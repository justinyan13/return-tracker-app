import SwiftUI

struct RefundFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: RefundListViewModel
    let retailers: [String]

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Picker("Status", selection: $viewModel.selectedScope) {
                        ForEach(RefundFilterScope.allCases) { scope in
                            Text(scope.displayName)
                                .tag(scope)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityIdentifier("refundStatusFilter")
                }

                if !retailers.isEmpty {
                    Section {
                        selectionButton(
                            "All retailers",
                            isSelected: viewModel.selectedRetailer == nil
                        ) {
                            viewModel.selectedRetailer = nil
                        }

                        ForEach(retailers, id: \.self) { retailer in
                            selectionButton(
                                retailer,
                                isSelected: viewModel.selectedRetailer == retailer
                            ) {
                                viewModel.selectedRetailer = retailer
                            }
                        }
                    } header: {
                        Text("Retailer")
                    }
                    .accessibilityIdentifier("retailerFilterSection")
                }

                Section("Refund method") {
                    selectionButton(
                        "All methods",
                        isSelected: viewModel.selectedMethod == nil
                    ) {
                        viewModel.selectedMethod = nil
                    }

                    ForEach(RefundMethod.allCases) { method in
                        selectionButton(
                            method.displayName,
                            isSelected: viewModel.selectedMethod == method
                        ) {
                            viewModel.selectedMethod = method
                        }
                    }
                }
                .accessibilityIdentifier("refundMethodFilterSection")

                Section("Date range") {
                    Picker("Date field", selection: $viewModel.selectedDateField) {
                        ForEach(RefundDateField.allCases) { field in
                            Text(field.displayName).tag(field)
                        }
                    }

                    Toggle("Limit to a date range", isOn: $viewModel.usesExpectedDateRange)
                        .accessibilityIdentifier("dateRangeFilterToggle")

                    if viewModel.usesExpectedDateRange {
                        DatePicker(
                            "From",
                            selection: $viewModel.expectedDateStart,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "Through",
                            selection: $viewModel.expectedDateEnd,
                            displayedComponents: .date
                        )
                    }
                }
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
    }

    private func selectionButton(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

}
