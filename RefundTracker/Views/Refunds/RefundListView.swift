import SwiftData
import SwiftUI

struct RefundListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var refunds: [Refund]

    @State private var viewModel = RefundListViewModel()
    @State private var isPresentingAddRefund = false
    @State private var isPresentingFilters = false
    @State private var refundPendingDeletion: Refund?
    @State private var errorMessage: String?

    private let attachmentStore = AttachmentStore.shared

    private var results: [Refund] {
        viewModel.results(from: refunds)
    }

    private var retailers: [String] {
        Array(
            Set(
                refunds
                    .map(\.retailerName)
                    .filter { !$0.isEmpty }
            )
        )
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                if refunds.isEmpty {
                    firstRefundEmptyState
                } else {
                    refundList
                }
            }
            .navigationTitle("Refunds")
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Merchant, order, or tracking"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddRefund = true
                    } label: {
                        Label("Add refund", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addRefundButton")
                }
            }
            .sheet(isPresented: $isPresentingAddRefund) {
                RefundFormView()
                    .environment(settings)
                    .presentationCornerRadius(6)
            }
            .sheet(isPresented: $isPresentingFilters) {
                RefundFilterSheet(viewModel: viewModel, retailers: retailers)
            }
            .confirmationDialog(
                "Delete this refund?",
                isPresented: Binding(
                    get: { refundPendingDeletion != nil },
                    set: { if !$0 { refundPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Refund", role: .destructive) {
                    deletePendingRefund()
                }
                Button("Cancel", role: .cancel) {
                    refundPendingDeletion = nil
                }
            } message: {
                Text(
                    "This removes the refund record from this device. This action cannot be undone."
                )
            }
            .alert("Couldn’t update refunds", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var firstRefundEmptyState: some View {
        ScrollView {
            RefundWorkflowEmptyState(kind: .firstRefund) {
                isPresentingAddRefund = true
            }
        }
    }

    private var refundList: some View {
        VStack(spacing: 0) {
            filterBar

            if results.isEmpty {
                ScrollView {
                    RefundWorkflowEmptyState(kind: .noResults)
                }
            } else {
                List {
                    Text(resultSummary)
                        .eyebrow(size: 10)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 22,
                                bottom: 0,
                                trailing: 22
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    ForEach(results) { refund in
                        NavigationLink {
                            RefundDetailView(
                                refund: refund,
                                deleteRecord: deleteRecord
                            )
                            .environment(settings)
                        } label: {
                            RefundRowView(refund: refund)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "refundRow_\(refund.id.uuidString)"
                        )
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: false
                        ) {
                            Button(
                                "Delete",
                                systemImage: "trash",
                                role: .destructive
                            ) {
                                refundPendingDeletion = refund
                            }
                        }
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 22,
                                bottom: 0,
                                trailing: 22
                            )
                        )
                        .listRowSeparatorTint(RefundTheme.line)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .contentMargins(.bottom, 24, for: .scrollContent)
                .accessibilityIdentifier("refundList")
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 22) {
                    ForEach(RefundFilterScope.allCases) { filter in
                        RefundScopeTab(
                            title: filter.displayName,
                            isSelected: viewModel.selectedScope == filter
                        ) {
                            withAnimation(.snappy(duration: 0.2)) {
                                viewModel.selectedScope = filter
                            }
                        }
                        .accessibilityIdentifier(
                            filter == .overdue
                                ? "filterOverdueButton"
                                : "\(filter.rawValue)RefundFilterButton"
                        )
                    }

                    VerticalHairline(height: 14)

                    RefundScopeTab(
                        title: "Filters",
                        count: viewModel.hasAdvancedFilters
                            ? viewModel.appliedFilterCount
                                - (viewModel.selectedScope == .all ? 0 : 1)
                            : 0,
                        isSelected: viewModel.hasAdvancedFilters
                    ) {
                        isPresentingFilters = true
                    }
                    .accessibilityIdentifier("refundFilterButton")
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
            }
            .scrollIndicators(.hidden)

            Hairline()
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $viewModel.sortOption) {
                ForEach(RefundSortOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Divider()

            Picker("Direction", selection: $viewModel.sortDirection) {
                Label("Ascending", systemImage: "arrow.up")
                    .tag(RefundSortDirection.ascending)
                Label("Descending", systemImage: "arrow.down")
                    .tag(RefundSortDirection.descending)
            }
        } label: {
            Label("Sort refunds", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("refundSortButton")
    }

    private var resultSummary: String {
        let count = "\(results.count) \(results.count == 1 ? "return" : "returns")"
        let scope = viewModel.selectedScope == .all
            ? "All statuses"
            : viewModel.selectedScope.displayName
        return "\(count) · \(scope) · \(viewModel.sortOption.displayName)"
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func deletePendingRefund() {
        guard let refund = refundPendingDeletion else { return }
        let refundID = refund.id
        let storedFilenames = refund.attachments.map(\.storedFilename)
        refundPendingDeletion = nil
        do {
            try deleteRecord(refund)
            NotificationService.shared.cancelNotifications(for: refundID)
            try? attachmentStore.deleteFiles(named: storedFilenames)
            NotificationCenter.default.post(
                name: .refundDataDidChange,
                object: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRecord(_ refund: Refund) throws {
        modelContext.delete(refund)
        modelContext.processPendingChanges()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

/// A word with a rule under it when chosen. Replaces the filled gradient pills.
private struct RefundScopeTab: View {
    let title: String
    var count = 0
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(title)
                        .eyebrow(
                            size: 11,
                            color: isSelected
                                ? RefundTheme.ink
                                : RefundTheme.inkFaint
                        )
                        .lineLimit(1)

                    if count > 0 {
                        Text(count.formatted())
                            .serif(11, relativeTo: .footnote)
                            .foregroundStyle(RefundTheme.ink)
                            .baselineOffset(5)
                    }
                }

                Rectangle()
                    .fill(isSelected ? RefundTheme.ink : .clear)
                    .frame(height: 1.5)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(title) filter\(count > 0 ? ", \(count) options" : "")"
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
