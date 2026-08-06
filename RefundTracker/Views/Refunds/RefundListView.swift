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
            .toolbarBackground(.hidden, for: .navigationBar)
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
                    .presentationCornerRadius(32)
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
            .padding(.top, 14)
        }
    }

    private var refundList: some View {
        VStack(spacing: 0) {
            filterBar

            if results.isEmpty {
                noResultsState
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
                                    top: 7,
                                    leading: 16,
                                    bottom: 7,
                                    trailing: 16
                                )
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        RefundSectionHeading(
                            title: resultCountText,
                            subtitle: resultSummary,
                            symbol: "arrow.uturn.backward.circle.fill"
                        )
                        .textCase(nil)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 4)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .accessibilityIdentifier("refundList")
            }
        }
    }

    private var noResultsState: some View {
        ScrollView {
            RefundWorkflowEmptyState(kind: .noResults)
                .padding(.top, 10)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(RefundFilterScope.allCases) { filter in
                    RefundScopePill(
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

                RefundScopePill(
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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RefundTheme.violet.opacity(0.09))
                .frame(height: 1)
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

    private var resultCountText: String {
        "\(results.count) \(results.count == 1 ? "return" : "returns")"
    }

    private var resultSummary: String {
        let scope = viewModel.selectedScope == .all
            ? "All statuses"
            : viewModel.selectedScope.displayName
        return "\(scope) · \(viewModel.sortOption.displayName)"
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

private struct RefundScopePill: View {
    let title: String
    let symbolName: String
    var count = 0
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.caption.weight(.bold))

                Text(title)
                    .lineLimit(1)

                if count > 0 {
                    Text(count.formatted())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(
                            isSelected ? RefundTheme.violet : .secondary
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected
                                ? Color.white.opacity(0.88)
                                : RefundTheme.violet.opacity(0.11),
                            in: Capsule()
                        )
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RefundTheme.gradient(for: title)
                        .clipShape(Capsule())
                } else {
                    Capsule()
                        .fill(.thinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.52), lineWidth: 1)
                        }
                }
            }
            .shadow(
                color: isSelected
                    ? RefundTheme.color(for: title).opacity(0.22)
                    : .clear,
                radius: 8,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(title) filter\(count > 0 ? ", \(count) options" : "")"
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
