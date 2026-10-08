import Foundation
import UIKit

/// Things to fill in before launch. See the launch pack.
enum AppInfo {
    /// Where "Report a problem" emails go. Swap for a dedicated support address before launch.
    static let supportEmail = "matt.lakin.ml@gmail.com"

    /// The number in your App Store link (apps.apple.com/app/id123456789), from App Store Connect.
    /// Until it's set, "Rate us" shows Apple's built-in rating pop-up instead.
    static let appStoreID = ""

    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    static var reviewURL: URL? {
        guard !appStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    @MainActor
    static var bugReportURL: URL? {
        let device = UIDevice.current
        let body = """


        ---
        Please describe what went wrong above this line. A screenshot helps too.
        App version: \(version)
        iOS: \(device.systemVersion)
        Device: \(device.model)
        """
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = supportEmail
        c.queryItems = [
            URLQueryItem(name: "subject", value: "Shift Calendar problem"),
            URLQueryItem(name: "body", value: body),
        ]
        return c.url
    }
}
