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

        addRefund(retailer: "Everlane", amount: "84.50")

        XCTAssertTrue(app.staticTexts["Everlane"].waitForExistence(timeout: 3))
    }

    func testEditingARefund() {
        launchApp()
        addRefund(retailer: "Nordstrom", amount: "129.00")

        refundRow(named: "Nordstrom").tap()
        app.buttons["editRefundButton"].tap()

        let retailerField = app.textFields["retailerField"]
        XCTAssertTrue(retailerField.waitForExistence(timeout: 2))
        retailerField.clearAndEnterText("Nordstrom Rack")
        dismissKeyboard()
        app.buttons["saveRefundButton"].tap()

        XCTAssertTrue(app.staticTexts["Nordstrom Rack"].waitForExistence(timeout: 3))
    }

    func testMarkingARefundAsReceived() {
        launchApp()
        addRefund(retailer: "REI", amount: "179.95")

        refundRow(named: "REI").tap()
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

        XCTAssertTrue(refundRow(named: "Wayfair").waitForExistence(timeout: 2))
        XCTAssertFalse(refundRow(named: "Allbirds").exists)
    }

    func testDeletingARefund() {
        launchApp()
        addRefund(retailer: "Patagonia", amount: "109.00")

        refundRow(named: "Patagonia").tap()
        let deleteButton = app.buttons["deleteRefundButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(refundRow(named: "Patagonia").waitForNonExistence(timeout: 2))
    }

    private func launchApp(seedSampleData: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if seedSampleData {
            app.launchArguments.append("--ui-testing-seed")
        }
        app.launch()
    }

    private func addRefund(retailer: String, amount: String) {
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

        let amountField = app.textFields["amountField"]
        amountField.tap()
        amountField.typeText(amount)

        dismissKeyboard()
        app.buttons["saveRefundButton"].tap()
        XCTAssertTrue(refundRow(named: retailer).waitForExistence(timeout: 3))
    }

    private func dismissKeyboard() {
        let doneButton = app.toolbars.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2))
        doneButton.tap()
    }

    private func refundRow(named merchant: String) -> XCUIElement {
        app.buttons
            .matching(
                NSPredicate(
                    format: "label BEGINSWITH[c] %@",
                    merchant
                )
            )
            .firstMatch
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
