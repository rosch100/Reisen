import Foundation

extension ActivityListParser {
    func travelInformationDesktopURL(from activity: [String: Any]) -> String? {
        guard let travel = activity["travelInformation"] as? [String: Any],
              let buttons = travel["buttons"] as? [String: Any],
              let desktop = buttons["desktop"] as? [[String: Any]],
              let url = desktop.first?["url"] as? String else {
            return nil
        }
        return url
    }
}
