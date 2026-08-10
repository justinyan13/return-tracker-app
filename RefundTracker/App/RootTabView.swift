import SwiftUI

struct RootTabView: View {
    @Environment(AppSettings.self) private var settings
    private enum Tab: Hashable {
        case dashboard
        case refunds
        case add
        case insights
        case settings
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var selectedTab: Tab = .dashboard
    @State private var previousTab: Tab = .dashboard
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
            DashboardView {
                presentAddRefund()
            }
            .id(queryRevision)
            .tabItem {
                Image(systemName: "square.stack")
                    .accessibilityLabel("Overview")
            }
            .tag(Tab.dashboard)

            RefundListView()
                .id(queryRevision)
                .tabItem {
                    Image(systemName: "list.bullet")
                        .accessibilityLabel("Refunds")
                }
                .tag(Tab.refunds)

            Color.clear
                .tabItem {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add")
                }
                .tag(Tab.add)
                .accessibilityIdentifier("addRefundButton")

            InsightsView()
                .id(queryRevision)
                .tabItem {
                    Image(systemName: "chart.bar")
                        .accessibilityLabel("Insights")
                }
                .tag(Tab.insights)

            SettingsView()
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                        .accessibilityLabel("Settings")
                }
                .tag(Tab.settings)
        }
        .tint(RefundTheme.ink)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: selectedTab) { oldValue, newValue in
            guard newValue == .add else {
                previousTab = newValue
                return
            }
            selectedTab = oldValue == .add ? previousTab : oldValue
            presentAddRefund()
        }
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
