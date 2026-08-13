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
    @State private var isShowingSearch = false
    @FocusState private var isSearchFocused: Bool
    @State private var errorMessage: String?

    private let attachmentStore = AttachmentStore.shared
    private let onAddRefund: () -> Void
    private let onOpenSettings: () -> Void

    init(
        onAddRefund: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.onAddRefund = onAddRefund
        self.onOpenSettings = onOpenSettings
    }

    private var results: [Refund] {
        listViewModel.results(
            from: refunds,
            now: dashboardViewModel.referenceDate
        )
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

                // Keeps the two buttons in their own glass capsules instead of
                // sharing one.
                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onOpenSettings) {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("refunds.openSettings")
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
                    .navigationLinkIndicatorVisibility(.hidden)
                    .accessibilityIdentifier(
                        "refundRow_\(refund.id.uuidString)"
                    )
                    .contentShape(
                        .contextMenuPreview,
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .contextMenu {
                        Button {
                            navigationPath.append(refund.id)
                        } label: {
                            Label(
                                "Open details",
                                systemImage: "arrow.up.right.square"
                            )
                        }
                        .accessibilityIdentifier("refundPreviewOpenDetails")

                        Button(role: .destructive) {
                            delete(refund)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        .accessibilityIdentifier("refundPreviewDelete")
                    } preview: {
                        RefundPreviewView(
                            refund: refund,
                            referenceDate: dashboardViewModel.referenceDate
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            delete(refund)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        .tint(.red)
                        .accessibilityIdentifier("refundSwipeDelete")
                    }
                    .listRowInsets(
                        EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22)
                    )
                    .listRowSeparatorTint(RefundTheme.line)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .listRowBackground(RefundTheme.paper)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .accessibilityIdentifier("refundList")
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

                sortMenu
            }

            Hairline(color: RefundTheme.lineStrong)
        }
        .padding(.top, 8)
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
                ForEach(RefundFilterScope.allCases) { scope in
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

    private var sortMenu: some View {
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
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .regular))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .foregroundStyle(RefundTheme.inkSoft)
        .accessibilityLabel("Sort refunds")
        .accessibilityIdentifier("refundSortButton")
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

    private func delete(_ refund: Refund) {
        let refundID = refund.id
        let storedFilenames = refund.attachments.map(\.storedFilename)
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
        withAnimation(.smooth(duration: 0.24)) {
            modelContext.delete(refund)
            modelContext.processPendingChanges()
        }
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
        }
    }
}
