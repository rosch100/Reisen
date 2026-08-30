import Foundation
import XCTest

enum ReviewArtifactWriter {
    static let schemaVersion = 1

    static func makeDirectory() throws -> URL {
        let root = ProcessInfo.processInfo.environment["REISEN_UI_REVIEW_DIR"]
            ?? "/tmp/reisen-ui-review"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let directory = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent(stamp, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func write(app: XCUIApplication, directory: URL, screen: String) throws {
        let png = app.screenshot().pngRepresentation
        try png.write(to: directory.appendingPathComponent("\(screen).png"))
        let nodes = walk(app)
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": schemaVersion,
            "screen": screen,
            "nodes": nodes,
        ], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("\(screen).ax.json"))
    }

    static func writeManifest(directory: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": schemaVersion,
            "platform": "macOS",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("manifest.json"))
    }

    private static func walk(_ root: XCUIElement) -> [[String: Any]] {
        var nodes: [[String: Any]] = []
        append(root, into: &nodes, remaining: 400)
        return nodes
    }

    private static func append(
        _ element: XCUIElement,
        into nodes: inout [[String: Any]],
        remaining: Int
    ) {
        guard nodes.count < remaining else { return }
        let frame = element.frame
        nodes.append([
            "identifier": element.identifier,
            "label": element.label,
            "elementType": String(describing: element.elementType),
            "frame": [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.size.width,
                "height": frame.size.height,
            ],
            "enabled": element.isEnabled,
            "hittable": element.isHittable,
        ])
        let children = element.children(matching: .any)
        let limit = min(children.count, 40)
        for index in 0..<limit {
            append(children.element(boundBy: index), into: &nodes, remaining: remaining)
        }
    }
}
