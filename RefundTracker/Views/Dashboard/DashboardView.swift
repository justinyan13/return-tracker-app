import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Refund.expectedRefundDate) private var refunds: [Refund]

    @State private var viewModel = DashboardViewModel()

    let onAddRefund: () -> Void

    init(onAddRefund: @escaping () -> Void = {}) {
        self.onAddRefund = onAddRefund
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                if refunds.isEmpty {
                    DashboardEmptyState(onAddRefund: onAddRefund)
                } else {
                    dashboard
                }
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddRefund) {
                        Label("Add refund", systemImage: "plus")
                    }
                    .accessibilityIdentifier("dashboard.addRefund")
                }
            }
            .onAppear {
                viewModel.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                viewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.significantTimeChangeNotification
                )
            ) { _ in
                viewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .NSCalendarDayChanged
                )
            ) { _ in
                viewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .NSSystemTimeZoneDidChange
                )
            ) { _ in
                viewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSLocale.currentLocaleDidChangeNotification
                )
            ) { _ in
                viewModel.refresh()
            }
        }
    }

    private var dashboard: some View {
        let metrics = viewModel.metrics(for: refunds)
        let stream = returnsStream(at: viewModel.referenceDate)
        let preferredCurrency = settings.defaultCurrencyCode.uppercased()
        let primaryCurrency = metrics.awaitingAmountsByCurrency[preferredCurrency] != nil
            ? preferredCurrency
            : metrics.awaitingAmountsByCurrency.keys.sorted().first
                ?? preferredCurrency

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                OutstandingHeader(
                    amount: metrics.awaitingAmountsByCurrency[primaryCurrency] ?? 0,
                    currencyCode: primaryCurrency,
                    otherAmounts: metrics.awaitingAmountsByCurrency.filter {
                        $0.key.caseInsensitiveCompare(
                            primaryCurrency
                        ) != .orderedSame
                    },
                    openCount: metrics.openReturnCount,
                    overdueCount: metrics.overdueRefundCount,
                    refundedCount: metrics.completedThisMonthCount
                )

                RefundSectionHeading(
                    title: "In progress",
                    trailing: stream.isEmpty ? nil : "Late first"
                )
                .padding(.top, 40)

                if stream.isEmpty {
                    DashboardAllCaughtUp()
                } else {
                    ForEach(stream) { refund in
                        NavigationLink {
                            RefundDetailView(
                                refund: refund,
                                deleteRecord: deleteRecord
                            )
                            .environment(settings)
                        } label: {
                            RefundRowView(
                                refund: refund,
                                referenceDate: viewModel.referenceDate
                            )
                        }
                        .buttonStyle(.plain)

                        Hairline()
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private func returnsStream(at date: Date) -> [Refund] {
        refunds
            .filter {
                $0.effectiveStatus(on: date, calendar: .current).isOpen
            }
            .sorted { lhs, rhs in
                let lhsStatus = lhs.effectiveStatus(on: date, calendar: .current)
                let rhsStatus = rhs.effectiveStatus(on: date, calendar: .current)
                if lhsStatus.sortOrder != rhsStatus.sortOrder {
                    return lhsStatus.sortOrder < rhsStatus.sortOrder
                }
                return lhs.expectedRefundDate < rhs.expectedRefundDate
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

/// The figure the screen exists for, set large in serif, with the three counts
/// beneath it on a ruled strip.
private struct OutstandingHeader: View {
    let amount: Decimal
    let currencyCode: String
    let otherAmounts: [String: Decimal]
    let openCount: Int
    let overdueCount: Int
    let refundedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outstanding")
                .eyebrow()

            Text(amount, format: .currency(code: currencyCode))
                .serif(46, relativeTo: .largeTitle)
                .foregroundStyle(RefundTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 10)

            Text(summary)
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.inkSoft)
                .padding(.top, 6)

            if !otherAmounts.isEmpty {
                Text(otherAmountsDescription)
                    .eyebrow(size: 10)
                    .padding(.top, 10)
            }

            Hairline()
                .padding(.top, 22)

            HStack(alignment: .top, spacing: 0) {
                DashboardCount(value: openCount, label: "Open")

                VerticalHairline(height: 40)

                DashboardCount(
                    value: overdueCount,
                    label: "Overdue",
                    tint: overdueCount == 0 ? RefundTheme.ink : RefundTheme.alert
                )

                VerticalHairline(height: 40)

                DashboardCount(value: refundedCount, label: "Refunded")
            }
            .padding(.vertical, 18)

            Hairline()
        }
        .padding(.top, 6)
        .accessibilityElement(children: .contain)
    }

    private var summary: String {
        if openCount == 0 {
            return "Everything has landed."
        }
        if overdueCount > 0 {
            return overdueCount == 1
                ? "One refund is running late."
                : "\(overdueCount) refunds are running late."
        }
        return openCount == 1
            ? "One refund on the way."
            : "\(openCount) refunds on the way."
    }

    private var otherAmountsDescription: String {
        let sorted = otherAmounts.sorted { $0.key < $1.key }
        // The formatted amount already carries the symbol or the code, so
        // appending the code again reads as "WST 64.90 WST".
        let displayed = sorted.prefix(2).map { code, amount in
            amount.formatted(.currency(code: code))
        }
        let remainder = sorted.count - displayed.count
        let suffix = remainder > 0 ? " +\(remainder)" : ""
        return "Also due · \(displayed.joined(separator: " · "))\(suffix)"
    }
}

private struct DashboardCount: View {
    let value: Int
    let label: String
    var tint: Color = RefundTheme.ink

    var body: some View {
        VStack(spacing: 7) {
            Text(value.formatted())
                .serif(26, relativeTo: .title)
                .foregroundStyle(tint)

            Text(label)
                .eyebrow(size: 9)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct DashboardAllCaughtUp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All clear")
                .serif(22, relativeTo: .title2)
                .foregroundStyle(RefundTheme.ink)

            Text("Nothing is waiting on a merchant right now.")
                .font(.system(.footnote))
                .foregroundStyle(RefundTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 26)
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardEmptyState: View {
    let onAddRefund: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Refund Tracker")
                    .eyebrow()

                Text("Know exactly what is\nowed back to you.")
                    .serif(34, relativeTo: .largeTitle)
                    .foregroundStyle(RefundTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)

                Hairline()
                    .padding(.top, 26)

                Text(
                    "Add a return once. The amount, the expected date, and anything running late stay one glance away."
                )
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

                Button("Track my first refund", action: onAddRefund)
                    .buttonStyle(RefundPrimaryButtonStyle())
                    .padding(.top, 32)
                    .accessibilityIdentifier("dashboard.empty.addRefund")
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
        }
    }
}
