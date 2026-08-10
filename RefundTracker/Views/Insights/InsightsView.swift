import Charts
import SwiftData
import SwiftUI
import UIKit

struct InsightsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Query private var refunds: [Refund]

    @State private var viewModel = InsightsViewModel()
    @State private var selectedMode: InsightsMode = .completed

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                VStack(spacing: 0) {
                    InsightsModePicker(selection: $selectedMode)

                    switch selectedMode {
                    case .completed:
                        completedInsights
                    case .outstanding:
                        outstandingInsights
                    }
                }
            }
            .navigationTitle("Insights")
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
                NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
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

    @ViewBuilder
    private var completedInsights: some View {
        let currencyCode = viewModel.completedCurrencyCode(
            for: refunds,
            preferred: settings.defaultCurrencyCode
        )
        let snapshot = viewModel.metrics(
            for: refunds,
            currencyCode: currencyCode
        )

        if snapshot.completedRefundCount == 0 {
            ScrollView {
                InsightsModeEmptyState(mode: .completed)
            }
            .accessibilityIdentifier("insights.completedContent")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    CompletedHeader(
                        amount: snapshot.totalRefundsReceived,
                        currencyCode: currencyCode,
                        completedCount: snapshot.completedRefundCount,
                        averageDays: averageDaysLabel(snapshot.averageRefundDays),
                        merchantCount: snapshot.completedRetailerCount
                    )

                    MonthlyRefundChart(
                        totals: snapshot.monthlyRefundTotals,
                        currencyCode: currencyCode
                    )
                    .padding(.top, 44)

                    RetailerTimingSection(
                        retailers: Array(snapshot.retailerPerformance.prefix(5))
                    )
                    .padding(.top, 44)

                    Text("\(currencyCode) only · currencies are never converted")
                        .eyebrow(size: 9)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .refreshable {
                viewModel.refresh()
            }
            .accessibilityIdentifier("insights.completedContent")
        }
    }

    @ViewBuilder
    private var outstandingInsights: some View {
        if refunds.isEmpty {
            ScrollView {
                InsightsModeEmptyState(mode: .outstanding)
            }
            .accessibilityIdentifier("insights.outstandingContent")
        } else {
            let metrics = viewModel.outstandingMetrics(for: refunds)
            let preferredCurrency = settings.defaultCurrencyCode.uppercased()
            let primaryCurrency = metrics.awaitingAmountsByCurrency[preferredCurrency] != nil
                ? preferredCurrency
                : metrics.awaitingAmountsByCurrency.keys.sorted().first
                    ?? preferredCurrency

            ScrollView {
                RefundSummaryHeader(
                    amount: metrics.awaitingAmountsByCurrency[primaryCurrency] ?? 0,
                    currencyCode: primaryCurrency,
                    otherAmounts: metrics.awaitingAmountsByCurrency.filter {
                        $0.key.caseInsensitiveCompare(
                            primaryCurrency
                        ) != .orderedSame
                    },
                    openCount: metrics.openReturnCount,
                    overdueCount: metrics.overdueRefundCount,
                    refundedCount: metrics.refundedCount
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .refreshable {
                viewModel.refresh()
            }
            .accessibilityIdentifier("insights.outstandingContent")
        }
    }

    private func averageDaysLabel(_ days: Double?) -> String {
        guard let days else { return "—" }
        return "\(days.formatted(.number.precision(.fractionLength(days < 10 ? 1 : 0))))d"
    }
}

private enum InsightsMode: String, CaseIterable, Identifiable {
    case completed
    case outstanding

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .completed:
            "Completed"
        case .outstanding:
            "Outstanding"
        }
    }
}

private struct InsightsModePicker: View {
    @Binding var selection: InsightsMode

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(InsightsMode.allCases) { mode in
                    let isSelected = selection == mode

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selection = mode
                        }
                    } label: {
                        Text(mode.displayName)
                            .eyebrow(
                                size: 11,
                                color: isSelected
                                    ? RefundTheme.ink
                                    : RefundTheme.inkFaint
                            )
                            .padding(.bottom, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(
                                        isSelected
                                            ? RefundTheme.ink
                                            : .clear
                                    )
                                    .frame(height: 1.5)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.displayName)
                    .accessibilityValue(
                        isSelected ? "Selected" : "Not selected"
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("insights.mode.\(mode.rawValue)")
                }
            }
            .padding(.horizontal, 22)

            Hairline()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.modePicker")
    }
}

private struct CompletedHeader: View {
    let amount: Decimal
    let currencyCode: String
    let completedCount: Int
    let averageDays: String
    let merchantCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Back in your pocket")
                .eyebrow()

            Text(amount, format: .currency(code: currencyCode))
                .serif(46, relativeTo: .largeTitle)
                .foregroundStyle(RefundTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 10)

            Text(completedSummary)
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.inkSoft)
                .padding(.top, 6)

            Hairline()
                .padding(.top, 24)

            HStack(alignment: .top, spacing: 0) {
                InsightFigure(
                    value: completedCount.formatted(),
                    label: "Completed"
                )

                VerticalHairline(height: 40)

                InsightFigure(value: averageDays, label: "Avg wait")

                VerticalHairline(height: 40)

                InsightFigure(
                    value: merchantCount.formatted(),
                    label: merchantCount == 1 ? "Merchant" : "Merchants"
                )
            }
            .padding(.vertical, 18)

            Hairline()
        }
        .padding(.top, 22)
        .accessibilityIdentifier("insights.completedSummary")
    }

    private var completedSummary: String {
        completedCount == 1
            ? "One refund completed."
            : "\(completedCount) refunds completed."
    }
}

private struct InsightFigure: View {
    let value: String
    let label: String
    var tint: Color = RefundTheme.ink

    var body: some View {
        VStack(spacing: 7) {
            Text(value)
                .serif(22, relativeTo: .title2)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(label)
                .eyebrow(size: 9)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct InsightsModeEmptyState: View {
    let mode: InsightsMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .eyebrow()

            Text(title)
                .serif(30, relativeTo: .largeTitle)
                .foregroundStyle(RefundTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Hairline()
                .padding(.top, 24)

            Text(message)
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 40)
    }

    private var eyebrow: String {
        switch mode {
        case .completed:
            "Nothing completed yet"
        case .outstanding:
            "Nothing outstanding"
        }
    }

    private var title: String {
        switch mode {
        case .completed:
            "Completed patterns will show up here."
        case .outstanding:
            "No returns in flight."
        }
    }

    private var message: String {
        switch mode {
        case .completed:
            "Once a refund lands, Insights will track the amount, timing, and merchant history."
        case .outstanding:
            "New returns will appear here with the amount still due and anything running late."
        }
    }
}

private struct MonthlyRefundChart: View {
    let totals: [MonthlyRefundTotal]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            RefundSectionHeading(title: "By month", trailing: "Last six")

            Chart(totals) { total in
                BarMark(
                    x: .value("Month", total.month, unit: .month),
                    y: .value(
                        "Refund total",
                        NSDecimalNumber(decimal: total.amount).doubleValue
                    ),
                    width: .fixed(22)
                )
                .foregroundStyle(RefundTheme.ink)
                .accessibilityLabel(total.month.formatted(.dateTime.month(.wide)))
                .accessibilityValue(
                    total.amount.formatted(.currency(code: currencyCode))
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) {
                    AxisValueLabel(format: .dateTime.month(.narrow))
                        .font(.system(.caption2).weight(.semibold))
                        .foregroundStyle(RefundTheme.inkFaint)
                    AxisGridLine().foregroundStyle(.clear)
                    AxisTick().foregroundStyle(.clear)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(RefundTheme.line)
                    AxisTick().foregroundStyle(.clear)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(
                                amount,
                                format: .currency(code: currencyCode)
                                    .precision(.fractionLength(0))
                            )
                            .font(.system(.caption2))
                            .foregroundStyle(RefundTheme.inkFaint)
                        }
                    }
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Monthly refund totals chart")
        }
    }
}

private struct RetailerTimingSection: View {
    let retailers: [RetailerRefundPerformance]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RefundSectionHeading(title: "Merchants", trailing: "Avg days")

            if retailers.isEmpty {
                Text("Complete a refund with a received date to compare merchants.")
                    .font(.system(.footnote))
                    .foregroundStyle(RefundTheme.inkSoft)
                    .padding(.vertical, 22)
            } else {
                ForEach(retailers) { retailer in
                    HStack(spacing: 14) {
                        MerchantMark(name: retailer.retailerName, size: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(retailer.retailerName)
                                .font(.system(.subheadline).weight(.medium))
                                .foregroundStyle(RefundTheme.ink)
                                .lineLimit(1)

                            Text("\(retailer.completedRefundCount) completed")
                                .font(.system(.caption))
                                .foregroundStyle(RefundTheme.inkSoft)
                        }

                        Spacer(minLength: 8)

                        Text(
                            "\(retailer.averageDays.formatted(.number.precision(.fractionLength(1))))d"
                        )
                        .serif(19, relativeTo: .title3)
                        .foregroundStyle(RefundTheme.ink)
                    }
                    .padding(.vertical, 14)
                    .accessibilityElement(children: .combine)

                    Hairline()
                }
            }
        }
    }
}
