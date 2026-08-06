import XCTest

final class RefundTrackerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAddingARefund() {
        launchApp()

        addRefund(retailer: "Everlane", item: "Linen shirt", amount: "84.50")

        XCTAssertTrue(app.staticTexts["Everlane"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Linen shirt"].exists)
    }

    func testEditingARefund() {
        launchApp()
        addRefund(retailer: "Nordstrom", item: "Running shoes", amount: "129.00")

        app.staticTexts["Nordstrom"].tap()
        app.buttons["editRefundButton"].tap()

        let itemField = app.textFields["itemField"]
        XCTAssertTrue(itemField.waitForExistence(timeout: 2))
        itemField.clearAndEnterText("Trail running shoes")
        app.buttons["saveRefundButton"].tap()

        XCTAssertTrue(app.staticTexts["Trail running shoes"].waitForExistence(timeout: 3))
    }

    func testMarkingARefundAsReceived() {
        launchApp()
        addRefund(retailer: "REI", item: "Rain jacket", amount: "179.95")

        app.staticTexts["REI"].tap()
        let receivedButton = app.buttons["markRefundReceivedButton"]
        XCTAssertTrue(receivedButton.waitForExistence(timeout: 2))
        receivedButton.tap()

        XCTAssertTrue(app.staticTexts["Refunded"].waitForExistence(timeout: 3))
    }

    func testFilteringOverdueRefunds() {
        launchApp(seedSampleData: true)

        app.tabBars.buttons["Refunds"].tap()
        let overdueFilter = app.buttons["filterOverdueButton"]
        XCTAssertTrue(overdueFilter.waitForExistence(timeout: 2))
        overdueFilter.tap()

        XCTAssertTrue(app.staticTexts["Overdue"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Expected next week"].exists)
    }

    func testDeletingARefund() {
        launchApp()
        addRefund(retailer: "Patagonia", item: "Fleece vest", amount: "109.00")

        app.staticTexts["Patagonia"].tap()
        let deleteButton = app.buttons["deleteRefundButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["Patagonia"].waitForNonExistence(timeout: 2))
    }

    private func launchApp(seedSampleData: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if seedSampleData {
            app.launchArguments.append("--ui-testing-seed")
        }
        app.launch()
    }

    private func addRefund(retailer: String, item: String, amount: String) {
        let identifiedAddButton = app.buttons["addRefundButton"]
        let addButton = identifiedAddButton.exists
            ? identifiedAddButton
            : app.tabBars.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        let retailerField = app.textFields["retailerField"]
        XCTAssertTrue(retailerField.waitForExistence(timeout: 2))
        retailerField.tap()
        retailerField.typeText(retailer)

        let itemField = app.textFields["itemField"]
        itemField.tap()
        itemField.typeText(item)

        let amountField = app.textFields["amountField"]
        amountField.tap()
        amountField.typeText(amount)

        app.buttons["saveRefundButton"].tap()
        XCTAssertTrue(app.staticTexts[retailer].waitForExistence(timeout: 3))
    }
}

private extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        tap()
        if let currentValue = value as? String, !currentValue.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        typeText(text)
    }
}
