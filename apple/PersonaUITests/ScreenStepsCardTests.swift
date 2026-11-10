import XCTest

/// A terminal question of several (#2970): Previous and Next press ← and →, a question gone back to shows the answer it
/// had, and the answers are reviewed before they go. Against scripts/mock/mock_hub.py started with MOCK_SCREEN_STEPS=1,
/// whose dialog moves as the terminal does (TEST_RUNNER_PERSONA_STEPS_HUB=http://127.0.0.1:<port>;
/// TEST_RUNNER_PERSONA_SHOTS=<dir> keeps the screenshots); both styles (TEST_RUNNER_PERSONA_UI_STYLE=beautiful).
final class ScreenStepsCardTests: XCTestCase {
    private let review = "a1f3c2d4-0000-4000-8000-000000000006"
    private var hub = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let hub = ProcessInfo.processInfo.environment["PERSONA_STEPS_HUB"] else {
            throw XCTSkip("needs scripts/mock/mock_hub.py with MOCK_SCREEN_STEPS=1 (PERSONA_STEPS_HUB)")
        }
        self.hub = hub
    }

    @MainActor func testBackAndForthThenReview() throws {
        for scheme in ["light", "dark"] {
            mock("/mock/screen-steps?reset=1")
            let app = launch(scheme)
            XCTAssertTrue(app.staticTexts["先发哪个环境？"].waitForExistence(timeout: 20), "no first question:\n\(app.debugDescription)")
            XCTAssertFalse(app.buttons["screen-step-back"].exists, "Previous on the first question")
            shot(app, "first-\(scheme)")
            answer(app, "预览", next: "哪些平台要一起发？")
            shot(app, "second-\(scheme)")
            // Previous: the first question again, with the answer it had.
            app.buttons["screen-step-back"].tap()
            XCTAssertTrue(app.staticTexts["先发哪个环境？"].waitForExistence(timeout: 10), "Previous did not go back")
            XCTAssertTrue(waitUntil(5) { let o = self.option(app, "预览"); return o.label.contains("已选") || o.isSelected },
                          "the answer it had is not marked")
            shot(app, "back-\(scheme)")
            guard scheme == "light" else { app.terminate(); continue }
            // Next keeps it and goes on; the second question comes back although this device ended its card.
            if app.buttons["screen-step-next"].exists { app.buttons["screen-step-next"].tap() } else { app.buttons["发送"].firstMatch.tap() }
            XCTAssertTrue(app.staticTexts["哪些平台要一起发？"].waitForExistence(timeout: 10), "Next did not go on")
            option(app, "手表").tap()
            app.buttons["下一题"].firstMatch.tap()
            XCTAssertTrue(app.staticTexts["发完通知谁？"].waitForExistence(timeout: 10), "no last question")
            // The last answer goes as keys, so the review comes as a card and nothing is submitted yet.
            let submit = app.buttons["screen-review-submit"]
            answer(app, "设计组", until: submit)
            XCTAssertTrue(app.staticTexts["预览"].exists && app.staticTexts["手表"].exists && app.staticTexts["设计组"].exists,
                          "the review does not show the answers")
            XCTAssertNil(state()["done"] as? String, "submitted before the review")
            shot(app, "review")
            submit.tap()
            XCTAssertTrue(waitUntil(10) { self.state()["done"] as? String == "submitted" }, "Submit did not submit")
            let log = try XCTUnwrap(state()["log"] as? [[String: Any]])
            let last = log.filter { ($0["at"] as? Int) == 2 }.compactMap { $0["resolution"] as? [String: Any] }.last
            XCTAssertEqual(last?["keys"] as? [String], ["1"], "the last answer goes as keys")
            XCTAssertNil(last?["option"], "an answer naming its option would have been submitted at once")
            app.terminate()
        }
    }

    /// A question left unanswered at the computer: the review says so, and its button goes back to it.
    @MainActor func testAnUnansweredQuestionIsAnsweredFromTheReview() throws {
        mock("/mock/screen-steps?reset=review")
        let app = launch("light")
        let goAnswer = app.buttons["screen-review-answer"]
        XCTAssertTrue(goAnswer.waitForExistence(timeout: 20), "no review with a question left:\n\(app.debugDescription)")
        XCTAssertTrue(app.staticTexts["未回答"].exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "未回答")).firstMatch.exists)
        XCTAssertTrue(app.buttons["screen-review-submit-anyway"].exists, "no Submit Without Them")
        shot(app, "review-incomplete")
        goAnswer.tap()
        XCTAssertTrue(app.staticTexts["发完通知谁？"].waitForExistence(timeout: 10), "did not go back to the question left")
        shot(app, "answer-left")
        let submit = app.buttons["screen-review-submit"]
        answer(app, "全组", until: submit)
        submit.tap()
        XCTAssertTrue(waitUntil(10) { self.state()["done"] as? String == "submitted" }, "Submit did not submit")
    }

    // MARK: Helpers

    @MainActor private func launch(_ scheme: String) -> XCUIApplication {
        let app = XCUIApplication()
        let pair = "persona://pair?url=" + hub.addingPercentEncoding(withAllowedCharacters: .alphanumerics)! + "&token=mock"
        app.launchArguments = ["-pairURL", pair, "-openSession", "macbook/" + review, "-ui.scheme", scheme]
        app.launchPinned()
        dismissAlerts()
        return app
    }

    /// A system alert over the app (the style's icon changed): OK.
    private func dismissAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let ok = springboard.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["OK", "好", "Allow", "允许"])).firstMatch
        if ok.waitForExistence(timeout: 2) { ok.tap() }
    }

    @MainActor private func option(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    /// Picks a choice; BeautifulUI's card sends it with Send.
    @MainActor private func answer(_ app: XCUIApplication, _ label: String, next: String) {
        answer(app, label, until: app.staticTexts[next])
    }

    @MainActor private func answer(_ app: XCUIApplication, _ label: String, until shown: XCUIElement) {
        option(app, label).tap()
        if !shown.waitForExistence(timeout: 2), app.buttons["发送"].exists { app.buttons["发送"].firstMatch.tap() }
        XCTAssertTrue(shown.waitForExistence(timeout: 10), "nothing after answering \(label):\n\(app.debugDescription)")
    }

    private func mock(_ path: String) { _ = try? Data(contentsOf: URL(string: hub + path)!) }

    private func state() -> [String: Any] {
        guard let data = try? Data(contentsOf: URL(string: hub + "/mock/screen-steps")!),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    @MainActor private func shot(_ app: XCUIApplication, _ name: String) {
        dismissAlerts()
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["PERSONA_SHOTS"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/steps-\(name).png"))
        }
    }

    private func waitUntil(_ timeout: TimeInterval, _ ok: @escaping () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if ok() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return false
    }
}
