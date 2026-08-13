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
                            OnboardingPageView(
                                page: page,
                                index: index,
                                total: pages.count
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    VStack(spacing: 18) {
                        Button(
                            selectedPage == pages.count - 1
                                ? "Track a refund"
                                : "Continue"
                        ) {
                            if selectedPage == pages.count - 1 {
                                finishAndAddRefund()
                            } else {
                                withAnimation(.snappy) {
                                    selectedPage += 1
                                }
                            }
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
                        .buttonStyle(RefundTextButtonStyle(tint: RefundTheme.inkSoft))
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 28)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        isPresented = false
                    }
                    .foregroundStyle(RefundTheme.inkSoft)
                }
            }
        }
        .tint(RefundTheme.ink)
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
    let index: Int
    let total: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(String(format: "%02d", index + 1)) / \(String(format: "%02d", total))")
                    .eyebrow()

                Text(page.title)
                    .serif(38, relativeTo: .largeTitle)
                    .foregroundStyle(RefundTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)

                Hairline()
                    .padding(.top, 26)

                Text(page.detail)
                    .font(.system(.callout))
                    .foregroundStyle(RefundTheme.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(page.highlights, id: \.title) { highlight in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(highlight.title)
                                .font(.system(.subheadline).weight(.medium))
                                .foregroundStyle(RefundTheme.ink)

                            Text(highlight.detail)
                                .font(.system(.footnote))
                                .foregroundStyle(RefundTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                        .accessibilityElement(children: .combine)

                        Hairline()
                    }
                }
                .padding(.top, 26)

                Text("Private · stored on this iPhone")
                    .eyebrow(size: 9)
                    .padding(.top, 26)
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
}

private struct OnboardingPage {
    struct Highlight {
        let title: String
        let detail: String
    }

    let title: String
    let detail: String
    let highlights: [Highlight]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            title: "Refunds, minus\nthe spreadsheet.",
            detail: "Merchant, amount, and the date it went back. That is the whole form.",
            highlights: [
                Highlight(
                    title: "Add one in seconds",
                    detail: "No order numbers, tracking codes, or busy forms."
                ),
                Highlight(
                    title: "Your currency is remembered",
                    detail: "Set it once and keep moving."
                )
            ]
        ),
        OnboardingPage(
            title: "Know what is\ncoming back.",
            detail: "The expected date is worked out for you, and anything late rises to the top.",
            highlights: [
                Highlight(
                    title: "Dates happen automatically",
                    detail: "Your expected refund date is calculated from the day it shipped."
                ),
                Highlight(
                    title: "Late refunds stand out",
                    detail: "One glance tells you what needs chasing."
                )
            ]
        )
    ]
}
