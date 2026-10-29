import XCTest
import UserNotifications
import Network
import UIKit

/// This is a genuine UI-test runner, not a normal app calling a restricted daemon.
/// The only mutable operation is a user-approved, strictly formatted Sleep command.
final class DaybreakUITests: XCTestCase, UNUserNotificationCenterDelegate {
    private var executing = false
    private var blocked = false
    private var lastSubmission = Date.distantPast
    private var approved: [[String: Any]] = []
    private var offered: [String: [String: Any]] = [:]
    private var listener: NWListener?
    private let sessionToken = UUID().uuidString
    private var accepted = Set<String>()
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
    @MainActor func testReadOnly() async throws {
        // CI checks API presence and request parsing, never sends a Siri command.
        XCTAssertTrue(XCUIDevice.shared.siriService.responds(to: NSSelectorFromString("activateWithVoiceRecognitionText:")))
        XCTAssertTrue(DaybreakLaunch.takeRequests().isEmpty)
        startLocalServer()
        defer { listener?.cancel() }
        let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:8275/status")!)
        let info = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let token = try XCTUnwrap(info["session"] as? String)
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8275/sleep-test")!)
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "X-Daybreak-Session")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["hour": 8, "minute": 30, "request": UUID().uuidString])
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(approved.count, 1)
        // No execution loop is entered in this test: no Siri activation or alarm mutation.
        _ = try await URLSession.shared.data(for: request)
        XCTAssertEqual(approved.count, 1, "Duplicate requests must not queue twice")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["hour": 9, "minute": 0, "request": UUID().uuidString])
        let (_, busyResponse) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((busyResponse as? HTTPURLResponse)?.statusCode, 409, "A different request must not queue while one is pending")
        XCTAssertEqual(approved.count, 1)
        request.setValue("invalid", forHTTPHeaderField: "X-Daybreak-Session")
        let (_, rejected) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((rejected as? HTTPURLResponse)?.statusCode, 400)
        XCTAssertEqual(approved.count, 1)
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
        startLocalServer()
        status = ["phase": "ready", "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown"]
        log("On-device XCTest runner active. No computer connection is used by this test.")
        while true {
            for raw in DaybreakLaunch.takeRequests() {
                guard !executing, !blocked, approved.isEmpty, Date().timeIntervalSince(lastSubmission) >= 60 else { log("Ignored URL request while another operation requires attention"); continue }
                guard let request = raw as? [String: Any], let h = request["hour"] as? Int, let m = request["minute"] as? Int,
                      let id = request["request"] as? String else { continue }
                offered[id] = request
                announce("Set next Sleep alarm to \(Self.time(h,m))?", "Long-press and choose Apply Sleep alarm test. This sends the command to Siri, leaves Siri visible for clarification. Verify the actual Sleep alarm in Clock.", category: "sleep-test", identifier: id)
                status = ["phase": "awaiting-approval", "request": id]
                log("Awaiting device approval for \(Self.time(h,m))")
            }
            if !approved.isEmpty {
                let request = approved.removeFirst()
                if let h = request["hour"] as? Int, let m = request["minute"] as? Int {
                    executing = true; lastSubmission = Date()
                    let command = (request["operation"] as? String) == "enable" ? "Turn on my next sleep alarm." : "Change my next sleep alarm to \(Self.time(h,m))."
                    log("Submitting fixed Sleep-only command: \(command)")
                    status = ["phase": "activating-siri", "command": command]
                    let error = DaybreakLaunch.caught { XCUIDevice.shared.siriService.activate(voiceRecognitionText: command) }
                    if let error {
                        blocked = true
                        status = ["phase": "needs-reset", "error": error, "command": command]
                        log("Siri activation failed: \(error)")
                        announce("Daybreak Siri test failed", error)
                    } else {
                        status = ["phase": "submitted", "command": command, "verified": false]
                        log("Siri activation returned. Alarm change is NOT verified.")
                        // Leave Siri visible. Switching apps here could interrupt its dialog.
                        log("Siri remains visible for any clarification. No automatic retry is performed.")
                        announce("Check Clock → Sleep | Wake Up", "Siri activation returned; an alarm change is not verified. Confirm the actual time in Clock. If Siri asks which alarm, dismiss it and check Clock before retrying.")
                    }
                    executing = false
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
            if let request = self.offered.removeValue(forKey: id), response.actionIdentifier == "apply", !self.executing, !self.blocked, self.approved.isEmpty, Date().timeIntervalSince(self.lastSubmission) >= 60 { self.approved.append(request) }
            completionHandler()
        }
    }
    private func receiveHTTP(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, complete, error in
            var buffer = buffer; if let data { buffer.append(data) }
            guard buffer.count <= 8192, error == nil else { connection.cancel(); return }
            guard let split = buffer.range(of: Data("\r\n\r\n".utf8)),
                  let header = String(data: buffer[..<split.lowerBound], encoding: .utf8) else {
                if complete { connection.cancel() } else { self.receiveHTTP(connection, buffer: buffer) }; return
            }
            let lines = header.components(separatedBy: "\r\n")
            let length = lines.dropFirst().first { $0.lowercased().hasPrefix("content-length:") }.flatMap { Int($0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)) } ?? 0
            guard length >= 0, length <= 2048 else { connection.cancel(); return }
            let body = Data(buffer[split.upperBound...])
            if body.count < length {
                if complete { connection.cancel() } else { self.receiveHTTP(connection, buffer: buffer) }; return
            }
            DispatchQueue.main.async {
                var result = self.status; var code = "200 OK"
                if lines.first == "GET /status HTTP/1.1" {
                    result["session"] = self.sessionToken
                    result["busy"] = self.executing || !self.approved.isEmpty
                    result["cooldownSeconds"] = max(0, 60 - Int(Date().timeIntervalSince(self.lastSubmission)))
                } else if lines.first == "POST /reset HTTP/1.1",
                          lines.contains(where: { $0.lowercased() == "x-daybreak-session: \(self.sessionToken.lowercased())" }) {
                    if self.executing { code = "409 Conflict"; result = ["error": "Siri is still executing. Dismiss it and wait before resetting."] }
                    else { self.approved.removeAll(); self.offered.removeAll(); self.blocked = false; self.lastSubmission = .distantPast; self.status = ["phase": "ready"]; self.log("User checked Clock and cleared the previous request"); result = self.status }
                } else if lines.first == "POST /sleep-test HTTP/1.1",
                          lines.contains(where: { $0.lowercased() == "x-daybreak-session: \(self.sessionToken.lowercased())" }),
                          let request = (try? JSONSerialization.jsonObject(with: body.prefix(length))) as? [String: Any],
                          let h = request["hour"] as? Int, (0...23).contains(h),
                          let m = request["minute"] as? Int, (0...59).contains(m),
                          let id = request["request"] as? String, UUID(uuidString: id) != nil,
                          ["set", "enable"].contains(request["operation"] as? String ?? "set") {
                    if self.accepted.contains(id) { result = self.status }
                    else if self.executing || self.blocked || !self.approved.isEmpty || Date().timeIntervalSince(self.lastSubmission) < 60 {
                        code = "409 Conflict"
                        result = ["error": "Previous Siri request is active, cooling down, or needs reset. Check Clock and clear it before retrying."]
                    } else {
                        self.accepted.insert(id)
                        self.approved.append(request)
                        self.status = ["phase": "queued", "request": id]
                        self.log("Received host-confirmed \(request["operation"] as? String ?? "set") Sleep test; selected time \(Self.time(h,m))")
                    }
                    if code == "200 OK" { result = self.status }
                } else { code = "400 Bad Request"; result = ["error": "Invalid endpoint, session or Sleep request"] }
                result["log"] = self.history
                let json = (try? JSONSerialization.data(withJSONObject: result)) ?? Data("{}".utf8)
                var payload = Data("HTTP/1.1 \(code)\r\nContent-Type: application/json\r\nContent-Length: \(json.count)\r\nConnection: close\r\n\r\n".utf8)
                payload.append(json)
                connection.send(content: payload, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }
    // Loopback only. A session-bound endpoint accepts one fixed Sleep command after host confirmation.
    private func startLocalServer() {
        do {
            let p = NWParameters.tcp
            p.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: 8275)
            listener = try NWListener(using: p)
            listener?.newConnectionHandler = { connection in
                connection.start(queue: self.networkQueue)
                self.receiveHTTP(connection, buffer: Data())
            }
            listener?.start(queue: networkQueue)
        } catch { log("Status listener unavailable: \(error.localizedDescription)") }
    }
}
