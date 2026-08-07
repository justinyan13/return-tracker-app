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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currencyName(for: code))
                            .foregroundStyle(.primary)
                        Text(currencyDetail(for: code))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selection == code {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .accessibilityLabel(
                "\(currencyName(for: code)), \(code)\(selection == code ? ", selected" : "")"
            )
            .accessibilityIdentifier("currency.\(code)")
        }
        .scrollContentBackground(.hidden)
        .background(RefundBackdrop())
        .tint(RefundTheme.violet)
        .navigationTitle("Default Currency")
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

    private func currencyDetail(for code: String) -> String {
        // Building the locale from `en_<code>` reads the currency code as a
        // region, which every currency resolves to the generic "¤" placeholder.
        // Overriding the currency component resolves the real symbol.
        var components = Locale.Components(locale: .current)
        components.currency = Locale.Currency(code)
        let symbol = Locale(components: components)
            .currencySymbol
            .flatMap { $0.isEmpty || $0 == "¤" ? nil : $0 } ?? code
        return symbol == code ? code : "\(code) · \(symbol)"
    }
}
