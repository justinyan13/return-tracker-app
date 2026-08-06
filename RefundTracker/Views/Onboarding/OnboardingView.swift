import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onAddRefund: () -> Void

    @State private var selectedPage = 0

    private let pages = OnboardingPage.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut(duration: 0.2), value: selectedPage)

                VStack(spacing: 12) {
                    Button {
                        if selectedPage == pages.count - 1 {
                            finishAndAddRefund()
                        } else {
                            withAnimation {
                                selectedPage += 1
                            }
                        }
                    } label: {
                        Label(
                            selectedPage == pages.count - 1
                                ? "Track my first refund"
                                : "Continue",
                            systemImage: selectedPage == pages.count - 1
                                ? "plus.circle.fill"
                                : "arrow.right"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboarding.primaryAction")

                    if selectedPage > 0 {
                        Button("Back") {
                            withAnimation {
                                selectedPage -= 1
                            }
                        }
                        .font(.subheadline.weight(.medium))
                    } else {
                        Button("Maybe later") {
                            isPresented = false
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                if selectedPage > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") {
                            isPresented = false
                        }
                    }
                }
            }
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
                Spacer(minLength: 18)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    page.tint.opacity(0.18),
                                    page.tint.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 190, height: 190)

                    Circle()
                        .strokeBorder(page.tint.opacity(0.2), lineWidth: 1)
                        .frame(width: 150, height: 150)

                    Image(systemName: page.systemImage)
                        .font(.system(size: 72, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(page.tint)
                }
                .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text(page.detail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(page.highlights, id: \.title) { highlight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: highlight.systemImage)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(page.tint)
                                .frame(width: 24)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(highlight.title)
                                    .font(.headline)
                                Text(highlight.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
        }
    }
}

private struct OnboardingPage {
    struct Highlight {
        let title: String
        let detail: String
        let systemImage: String
    }

    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let highlights: [Highlight]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            title: "Know what’s still coming",
            detail: "Keep every expected refund, amount, and due date together.",
            systemImage: "arrow.uturn.backward.circle.fill",
            tint: .blue,
            highlights: [
                Highlight(
                    title: "A clear money snapshot",
                    detail: "See how much is outstanding at a glance.",
                    systemImage: "dollarsign.circle"
                ),
                Highlight(
                    title: "Every return in one place",
                    detail: "Save tracking, dates, notes, and receipts.",
                    systemImage: "tray.full"
                )
            ]
        ),
        OnboardingPage(
            title: "Catch late refunds early",
            detail: "Expected dates turn into a focused follow-up list automatically.",
            systemImage: "calendar.badge.exclamationmark",
            tint: .orange,
            highlights: [
                Highlight(
                    title: "Automatic overdue status",
                    detail: "Know exactly when a retailer misses its date.",
                    systemImage: "exclamationmark.triangle"
                ),
                Highlight(
                    title: "Gentle reminders",
                    detail: "Choose when to be reminded before and after a due date.",
                    systemImage: "bell.badge"
                )
            ]
        ),
        OnboardingPage(
            title: "Calm, private tracking",
            detail: "Your refund records stay locally on this device.",
            systemImage: "lock.shield.fill",
            tint: .green,
            highlights: [
                Highlight(
                    title: "No account required",
                    detail: "Start immediately without a login or subscription.",
                    systemImage: "person.crop.circle.badge.checkmark"
                ),
                Highlight(
                    title: "Your data is portable",
                    detail: "Export a CSV whenever you need a copy.",
                    systemImage: "square.and.arrow.up"
                )
            ]
        )
    ]
}
