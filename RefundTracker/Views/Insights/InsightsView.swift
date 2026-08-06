import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var refunds: [Refund]

    @State private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if refunds.isEmpty {
                    ContentUnavailableView(
                        "Insights appear as you track",
                        systemImage: "chart.bar.xaxis",
                        description: Text(
                            "Your refund totals, timing trends, and retailer performance will show here."
                        )
                    )
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
        let currencyCode = settings.defaultCurrencyCode
        let snapshot = viewModel.metrics(
            for: refunds,
            currencyCode: currencyCode
        )

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    InsightMetricCard(
                        title: "Received",
                        value: snapshot.totalRefundsReceived.formatted(
                            .currency(code: currencyCode)
                        ),
                        detail: "All completed refunds",
                        systemImage: "checkmark.circle.fill",
                        tint: .green
                    )
                    InsightMetricCard(
                        title: "Still pending",
                        value: snapshot.totalRefundsPending.formatted(
                            .currency(code: currencyCode)
                        ),
                        detail: "Across open returns",
                        systemImage: "clock.fill",
                        tint: .blue
                    )
                    InsightMetricCard(
                        title: "Average time",
                        value: averageDaysLabel(snapshot.averageRefundDays),
                        detail: "Return to refund",
                        systemImage: "calendar.badge.clock",
                        tint: .indigo
                    )
                    InsightMetricCard(
                        title: "Overdue",
                        value: snapshot.overdueRefundValue.formatted(
                            .currency(code: currencyCode)
                        ),
                        detail: "\(snapshot.overdueRefundCount) \(snapshot.overdueRefundCount == 1 ? "refund" : "refunds")",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: snapshot.overdueRefundCount == 0 ? .green : .red
                    )
                }

                MonthlyRefundChart(
                    totals: snapshot.monthlyRefundTotals,
                    currencyCode: currencyCode
                )

                RetailerTimingSection(
                    retailers: Array(snapshot.retailerPerformance.prefix(5))
                )

                Text(
                    "Insights include \(currencyCode) records only. Currency values are never converted."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            viewModel.refresh()
        }
    }

    private func averageDaysLabel(_ days: Double?) -> String {
        guard let days else { return "—" }
        return "\(days.formatted(.number.precision(.fractionLength(days < 10 ? 1 : 0)))) days"
    }
}

private struct InsightMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value). \(detail)")
    }
}

private struct MonthlyRefundChart: View {
    let totals: [MonthlyRefundTotal]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly refunds")
                    .font(.title3.bold())
                Text("Money received over the last six months")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(totals) { total in
                BarMark(
                    x: .value("Month", total.month, unit: .month),
                    y: .value(
                        "Refund total",
                        NSDecimalNumber(decimal: total.amount).doubleValue
                    )
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(5)
                .accessibilityLabel(total.month.formatted(.dateTime.month(.wide)))
                .accessibilityValue(
                    total.amount.formatted(.currency(code: currencyCode))
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                    AxisGridLine()
                        .foregroundStyle(.clear)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(
                                amount,
                                format: .currency(code: currencyCode)
                                    .precision(.fractionLength(0))
                            )
                        }
                    }
                }
            }
            .frame(height: 220)
            .accessibilityLabel("Monthly refund totals chart")
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RetailerTimingSection: View {
    let retailers: [RetailerRefundPerformance]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Slowest retailers")
                    .font(.title3.bold())
                Text("Average days from return to refund")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if retailers.isEmpty {
                Label(
                    "Complete a refund to compare retailer timing",
                    systemImage: "hourglass"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(retailers.enumerated()), id: \.element.id) { index, retailer in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .background(
                                    Color(uiColor: .tertiarySystemFill),
                                    in: Circle()
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(retailer.retailerName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(
                                    "\(retailer.completedRefundCount) completed \(retailer.completedRefundCount == 1 ? "refund" : "refunds")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(
                                "\(retailer.averageDays.formatted(.number.precision(.fractionLength(1)))) days"
                            )
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        }
                        .padding(14)
                        .accessibilityElement(children: .combine)

                        if index < retailers.count - 1 {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
