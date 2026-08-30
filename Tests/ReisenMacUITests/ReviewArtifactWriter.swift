import Foundation
import XCTest

enum ReviewArtifactWriter {
    static let schemaVersion = 1

    static func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("reisen-ui-review-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func write(
        app: XCUIApplication,
        directory: URL,
        screen: String,
        testCase: XCTestCase
    ) throws {
        let pngURL = directory.appendingPathComponent("\(screen).png")
        try app.screenshot().pngRepresentation.write(to: pngURL)
        addAttachment(at: pngURL, to: testCase)
        let nodes = walk(app)
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": schemaVersion,
            "screen": screen,
            "nodes": nodes,
        ], options: [.prettyPrinted, .sortedKeys])
        let axURL = directory.appendingPathComponent("\(screen).ax.json")
        try data.write(to: axURL)
        addAttachment(at: axURL, to: testCase)
    }

    static func writeManifest(directory: URL, testCase: XCTestCase) throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "png" || $0.pathExtension == "json" }
        .map(\.lastPathComponent)
        .sorted()
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": schemaVersion,
            "platform": "macOS",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "artifacts": files,
        ], options: [.prettyPrinted, .sortedKeys])
        let manifestURL = directory.appendingPathComponent("manifest.json")
        try data.write(to: manifestURL)
        addAttachment(at: manifestURL, to: testCase)
    }

    private static func addAttachment(at url: URL, to testCase: XCTestCase) {
        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.lifetime = XCTAttachment.Lifetime.keepAlways
        testCase.add(attachment)
    }

    private static func walk(_ root: XCUIElement) -> [[String: Any]] {
        var nodes: [[String: Any]] = []
        append(root.windows.firstMatch, into: &nodes, remaining: 400)
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
