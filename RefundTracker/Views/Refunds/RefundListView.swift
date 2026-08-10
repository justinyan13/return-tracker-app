import SwiftData
import SwiftUI
import UIKit

struct RefundListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Refund.expectedRefundDate) private var refunds: [Refund]

    @State private var listViewModel = RefundListViewModel()
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var navigationPath: [UUID] = []
    @State private var isPresentingFilters = false
    @State private var isShowingSearch = false
    @FocusState private var isSearchFocused: Bool
    @State private var refundPendingDeletion: Refund?
    @State private var errorMessage: String?

    private let attachmentStore = AttachmentStore.shared
    private let onAddRefund: () -> Void

    init(onAddRefund: @escaping () -> Void = {}) {
        self.onAddRefund = onAddRefund
    }

    private var results: [Refund] {
        listViewModel.results(
            from: refunds,
            now: dashboardViewModel.referenceDate
        )
    }

    private var retailers: [String] {
        RefundQueryService.availableRetailers(in: refunds)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                RefundBackdrop()
                combinedList
            }
            .navigationTitle("Refunds")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddRefund) {
                        Label("Add refund", systemImage: "plus")
                    }
                    .accessibilityIdentifier("refunds.addRefund")
                }
            }
            .navigationDestination(for: UUID.self) { refundID in
                if let refund = refunds.first(where: { $0.id == refundID }) {
                    RefundDetailView(
                        refund: refund,
                        deleteRecord: deleteRecord
                    )
                    .environment(settings)
                }
            }
            .sheet(isPresented: $isPresentingFilters) {
                RefundFilterSheet(
                    viewModel: listViewModel,
                    retailers: retailers
                )
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
            .onAppear {
                dashboardViewModel.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                dashboardViewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.significantTimeChangeNotification
                )
            ) { _ in
                dashboardViewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            ) { _ in
                dashboardViewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .NSSystemTimeZoneDidChange
                )
            ) { _ in
                dashboardViewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSLocale.currentLocaleDidChangeNotification
                )
            ) { _ in
                dashboardViewModel.refresh()
            }
        }
    }

    private var combinedList: some View {
        List {
            summaryHeader
                .listRowInsets(
                    EdgeInsets(top: 6, leading: 22, bottom: 0, trailing: 22)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            listToolsHeader
                .listRowInsets(
                    EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if isShowingSearch {
                searchField
                    .listRowInsets(
                        EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            scopePicker
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if refunds.isEmpty {
                RefundWorkflowEmptyState(kind: .firstRefund) {
                    onAddRefund()
                }
                .padding(.bottom, 28)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if results.isEmpty {
                RefundWorkflowEmptyState(kind: .noResults)
                    .padding(.bottom, 28)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(results) { refund in
                    NavigationLink(value: refund.id) {
                        RefundRowView(
                            refund: refund,
                            referenceDate: dashboardViewModel.referenceDate
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "refundRow_\(refund.id.uuidString)"
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(
                            "Delete",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            refundPendingDeletion = refund
                        }
                    }
                    .listRowInsets(
                        EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22)
                    )
                    .listRowSeparatorTint(RefundTheme.line)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .refreshable {
            dashboardViewModel.refresh()
        }
        .accessibilityIdentifier("refundList")
    }

    private var summaryHeader: some View {
        let metrics = dashboardViewModel.metrics(for: refunds)
        let preferredCurrency = settings.defaultCurrencyCode.uppercased()
        let primaryCurrency = metrics.awaitingAmountsByCurrency[preferredCurrency] != nil
            ? preferredCurrency
            : metrics.awaitingAmountsByCurrency.keys.sorted().first
                ?? preferredCurrency

        return RefundSummaryHeader(
            amount: metrics.awaitingAmountsByCurrency[primaryCurrency] ?? 0,
            currencyCode: primaryCurrency,
            otherAmounts: metrics.awaitingAmountsByCurrency.filter {
                $0.key.caseInsensitiveCompare(primaryCurrency) != .orderedSame
            },
            openCount: metrics.openReturnCount,
            overdueCount: metrics.overdueRefundCount,
            refundedCount: metrics.refundedCount
        )
    }

    private var listToolsHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 16) {
                Text("Returns")
                    .eyebrow(color: RefundTheme.ink)

                Spacer(minLength: 12)

                Button(action: toggleSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .regular))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    isShowingSearch ? RefundTheme.ink : RefundTheme.inkSoft
                )
                .accessibilityLabel(
                    isShowingSearch ? "Close search" : "Search refunds"
                )
                .accessibilityIdentifier("refundSearchButton")

                filterAndSortMenu
            }

            Hairline(color: RefundTheme.lineStrong)
        }
        .padding(.top, 32)
    }

    private var searchField: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(RefundTheme.inkFaint)
                    .accessibilityHidden(true)

                TextField(
                    "Merchant, item, order, or tracking",
                    text: $listViewModel.searchText
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .accessibilityIdentifier("refundSearchField")

                if !listViewModel.searchText.isEmpty {
                    Button {
                        listViewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(RefundTheme.inkFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .font(.system(.subheadline))
            .foregroundStyle(RefundTheme.ink)
            .padding(.vertical, 12)

            Hairline()
        }
    }

    private var scopePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 22) {
                ForEach(RefundFilterScope.quickScopes) { scope in
                    RefundScopeTab(
                        title: scope.displayName,
                        isSelected: listViewModel.selectedScope == scope
                    ) {
                        withAnimation(.snappy(duration: 0.2)) {
                            listViewModel.selectedScope = scope
                        }
                    }
                    .accessibilityIdentifier(scope.quickAccessibilityIdentifier)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 13)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var filterAndSortMenu: some View {
        Menu {
            Picker("Sort by", selection: $listViewModel.sortOption) {
                ForEach(RefundSortOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Picker("Direction", selection: $listViewModel.sortDirection) {
                Label("Ascending", systemImage: "arrow.up")
                    .tag(RefundSortDirection.ascending)
                Label("Descending", systemImage: "arrow.down")
                    .tag(RefundSortDirection.descending)
            }

            Divider()

            Button {
                isPresentingFilters = true
            } label: {
                Label(
                    advancedFilterLabel,
                    systemImage: "line.3.horizontal.decrease"
                )
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .regular))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .foregroundStyle(
            listViewModel.hasAdvancedFilters
                ? RefundTheme.ink
                : RefundTheme.inkSoft
        )
        .accessibilityLabel("Filter and sort refunds")
        .accessibilityIdentifier("refundFilterAndSortButton")
    }

    private var advancedFilterLabel: String {
        let count = listViewModel.hasAdvancedFilters
            ? listViewModel.appliedFilterCount
                - (listViewModel.selectedScope == .all ? 0 : 1)
            : 0
        return count == 0 ? "More filters" : "More filters (\(count))"
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func toggleSearch() {
        withAnimation(.snappy(duration: 0.2)) {
            isShowingSearch.toggle()
        }

        if isShowingSearch {
            Task { @MainActor in
                await Task.yield()
                isSearchFocused = true
            }
        } else {
            isSearchFocused = false
            listViewModel.searchText = ""
        }
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

/// A word with a rule under it when chosen. Replaces filled filter pills.
private struct RefundScopeTab: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .eyebrow(
                        size: 11,
                        color: isSelected
                            ? RefundTheme.ink
                            : RefundTheme.inkFaint
                    )
                    .lineLimit(1)

                Rectangle()
                    .fill(isSelected ? RefundTheme.ink : .clear)
                    .frame(height: 1.5)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filter")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension RefundFilterScope {
    var quickAccessibilityIdentifier: String {
        switch self {
        case .active:
            "refundScope.open"
        case .overdue:
            "refundScope.overdue"
        case .refunded:
            "refundScope.refunded"
        case .all:
            "refundScope.all"
        case .disputed:
            "refundScope.disputed"
        }
    }
}
