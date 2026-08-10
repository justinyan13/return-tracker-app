import SwiftUI

struct RefundFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: RefundListViewModel
    let retailers: [String]

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        statusSection

                        if !retailers.isEmpty {
                            retailerSection
                        }

                        methodSection
                        dateRangeSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .tint(RefundTheme.ink)
            }
            .navigationTitle("Filter refunds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.clearFilters()
                    }
                    .disabled(viewModel.appliedFilterCount == 0)
                    .accessibilityIdentifier("resetRefundFiltersButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.normalizeDateRange()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("applyRefundFiltersButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(6)
        .tint(RefundTheme.ink)
    }

    private var statusSection: some View {
        FilterSection(title: "Status") {
            ForEach(RefundFilterScope.allCases) { scope in
                RefundSelectionRow(
                    title: scope.displayName,
                    isSelected: viewModel.selectedScope == scope
                ) {
                    viewModel.selectedScope = scope
                }

                Hairline()
            }
        }
        .accessibilityIdentifier("refundStatusFilter")
    }

    private var retailerSection: some View {
        FilterSection(title: "Retailer") {
            RefundSelectionRow(
                title: "All retailers",
                isSelected: viewModel.selectedRetailer == nil
            ) {
                viewModel.selectedRetailer = nil
            }

            Hairline()

            ForEach(retailers, id: \.self) { retailer in
                RefundSelectionRow(
                    title: retailer,
                    isSelected: viewModel.selectedRetailer == retailer
                ) {
                    viewModel.selectedRetailer = retailer
                }

                Hairline()
            }
        }
        .accessibilityIdentifier("retailerFilterSection")
    }

    private var methodSection: some View {
        FilterSection(title: "Refund method") {
            RefundSelectionRow(
                title: "All methods",
                isSelected: viewModel.selectedMethod == nil
            ) {
                viewModel.selectedMethod = nil
            }

            Hairline()

            ForEach(RefundMethod.allCases) { method in
                RefundSelectionRow(
                    title: method.displayName,
                    isSelected: viewModel.selectedMethod == method
                ) {
                    viewModel.selectedMethod = method
                }

                Hairline()
            }
        }
        .accessibilityIdentifier("refundMethodFilterSection")
    }

    private var dateRangeSection: some View {
        FilterSection(title: "Date range") {
            HStack(spacing: 22) {
                ForEach(RefundDateField.allCases) { field in
                    RefundChoice(
                        title: field.displayName,
                        isSelected: viewModel.selectedDateField == field
                    ) {
                        viewModel.selectedDateField = field
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)

            Hairline()

            HStack(spacing: 12) {
                Text("Limit to a date range")
                    .font(.system(.subheadline))
                    .foregroundStyle(RefundTheme.ink)

                Spacer(minLength: 8)

                Toggle("", isOn: $viewModel.usesExpectedDateRange)
                    .labelsHidden()
                    .tint(RefundTheme.ink)
                    .accessibilityLabel("Limit to a date range")
                    .accessibilityIdentifier("dateRangeFilterToggle")
            }
            .padding(.vertical, 12)

            Hairline()

            if viewModel.usesExpectedDateRange {
                filterDateRow("From", selection: $viewModel.expectedDateStart)
                Hairline()
                filterDateRow("Through", selection: $viewModel.expectedDateEnd)
                Hairline()
            }
        }
    }

    private func filterDateRow(
        _ title: String,
        selection: Binding<Date>
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.ink)

            Spacer(minLength: 8)

            DatePicker(
                title,
                selection: selection,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
        .padding(.vertical, 10)
    }
}

private struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RefundSectionHeading(title: title)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
