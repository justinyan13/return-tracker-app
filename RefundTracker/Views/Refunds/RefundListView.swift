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
            Group {
                if refunds.isEmpty {
                    RefundWorkflowEmptyState(kind: .firstRefund) {
                        isPresentingAddRefund = true
                    }
                } else {
                    refundList
                }
            }
            .navigationTitle("Refunds")
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Retailer, item, order, or tracking"
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
                Text("This removes the refund record from this device. This action cannot be undone.")
            }
            .alert("Couldn’t update refunds", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var refundList: some View {
        VStack(spacing: 0) {
            filterBar

            if results.isEmpty {
                RefundWorkflowEmptyState(kind: .noResults)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
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
                            .accessibilityIdentifier("refundRow_\(refund.id.uuidString)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    refundPendingDeletion = refund
                                }
                            }
                        }
                    } header: {
                        Text(resultCountText)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(RefundFilterScope.allCases) { filter in
                    RefundFilterChip(
                        title: filter.displayName,
                        symbolName: filter.symbolName,
                        isSelected: viewModel.selectedScope == filter
                    ) {
                        withAnimation(.snappy) {
                            viewModel.selectedScope = filter
                        }
                    }
                    .accessibilityIdentifier(
                        filter == .overdue
                            ? "filterOverdueButton"
                            : "\(filter.rawValue)RefundFilterButton"
                    )
                }

                RefundFilterChip(
                    title: "More",
                    symbolName: "line.3.horizontal.decrease",
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
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
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

    private var resultCountText: String {
        "\(results.count) \(results.count == 1 ? "refund" : "refunds")"
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

private extension RefundFilterScope {
    var symbolName: String {
        switch self {
        case .all: "tray.full"
        case .active: "clock"
        case .overdue: "exclamationmark.triangle"
        case .refunded: "checkmark.circle"
        case .disputed: "exclamationmark.bubble"
        }
    }
}
