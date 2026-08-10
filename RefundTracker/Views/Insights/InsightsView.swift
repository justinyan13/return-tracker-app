import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var refunds: [Refund]

    @State private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                if refunds.isEmpty {
                    insightsEmptyState
                } else {
                    insights
                }
            }
            .navigationTitle("Insights")
            .onAppear {
                viewModel.refresh()
            }
        }
    }

    private var insights: some View {
        let currencyCode = viewModel.displayCurrencyCode(
            for: refunds,
            preferred: settings.defaultCurrencyCode
        )
        let snapshot = viewModel.metrics(
            for: refunds,
            currencyCode: currencyCode
        )

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ReceivedHeader(
                    amount: snapshot.totalRefundsReceived,
                    pendingAmount: snapshot.totalRefundsPending,
                    currencyCode: currencyCode,
                    averageDays: averageDaysLabel(snapshot.averageRefundDays),
                    overdueCount: snapshot.overdueRefundCount
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
    }

    private var insightsEmptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nothing to measure yet")
                .eyebrow()

            Text("Patterns show up\nafter a return or two.")
                .serif(30, relativeTo: .largeTitle)
                .foregroundStyle(RefundTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Hairline()
                .padding(.top, 24)

            Text("Track a few refunds and this page will show how long merchants take and what has landed.")
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
    }

    private func averageDaysLabel(_ days: Double?) -> String {
        guard let days else { return "—" }
        return "\(days.formatted(.number.precision(.fractionLength(days < 10 ? 1 : 0))))d"
    }
}

private struct ReceivedHeader: View {
    let amount: Decimal
    let pendingAmount: Decimal
    let currencyCode: String
    let averageDays: String
    let overdueCount: Int

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

            Hairline()
                .padding(.top, 24)

            HStack(alignment: .top, spacing: 0) {
                InsightFigure(value: averageDays, label: "Avg wait")

                VerticalHairline(height: 40)

                InsightFigure(
                    value: overdueCount.formatted(),
                    label: "Overdue",
                    tint: overdueCount == 0 ? RefundTheme.ink : RefundTheme.alert
                )

                VerticalHairline(height: 40)

                InsightFigure(
                    value: pendingAmount.formatted(
                        .currency(code: currencyCode).precision(.fractionLength(0))
                    ),
                    label: "Still due"
                )
            }
            .padding(.vertical, 18)

            Hairline()
        }
        .padding(.top, 6)
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
                Text("Complete a refund to compare merchants.")
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
