import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Refund.expectedRefundDate) private var refunds: [Refund]

    @State private var viewModel = DashboardViewModel()

    let onAddRefund: () -> Void

    init(onAddRefund: @escaping () -> Void = {}) {
        self.onAddRefund = onAddRefund
    }

    var body: some View {
        NavigationStack {
            Group {
                if refunds.isEmpty {
                    DashboardEmptyState(onAddRefund: onAddRefund)
                } else {
                    dashboard
                }
            }
            .navigationTitle("Dashboard")
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

        return ScrollView {
            LazyVStack(spacing: 20) {
                AwaitingRefundCard(
                    amount: metrics.awaitingAmountsByCurrency[
                        settings.defaultCurrencyCode
                    ] ?? 0,
                    currencyCode: settings.defaultCurrencyCode,
                    otherAmounts: metrics.awaitingAmountsByCurrency.filter {
                        $0.key.caseInsensitiveCompare(
                            settings.defaultCurrencyCode
                        ) != .orderedSame
                    }
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    DashboardMetricCard(
                        title: "Open returns",
                        value: metrics.openReturnCount.formatted(),
                        systemImage: "shippingbox",
                        tint: .blue
                    )
                    DashboardMetricCard(
                        title: "Overdue",
                        value: metrics.overdueRefundCount.formatted(),
                        systemImage: "exclamationmark.triangle.fill",
                        tint: metrics.overdueRefundCount == 0 ? .green : .red
                    )
                    DashboardMetricCard(
                        title: "Refunded this month",
                        value: metrics.completedThisMonthCount.formatted(),
                        systemImage: "checkmark.circle.fill",
                        tint: .green
                    )
                }

                DashboardRefundSection(
                    title: "Needs attention",
                    subtitle: "Late or disputed refunds",
                    refunds: metrics.attentionRefunds,
                    emptyTitle: "Nothing needs attention",
                    emptySystemImage: "checkmark.shield.fill",
                    referenceDate: viewModel.referenceDate
                )

                DashboardRefundSection(
                    title: "Coming up",
                    subtitle: "Expected in the next two weeks",
                    refunds: metrics.upcomingRefunds,
                    emptyTitle: "No refunds due soon",
                    emptySystemImage: "calendar.badge.checkmark",
                    referenceDate: viewModel.referenceDate
                )
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            viewModel.refresh()
        }
    }
}

private struct AwaitingRefundCard: View {
    let amount: Decimal
    let currencyCode: String
    let otherAmounts: [String: Decimal]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Awaiting refund", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))

            Text(amount, format: .currency(code: currencyCode))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Text("Open returns recorded in \(currencyCode)")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.78))

            if !otherAmounts.isEmpty {
                Divider()
                    .overlay(.white.opacity(0.28))

                Text(otherAmountsDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            accessibilityDescription
        )
    }

    private var otherAmountsDescription: String {
        let sorted = otherAmounts.sorted { $0.key < $1.key }
        let displayed = sorted.prefix(2).map { code, amount in
            "\(amount.formatted(.currency(code: code))) \(code)"
        }
        let remainingCount = sorted.count - displayed.count
        let suffix = remainingCount > 0 ? " and \(remainingCount) more" : ""
        return "Also waiting: \(displayed.joined(separator: " · "))\(suffix)"
    }

    private var accessibilityDescription: String {
        let primary = "Total awaiting refund in \(currencyCode): \(amount.formatted(.currency(code: currencyCode)))"
        guard !otherAmounts.isEmpty else { return primary }
        return "\(primary). \(otherAmountsDescription)"
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct DashboardRefundSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    let title: String
    let subtitle: String
    let refunds: [Refund]
    let emptyTitle: String
    let emptySystemImage: String
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if refunds.isEmpty {
                Label(emptyTitle, systemImage: emptySystemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel(emptyTitle)
            } else {
                VStack(spacing: 0) {
                    ForEach(refunds) { refund in
                        NavigationLink {
                            RefundDetailView(
                                refund: refund,
                                deleteRecord: deleteRecord
                            )
                                .environment(settings)
                        } label: {
                            DashboardRefundRow(
                                refund: refund,
                                referenceDate: referenceDate
                            )
                        }
                        .buttonStyle(.plain)

                        if refund.id != refunds.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
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

private struct DashboardRefundRow: View {
    let refund: Refund
    let referenceDate: Date

    private var effectiveStatus: RefundStatus {
        refund.effectiveStatus(on: referenceDate, calendar: .current)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(refund.retailerName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(refund.itemName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(expectedDateDescription, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(effectiveStatus == .overdue ? .red : .secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 7) {
                RefundAmountLabel(
                    amount: refund.refundAmount,
                    currencyCode: refund.currencyCode,
                    style: .subheadline.weight(.semibold)
                )
                RefundStatusBadge(status: effectiveStatus)
            }

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens refund details")
    }

    private var expectedDateDescription: String {
        let calendar = Calendar.current
        let expected = calendar.startOfDay(for: refund.expectedRefundDate)
        let today = calendar.startOfDay(for: referenceDate)
        let days = calendar.dateComponents([.day], from: today, to: expected).day ?? 0

        switch days {
        case ..<(-1):
            return "\(abs(days)) days overdue"
        case -1:
            return "1 day overdue"
        case 0:
            return "Expected today"
        case 1:
            return "Expected tomorrow"
        default:
            return "Expected \(expected.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

private struct DashboardEmptyState: View {
    let onAddRefund: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Never lose track of a refund", systemImage: "arrow.uturn.backward.circle.fill")
        } description: {
            Text(
                "Add a return once, and Refund Tracker will keep expected dates, amounts, and follow-ups in one calm place."
            )
        } actions: {
            Button(action: onAddRefund) {
                Label("Track your first refund", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("dashboard.empty.addRefund")
        }
        .padding()
    }
}
