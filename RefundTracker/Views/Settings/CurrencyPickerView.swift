import SwiftUI

struct CurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    @State private var searchText = ""

    private var currencyCodes: [String] {
        let preferred = [
            "USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CNY", "INR",
            "CHF", "NZD", "SGD", "HKD", "KRW", "MXN", "BRL", "SEK",
            "NOK", "DKK", "PLN", "ZAR"
        ]
        let allCodes = Set(Locale.commonISOCurrencyCodes).union(preferred)
        return allCodes.sorted { lhs, rhs in
            let lhsPreferred = preferred.firstIndex(of: lhs)
            let rhsPreferred = preferred.firstIndex(of: rhs)

            switch (lhsPreferred, rhsPreferred) {
            case let (.some(left), .some(right)):
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs < rhs
            }
        }
    }

    private var filteredCodes: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return currencyCodes }
        return currencyCodes.filter { code in
            code.localizedCaseInsensitiveContains(query)
                || currencyName(for: code).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            currencyList
                // The selected code can sit far below the preferred ones, so
                // bring it into view instead of opening at the top of the list.
                .onAppear {
                    guard filteredCodes.contains(selection) else { return }
                    proxy.scrollTo(selection, anchor: .center)
                }
        }
    }

    private var currencyList: some View {
        List(filteredCodes, id: \.self) { code in
            Button {
                selection = code
                dismiss()
            } label: {
                CurrencyRow(
                    code: code,
                    name: currencyName(for: code),
                    symbol: currencySymbol(for: code),
                    flag: Self.flag(for: code),
                    isSelected: selection == code
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22))
            .listRowSeparatorTint(RefundTheme.line)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .listRowBackground(Color.clear)
            .accessibilityLabel(
                "\(currencyName(for: code)), \(code)\(selection == code ? ", selected" : "")"
            )
            .accessibilityIdentifier("currency.\(code)")
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RefundBackdrop())
        .tint(RefundTheme.ink)
        .navigationTitle("Default currency")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Currency or code")
        .overlay {
            if filteredCodes.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func currencyName(for code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    private func currencySymbol(for code: String) -> String {
        // Building the locale from `en_<code>` reads the currency code as a
        // region, which every currency resolves to the generic "¤" placeholder.
        // Overriding the currency component resolves the real symbol.
        var components = Locale.Components(locale: .current)
        components.currency = Locale.Currency(code)
        return Locale(components: components)
            .currencySymbol
            .flatMap { $0.isEmpty || $0 == "¤" ? nil : $0 } ?? code
    }

    /// An ISO 4217 code is its issuing country's ISO 3166-1 code plus a letter
    /// naming the unit — USD is US, JPY is JP — so the first two characters
    /// give the flag. Supranational codes break the pattern: the euro has no
    /// country, and the X-prefixed units (XAF, XCD, XAU) are shared or are
    /// metals, so those fall back to the currency symbol.
    static func flag(for code: String) -> String? {
        let regionCode = code == "EUR" ? "EU" : String(code.prefix(2))
        guard regionCode == "EU" || Locale.Region(regionCode).isISORegion else {
            return nil
        }

        var scalars = String.UnicodeScalarView()
        for character in regionCode.unicodeScalars {
            guard ("A" ... "Z").contains(Character(character)),
                  let indicator = UnicodeScalar(
                      0x1F1E6 + character.value - 0x41
                  ) else {
                return nil
            }
            scalars.append(indicator)
        }
        return String(scalars)
    }
}

private struct CurrencyRow: View {
    let code: String
    let name: String
    let symbol: String
    let flag: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            mark

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(.subheadline))
                    .foregroundStyle(RefundTheme.ink)
                    .lineLimit(1)

                Text(symbol == code ? code : "\(code) · \(symbol)")
                    .eyebrow(size: 9)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(.footnote).weight(.medium))
                    .foregroundStyle(RefundTheme.ink)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 62)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var mark: some View {
        if let flag {
            Text(flag)
                .font(.system(size: 24))
                .frame(width: 38, height: 38)
                .background(RefundTheme.sand)
                .accessibilityHidden(true)
        } else {
            Text(symbol)
                .serif(15, relativeTo: .body)
                .foregroundStyle(RefundTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 3)
                .frame(width: 38, height: 38)
                .background(RefundTheme.sand)
                .accessibilityHidden(true)
        }
    }
}
