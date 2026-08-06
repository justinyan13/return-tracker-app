import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onAddRefund: () -> Void

    @State private var selectedPage = 0

    private let pages = OnboardingPage.all

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                VStack(spacing: 0) {
                    TabView(selection: $selectedPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            OnboardingPageView(page: page)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                    VStack(spacing: 13) {
                        Button {
                            if selectedPage == pages.count - 1 {
                                finishAndAddRefund()
                            } else {
                                withAnimation(.snappy) {
                                    selectedPage += 1
                                }
                            }
                        } label: {
                            Label(
                                selectedPage == pages.count - 1
                                    ? "Track a refund"
                                    : "Show me",
                                systemImage: selectedPage == pages.count - 1
                                    ? "plus"
                                    : "arrow.right"
                            )
                        }
                        .buttonStyle(RefundPrimaryButtonStyle())
                        .accessibilityIdentifier("onboarding.primaryAction")

                        Button(selectedPage == 0 ? "Maybe later" : "Back") {
                            if selectedPage == 0 {
                                isPresented = false
                            } else {
                                withAnimation(.snappy) {
                                    selectedPage -= 1
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled()
    }

    private func finishAndAddRefund() {
        isPresented = false
        Task { @MainActor in
            onAddRefund()
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 44)

                ZStack {
                    Circle()
                        .fill(page.tint.opacity(0.16))
                        .frame(width: 220, height: 220)
                        .blur(radius: 2)

                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(page.gradient)
                        .frame(width: 154, height: 154)
                        .overlay {
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .stroke(.white.opacity(0.42), lineWidth: 1)
                        }
                        .shadow(color: page.tint.opacity(0.34), radius: 28, y: 18)

                    Image(systemName: page.systemImage)
                        .font(.system(size: 65, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)

                    Image(systemName: page.floatingSymbol)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(RefundTheme.coral, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                        .shadow(color: RefundTheme.coral.opacity(0.35), radius: 12, y: 7)
                        .offset(x: 82, y: -70)
                }
                .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(page.eyebrow.uppercased())
                        .font(.caption.bold())
                        .tracking(1.3)
                        .foregroundStyle(page.tint)

                    Text(page.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .multilineTextAlignment(.center)

                    Text(page.detail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                VStack(spacing: 12) {
                    ForEach(page.highlights, id: \.title) { highlight in
                        HStack(spacing: 13) {
                            Image(systemName: highlight.systemImage)
                                .font(.body.bold())
                                .foregroundStyle(page.tint)
                                .frame(width: 38, height: 38)
                                .background(page.tint.opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(highlight.title)
                                    .font(.headline)
                                Text(highlight.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .refundGlassCard(tint: page.tint)

                Label("Private and stored on this iPhone", systemImage: "lock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
}

private struct OnboardingPage {
    struct Highlight {
        let title: String
        let detail: String
        let systemImage: String
    }

    let eyebrow: String
    let title: String
    let detail: String
    let systemImage: String
    let floatingSymbol: String
    let tint: Color
    let gradient: LinearGradient
    let highlights: [Highlight]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "Delightfully simple",
            title: "Refunds, minus the spreadsheet",
            detail: "Merchant, amount, and shipped date. That’s all it takes.",
            systemImage: "arrow.uturn.backward",
            floatingSymbol: "dollarsign",
            tint: RefundTheme.violet,
            gradient: LinearGradient(
                colors: [RefundTheme.violet, RefundTheme.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            highlights: [
                Highlight(
                    title: "Add one in seconds",
                    detail: "No order numbers, tracking codes, or busy forms.",
                    systemImage: "bolt.fill"
                ),
                Highlight(
                    title: "Your currency is remembered",
                    detail: "Set it once and keep moving.",
                    systemImage: "coloncurrencysign.circle"
                )
            ]
        ),
        OnboardingPage(
            eyebrow: "A tiny money radar",
            title: "Know what’s coming back",
            detail: "We estimate the date, surface anything late, and celebrate when it lands.",
            systemImage: "sparkles",
            floatingSymbol: "checkmark",
            tint: RefundTheme.mint,
            gradient: LinearGradient(
                colors: [RefundTheme.mint, RefundTheme.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            highlights: [
                Highlight(
                    title: "Dates happen automatically",
                    detail: "Your expected refund date is calculated for you.",
                    systemImage: "calendar.badge.clock"
                ),
                Highlight(
                    title: "Late refunds stand out",
                    detail: "One glance tells you what needs a nudge.",
                    systemImage: "eyes"
                )
            ]
        )
    ]
}
