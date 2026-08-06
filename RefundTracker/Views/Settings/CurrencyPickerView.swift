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
        }
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
        let symbol = Locale(identifier: "en_\(code)")
            .currencySymbol
            .flatMap { $0.isEmpty ? nil : $0 } ?? code
        return symbol == code ? code : "\(code) · \(symbol)"
    }
}
