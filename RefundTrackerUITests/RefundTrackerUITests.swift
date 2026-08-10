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

    func testChoosingAndEditingARefundCoverEmoji() {
        launchApp()
        addRefund(
            retailer: "Baggu",
            amount: "68.00",
            coverOptionIndex: 0
        )

        refundRow(named: "Baggu").tap()

        let detailCover = app.descendants(matching: .any)["refundDetailCoverEmoji"]
        XCTAssertTrue(detailCover.waitForExistence(timeout: 3))
        XCTAssertEqual(detailCover.value as? String, "👗")

        app.buttons["editRefundButton"].tap()
        let pickerButton = app.buttons["coverEmojiPickerButton"]
        XCTAssertTrue(pickerButton.waitForExistence(timeout: 2))
        XCTAssertEqual(pickerButton.value as? String, "👗")

        pickerButton.tap()
        let newCover = app.buttons["coverEmojiOption_12"]
        XCTAssertTrue(newCover.waitForExistence(timeout: 2))
        newCover.tap()
        XCTAssertEqual(pickerButton.value as? String, "👠")

        app.buttons["saveRefundButton"].tap()
        XCTAssertTrue(detailCover.waitForExistence(timeout: 3))
        XCTAssertEqual(detailCover.value as? String, "👠")
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

    /// Selecting a currency used to crash the app: `AppSettings` normalized the
    /// new value by assigning to the property from inside its own `didSet`,
    /// which recurses forever under the @Observable macro.
    func testSelectingADefaultCurrency() {
        launchApp()

        app.tabBars.buttons["Settings"].tap()

        let currencyRow = app.buttons["settings.defaultCurrency"]
        XCTAssertTrue(currencyRow.waitForExistence(timeout: 3))
        currencyRow.tap()

        let euro = app.buttons["currency.EUR"]
        XCTAssertTrue(euro.waitForExistence(timeout: 3))
        euro.tap()

        XCTAssertTrue(
            waitForCurrencyPickerToClose(),
            "Picking a currency should return to Settings"
        )
        XCTAssertTrue(
            defaultCurrencyRow(showing: "EUR").waitForExistence(timeout: 3),
            "Settings should show the newly selected currency"
        )

        // A second trip through the picker: the row that opens it is rewritten
        // when the selection changes, which used to leave the pushed screen
        // detached, ignoring both the dismiss and every later tap.
        currencyRow.tap()

        let pound = app.buttons["currency.GBP"]
        XCTAssertTrue(pound.waitForExistence(timeout: 3))
        pound.tap()

        XCTAssertTrue(
            waitForCurrencyPickerToClose(),
            "The picker should still dismiss on a second selection"
        )
        XCTAssertTrue(
            defaultCurrencyRow(showing: "GBP").waitForExistence(timeout: 3),
            "Settings should show the second selected currency"
        )
    }

    func testChangingTheExpectedRefundWindow() {
        launchApp()

        app.tabBars.buttons["Settings"].tap()

        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 3))
        stepper.buttons["Increment"].tap()

        XCTAssertTrue(
            staticText(containing: "11 business days")
                .waitForExistence(timeout: 3)
        )
    }

    func testAddingARefundWithAnItemName() {
        launchApp()

        addRefund(
            retailer: "Everlane",
            item: "ReNew Transit Backpack",
            amount: "95.00"
        )

        refundRow(named: "Everlane").tap()

        let moreDetails = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'More details'"))
            .firstMatch
        XCTAssertTrue(moreDetails.waitForExistence(timeout: 3))
        moreDetails.tap()

        XCTAssertTrue(
            staticText(containing: "ReNew Transit Backpack")
                .waitForExistence(timeout: 3)
        )
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

    private func addRefund(
        retailer: String,
        item: String? = nil,
        amount: String,
        coverOptionIndex: Int? = nil
    ) {
        let identifiedAddButton = app.buttons["addRefundButton"]
        let addButton = identifiedAddButton.exists
            ? identifiedAddButton
            : app.tabBars.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        let retailerField = app.textFields["retailerField"]
        XCTAssertTrue(retailerField.waitForExistence(timeout: 2))

        if let coverOptionIndex {
            let pickerButton = app.buttons["coverEmojiPickerButton"]
            XCTAssertTrue(pickerButton.waitForExistence(timeout: 2))
            pickerButton.tap()

            let option = app.buttons["coverEmojiOption_\(coverOptionIndex)"]
            XCTAssertTrue(option.waitForExistence(timeout: 2))
            option.tap()
        }

        retailerField.tap()
        retailerField.typeText(retailer)

        let itemField = app.textFields["itemField"]
        XCTAssertTrue(itemField.waitForExistence(timeout: 2))
        if let item {
            itemField.tap()
            itemField.typeText(item)
        }

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

    /// The Settings row that opens the currency picker, carrying the selected
    /// code as its value. The picker lists the same codes, so callers confirm
    /// it has closed before matching on this.
    private func defaultCurrencyRow(showing currencyCode: String) -> XCUIElement {
        app.buttons
            .matching(
                NSPredicate(
                    format: "identifier == %@ AND label CONTAINS %@",
                    "settings.defaultCurrency",
                    currencyCode
                )
            )
            .firstMatch
    }

    /// Settings stays in the accessibility tree behind the pushed picker, and
    /// its rows keep reporting `exists` and even `isHittable`, so neither one
    /// proves the picker closed. The picker's own rows disappearing does.
    private func waitForCurrencyPickerToClose(
        timeout: TimeInterval = 5
    ) -> Bool {
        let anyCurrencyRow = app.buttons["currency.USD"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !anyCurrencyRow.exists { return true }
            _ = anyCurrencyRow.waitForExistence(timeout: 0.2)
        }
        return false
    }

    private func staticText(containing text: String) -> XCUIElement {
        app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    private func staticText(startingWith text: String) -> XCUIElement {
        app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", text))
            .firstMatch
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
