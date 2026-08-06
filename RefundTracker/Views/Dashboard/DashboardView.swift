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
            .navigationTitle("Dashboard")
            .toolbarBackground(.hidden, for: .navigationBar)
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
            LazyVStack(alignment: .leading, spacing: 18) {
                MoneyComingBackHero(
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
                    title: "Returns in motion",
                    subtitle: stream.isEmpty
                        ? "Your refund queue is clear"
                        : "Overdue first, then what’s coming back",
                    symbol: "arrow.uturn.backward.circle.fill"
                )
                .padding(.horizontal, 4)

                if stream.isEmpty {
                    DashboardAllCaughtUpCard()
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
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
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

private struct MoneyComingBackHero: View {
    let amount: Decimal
    let currencyCode: String
    let otherAmounts: [String: Decimal]
    let openCount: Int
    let overdueCount: Int
    let refundedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MONEY COMING BACK")
                        .font(.caption.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(RefundTheme.violet)

                    Text(amount, format: .currency(code: currencyCode))
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(
                            RefundTheme.gradient(for: "money coming back")
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    Text(heroMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                MoneyReturnGlyph()
            }

            if !otherAmounts.isEmpty {
                Text(otherAmountsDescription)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.thinMaterial, in: Capsule())
            }

            Divider()
                .overlay(RefundTheme.violet.opacity(0.16))

            HStack(spacing: 0) {
                DashboardSignal(
                    value: openCount,
                    label: "Open",
                    systemImage: "shippingbox.fill",
                    tint: RefundTheme.blue
                )

                SignalDivider()

                DashboardSignal(
                    value: overdueCount,
                    label: "Overdue",
                    systemImage: "exclamationmark.circle.fill",
                    tint: overdueCount == 0
                        ? RefundTheme.mint
                        : RefundTheme.coral
                )

                SignalDivider()

                DashboardSignal(
                    value: refundedCount,
                    label: "Refunded",
                    systemImage: "checkmark.circle.fill",
                    tint: RefundTheme.mint
                )
            }
        }
        .refundGlassCard(tint: RefundTheme.violet, padding: 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Money coming back: \(amount.formatted(.currency(code: currencyCode))). \(heroMessage)"
        )
    }

    private var heroMessage: String {
        if openCount == 0 {
            return "Everything has made its way home."
        }
        if overdueCount > 0 {
            return "\(overdueCount) \(overdueCount == 1 ? "refund needs" : "refunds need") a friendly nudge."
        }
        return "\(openCount) \(openCount == 1 ? "refund is" : "refunds are") on the way."
    }

    private var otherAmountsDescription: String {
        let sorted = otherAmounts.sorted { $0.key < $1.key }
        let displayed = sorted.prefix(2).map { code, amount in
            "\(amount.formatted(.currency(code: code))) \(code)"
        }
        let remainder = sorted.count - displayed.count
        let suffix = remainder > 0 ? " +\(remainder) more" : ""
        return "Also returning · \(displayed.joined(separator: " · "))\(suffix)"
    }
}

private struct MoneyReturnGlyph: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            RefundTheme.mint.opacity(0.24),
                            RefundTheme.blue.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 66, height: 66)

            Image(systemName: "banknote.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(RefundTheme.mint)
                .frame(width: 66, height: 66)

            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, RefundTheme.violet)
                .background(.white, in: Circle())
        }
        .accessibilityHidden(true)
    }
}

private struct DashboardSignal: View {
    let value: Int
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                Text(value.formatted())
                    .font(.headline.weight(.heavy))
                    .monospacedDigit()
            }

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct SignalDivider: View {
    var body: some View {
        Rectangle()
            .fill(RefundTheme.violet.opacity(0.13))
            .frame(width: 1, height: 34)
            .accessibilityHidden(true)
    }
}

private struct DashboardAllCaughtUpCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.bold))
                .foregroundStyle(RefundTheme.mint)
                .frame(width: 48, height: 48)
                .background(RefundTheme.mint.opacity(0.13), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("All caught up")
                    .font(.headline)
                Text("No open returns need your attention.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .refundGlassCard(tint: RefundTheme.mint, padding: 16)
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardEmptyState: View {
    let onAddRefund: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(RefundTheme.gradient(for: "first refund"))
                        .frame(width: 104, height: 104)

                    Image(systemName: "banknote.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 104, height: 104)

                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, RefundTheme.mint)
                        .background(.white, in: Circle())
                }
                .accessibilityHidden(true)

                VStack(spacing: 9) {
                    Text("Bring your money back")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .multilineTextAlignment(.center)

                    Text(
                        "Add a return once. We’ll keep the amount, expected date, and next nudge easy to spot."
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                Button(action: onAddRefund) {
                    Label("Track my first refund", systemImage: "plus")
                }
                .buttonStyle(RefundPrimaryButtonStyle())
                .accessibilityIdentifier("dashboard.empty.addRefund")
            }
            .refundGlassCard(tint: RefundTheme.violet, padding: 24)
            .padding(.horizontal, 20)
            .padding(.top, 36)
        }
    }
}
