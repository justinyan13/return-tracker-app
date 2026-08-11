import SwiftUI

struct RootTabView: View {
    @Environment(AppSettings.self) private var settings
    private enum AppTab: Hashable {
        case refunds
        case insights
        case settings
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var selectedTab: AppTab = .refunds
    @State private var isPresentingAddRefund = false
    @State private var isPresentingOnboarding = false
    @State private var isShowingStartupError = false
    @State private var queryRevision = UUID()
    @State private var reminderErrorMessage: String?

    let isUITesting: Bool
    let startupErrorMessage: String?

    init(
        isUITesting: Bool = false,
        startupErrorMessage: String? = nil
    ) {
        self.isUITesting = isUITesting
        self.startupErrorMessage = startupErrorMessage
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.refunds) {
                RefundListView(onAddRefund: presentAddRefund)
            } label: {
                Label("Refunds", systemImage: "list.clipboard")
                    .labelStyle(.iconOnly)
            }

            Tab(value: AppTab.insights) {
                InsightsView()
                    .id(queryRevision)
            } label: {
                Label("Insights", systemImage: "chart.bar.fill")
                    .labelStyle(.iconOnly)
            }

            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
                    .labelStyle(.iconOnly)
            }
        }
        .tint(RefundTheme.ink)
        .windowAppearance(settings.appearance)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $isPresentingAddRefund) {
            RefundFormView()
                .environment(settings)
                .presentationCornerRadius(6)
        }
        .fullScreenCover(isPresented: $isPresentingOnboarding) {
            OnboardingView(isPresented: $isPresentingOnboarding) {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    presentAddRefund()
                }
            }
        }
        .alert(
            "Temporary data mode",
            isPresented: $isShowingStartupError
        ) {
            Button("Continue", role: .cancel) {}
        } message: {
            Text(startupErrorMessage ?? "")
        }
        .alert(
            "Refund saved, but reminders weren’t updated",
            isPresented: reminderErrorBinding
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reminderErrorMessage ?? "You can try again from Settings.")
        }
        .task {
            if let startupErrorMessage, !startupErrorMessage.isEmpty {
                isShowingStartupError = true
            }

            guard !isUITesting, !hasCompletedOnboarding else { return }
            isPresentingOnboarding = true
        }
        .onChange(of: isPresentingOnboarding) { wasPresented, isPresented in
            if wasPresented && !isPresented {
                hasCompletedOnboarding = true
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .refundDataDidChange)
        ) { _ in
            queryRevision = UUID()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .refundReminderSchedulingFailed
            )
        ) { notification in
            reminderErrorMessage = notification.object as? String
                ?? "You can try again from Settings."
        }
    }

    private func presentAddRefund() {
        isPresentingAddRefund = true
    }

    private var reminderErrorBinding: Binding<Bool> {
        Binding(
            get: { reminderErrorMessage != nil },
            set: { if !$0 { reminderErrorMessage = nil } }
        )
    }
}
