import XCTest

final class DaylineIOSUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitest"]
        app.launch()
    }

    func testSwitchAllTabs() {
        for identifier in ["tab-today", "tab-upcoming", "tab-inbox", "tab-goals", "tab-ideas"] {
            let tab = app.buttons[identifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), identifier)
            tab.tap()
            XCTAssertTrue(tab.isSelected)
        }
    }

    func testCreateCompleteAndEditATask() {
        let field = app.textFields["quick-add-today"].exists ? app.textFields["quick-add-today"] : app.textFields["添加今天的任务"]
        XCTAssertTrue(field.waitForExistence(timeout: 8), app.debugDescription)
        field.tap()
        field.typeText("买牛奶")
        let submit = app.buttons["quick-add-today-submit"]
        if submit.waitForExistence(timeout: 2), submit.isHittable {
            submit.tap()
        } else {
            field.typeText("\n")
        }
        let row = app.staticTexts["买牛奶"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.buttons["完成 买牛奶"].tap()
        let completed = app.buttons["show-completed"]
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["完成 买牛奶"].exists)
        completed.tap()
        if app.buttons["取消完成 买牛奶"].waitForExistence(timeout: 2) {
            app.buttons["取消完成 买牛奶"].tap()
            XCTAssertTrue(app.buttons["完成 买牛奶"].waitForExistence(timeout: 3))
            app.buttons["完成 买牛奶"].tap()
        }

        app.buttons["新建任务"].tap()
        let title = app.textFields["task-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("写一封很长的说明，确认编辑页在键盘出现后仍能滚到保存")
        let notes = app.textFields["task-notes"]
        notes.tap()
        notes.typeText("备注在键盘上方仍应可以编辑。")
        let save = app.buttons["task-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        if !save.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(save.isHittable)
        app.switches["task-schedule-toggle"].tap()
        app.buttons["task-schedule-date"].tap()
        XCTAssertTrue(app.datePickers["date-picker"].waitForExistence(timeout: 5) || app.otherElements["date-picker"].waitForExistence(timeout: 2))
        app.buttons["完成"].tap()
        save.tap()
        XCTAssertTrue(app.staticTexts["写一封很长的说明，确认编辑页在键盘出现后仍能滚到保存"].waitForExistence(timeout: 5))
    }

    func testCreateGoalAndConvertIdea() {
        app.buttons["tab-goals"].tap()
        app.buttons["新建目标"].tap()
        let title = app.textFields["goal-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("保持阅读")
        app.buttons["goal-save"].tap()
        XCTAssertTrue(app.staticTexts["保持阅读"].waitForExistence(timeout: 5))

        app.buttons["tab-ideas"].tap()
        app.buttons["新灵感"].tap()
        let idea = app.textFields["idea-title"]
        XCTAssertTrue(idea.waitForExistence(timeout: 5))
        idea.tap()
        let existing = idea.value as? String ?? ""
        if !existing.isEmpty {
            idea.tap()
            idea.press(forDuration: 1.2)
            app.menuItems["全选"].tap()
        }
        idea.typeText("清晨的想法")
        if app.buttons["换行"].exists { app.buttons["换行"].tap() }
        let convert = app.buttons["idea-convert"]
        XCTAssertTrue(convert.waitForExistence(timeout: 5))
        convert.tap()
        app.buttons["tab-inbox"].tap()
        let created = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "清晨")).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 5))
    }
}
