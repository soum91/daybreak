import XCTest
import UserNotifications
import Network
import UIKit

/// This is a genuine UI-test runner, not a normal app calling a restricted daemon.
/// The only mutable operation is a user-approved, strictly formatted Sleep command.
final class DaybreakUITests: XCTestCase, UNUserNotificationCenterDelegate {
    private var approved: [[String: Any]] = []
    private var offered: [String: [String: Any]] = [:]
    private var listener: NWListener?
    private var status: [String: Any] = ["phase": "starting"]
    private var history: [String] = []
    private let networkQueue = DispatchQueue(label: "daybreak.runner.status")

    private func log(_ message: String) {
        history.append("\(Date()): \(message)")
        if history.count > 100 { history.removeFirst(history.count - 100) }
        print("DAYBREAK: \(message)")
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Daybreak-runner.txt")
        try? history.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
    private func announce(_ title: String, _ body: String, category: String = "", identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.categoryIdentifier = category
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }
    func testReadOnly() {
        // CI checks API presence and request parsing, never sends a Siri command.
        XCTAssertTrue(XCUIDevice.shared.siriService.responds(to: NSSelectorFromString("activateWithVoiceRecognitionText:")))
        XCTAssertTrue(DaybreakLaunch.takeRequests().isEmpty)
        print("DAYBREAK_READONLY_PASS: Siri testing interface exists; no activation performed")
    }
    @MainActor func testRunOnDevice() throws {
        DaybreakLaunch.markReady()
        continueAfterFailure = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let allow = UNNotificationAction(identifier: "apply", title: "Apply Sleep alarm test", options: [.authenticationRequired])
        let deny = UNNotificationAction(identifier: "deny", title: "Cancel", options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: "sleep-test", actions: [allow, deny], intentIdentifiers: [])])
        center.requestAuthorization(options: [.alert, .sound]) { allowed, error in
            DispatchQueue.main.async {
                self.log("Notifications authorized: \(allowed); \(error?.localizedDescription ?? "no error")")
                self.announce("Daybreak Runner ready", "Return to Daybreak and send a Sleep alarm test. Long-press its notification to approve.")
            }
        }
        startReadOnlyStatusServer()
        status = ["phase": "ready", "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown"]
        log("On-device XCTest runner active. No computer connection is used by this test.")
        while true {
            for request in DaybreakLaunch.takeRequests() {
                guard let h = request["hour"] as? Int, let m = request["minute"] as? Int,
                      let id = request["request"] as? String else { continue }
                offered[id] = request
                announce("Set next Sleep alarm to \(Self.time(h,m))?", "Long-press and choose Apply Sleep alarm test. This sends the command to Siri, then opens Clock for verification.", category: "sleep-test", identifier: id)
                status = ["phase": "awaiting-approval", "request": id]
                log("Awaiting device approval for \(Self.time(h,m))")
            }
            if !approved.isEmpty {
                let request = approved.removeFirst()
                if let h = request["hour"] as? Int, let m = request["minute"] as? Int {
                    let command = "Change my next sleep alarm to \(Self.time(h,m))."
                    log("Submitting fixed Sleep-only command: \(command)")
                    let error = DaybreakLaunch.caught { XCUIDevice.shared.siriService.activate(voiceRecognitionText: command) }
                    if let error {
                        status = ["phase": "failed", "error": error]
                        log("Siri activation failed: \(error)")
                        announce("Daybreak Siri test failed", error)
                    } else {
                        status = ["phase": "submitted", "command": command, "verified": false]
                        log("Siri activation returned. Alarm change is NOT verified.")
                        RunLoop.current.run(until: Date().addingTimeInterval(3))
                        let clockError = DaybreakLaunch.caught { XCUIApplication(bundleIdentifier: "com.apple.mobiletimer").activate() }
                        if let clockError { log("Clock activation: \(clockError)") }
                        announce("Check Clock → Sleep | Wake Up", "Siri received the request. Confirm its time before relying on it; return to Daybreak to copy the runner report.")
                    }
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
    }
    private static func time(_ h: Int, _ m: Int) -> String { String(format: "%d:%02d %@", h % 12 == 0 ? 12 : h % 12, m, h < 12 ? "AM" : "PM") }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .list, .sound]) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            let id = response.notification.request.identifier
            if let request = self.offered.removeValue(forKey: id), response.actionIdentifier == "apply" { self.approved.append(request) }
            completionHandler()
        }
    }
    // A loopback-bound status endpoint only. No action/control API and no LAN listener.
    private func startReadOnlyStatusServer() {
        do {
            let p = NWParameters.tcp
            p.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: 8275)
            listener = try NWListener(using: p)
            listener?.newConnectionHandler = { connection in
                connection.start(queue: self.networkQueue)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    guard let data, let text = String(data: data, encoding: .utf8), text.hasPrefix("GET /status ") else { connection.cancel(); return }
                    DispatchQueue.main.async {
                        var body = self.status; body["log"] = self.history
                        let json = (try? JSONSerialization.data(withJSONObject: body)) ?? Data("{}".utf8)
                        var payload = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(json.count)\r\nConnection: close\r\n\r\n".utf8)
                        payload.append(json)
                        connection.send(content: payload, completion: .contentProcessed { _ in connection.cancel() })
                    }
                }
            }
            listener?.start(queue: networkQueue)
        } catch { log("Status listener unavailable: \(error.localizedDescription)") }
    }
}
