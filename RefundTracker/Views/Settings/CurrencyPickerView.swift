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
                    isSelected: selection == code
                )
                // The stock row fill is opaque and spans the full width, which
                // hides the backdrop and makes this screen the odd one out.
                // Carrying the background on the content instead keeps it
                // inside the row insets, matching the app's card inset.
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground)
                        .opacity(0.82),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityLabel(
                "\(currencyName(for: code)), \(code)\(selection == code ? ", selected" : "")"
            )
            .accessibilityIdentifier("currency.\(code)")
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RefundBackdrop())
        .tint(RefundTheme.violet)
        .navigationTitle("Default currency")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
}

private struct CurrencyRow: View {
    let code: String
    let name: String
    let symbol: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 13) {
            Text(symbol)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 4)
                .frame(width: 42, height: 42)
                .background(RefundTheme.gradient(for: code))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(code)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(RefundTheme.violet)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }
}
