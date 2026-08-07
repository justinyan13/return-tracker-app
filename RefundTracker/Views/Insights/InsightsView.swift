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
            .navigationTitle("Money story")
            .toolbarBackground(.hidden, for: .navigationBar)
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
            LazyVStack(alignment: .leading, spacing: 22) {
                MoneyBackHero(
                    amount: snapshot.totalRefundsReceived,
                    pendingAmount: snapshot.totalRefundsPending,
                    currencyCode: currencyCode
                )

                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        InsightBubble(
                            title: "Average wait",
                            value: averageDaysLabel(snapshot.averageRefundDays),
                            symbol: "calendar.badge.clock",
                            tint: RefundTheme.blue
                        )
                        InsightBubble(
                            title: "Overdue",
                            value: "\(snapshot.overdueRefundCount)",
                            symbol: "exclamationmark.bubble.fill",
                            tint: snapshot.overdueRefundCount == 0
                                ? RefundTheme.mint
                                : RefundTheme.coral
                        )
                        InsightBubble(
                            title: "Still coming",
                            value: snapshot.totalRefundsPending.formatted(
                                .currency(code: currencyCode)
                            ),
                            symbol: "arrow.down.to.line.compact",
                            tint: RefundTheme.mango
                        )
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)

                MonthlyRefundChart(
                    totals: snapshot.monthlyRefundTotals,
                    currencyCode: currencyCode
                )

                RetailerTimingSection(
                    retailers: Array(snapshot.retailerPerformance.prefix(5))
                )

                Text("Showing \(currencyCode) only · currencies are never converted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private var insightsEmptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 112, height: 112)
                .background(
                    LinearGradient(
                        colors: [RefundTheme.violet, RefundTheme.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
                .shadow(color: RefundTheme.violet.opacity(0.28), radius: 22, y: 13)

            Text("Your money story starts here")
                .font(.title2.bold())

            Text("A few tracked refunds are all it takes to reveal timing and totals.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .refundGlassCard(tint: RefundTheme.pink, padding: 22)
        .padding(20)
    }

    private func averageDaysLabel(_ days: Double?) -> String {
        guard let days else { return "—" }
        return "\(days.formatted(.number.precision(.fractionLength(days < 10 ? 1 : 0))))d"
    }
}

private struct MoneyBackHero: View {
    let amount: Decimal
    let pendingAmount: Decimal
    let currencyCode: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [RefundTheme.violet, RefundTheme.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 180, height: 180)
                .offset(x: 55, y: -72)

            Image(systemName: "party.popper.fill")
                .font(.system(size: 42))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.9))
                .padding(24)

            VStack(alignment: .leading, spacing: 8) {
                Text("BACK IN YOUR POCKET")
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.76))

                Text(amount, format: .currency(code: currencyCode))
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)

                Label(
                    "\(pendingAmount.formatted(.currency(code: currencyCode))) still on the way",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.14), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .padding(.top, 28)
        }
        .frame(minHeight: 210)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: RefundTheme.violet.opacity(0.28), radius: 26, y: 16)
        .accessibilityElement(children: .combine)
    }
}

private struct InsightBubble: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.13), in: Circle())

            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(
            minWidth: 132,
            maxWidth: 132,
            minHeight: 126,
            alignment: .leading
        )
        .refundGlassCard(tint: tint, padding: 16)
        .accessibilityElement(children: .combine)
    }
}

private struct MonthlyRefundChart: View {
    let totals: [MonthlyRefundTotal]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            RefundSectionHeading(
                title: "The comeback",
                subtitle: "Refunds received over six months",
                symbol: "waveform.path.ecg"
            )

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
                        colors: [RefundTheme.violet, RefundTheme.pink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(7)
                .accessibilityLabel(total.month.formatted(.dateTime.month(.wide)))
                .accessibilityValue(
                    total.amount.formatted(.currency(code: currencyCode))
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) {
                    AxisValueLabel(format: .dateTime.month(.narrow))
                    AxisGridLine().foregroundStyle(.clear)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.16))
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
            .frame(height: 210)
            .accessibilityLabel("Monthly refund totals chart")
        }
        .refundGlassCard(tint: RefundTheme.violet)
    }
}

private struct RetailerTimingSection: View {
    let retailers: [RetailerRefundPerformance]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RefundSectionHeading(
                title: "Who takes their time?",
                subtitle: "Average days until money comes back",
                symbol: "hourglass"
            )

            if retailers.isEmpty {
                Label(
                    "Complete a refund to compare merchants",
                    systemImage: "sparkles"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .refundGlassCard(tint: RefundTheme.mango)
            } else {
                VStack(spacing: 12) {
                    ForEach(retailers) { retailer in
                        HStack(spacing: 12) {
                            MerchantMark(name: retailer.retailerName, size: 44)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(retailer.retailerName)
                                    .font(.headline)
                                    .lineLimit(1)

                                Text(
                                    "\(retailer.completedRefundCount) completed"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(
                                "\(retailer.averageDays.formatted(.number.precision(.fractionLength(1))))d"
                            )
                            .font(.title3.bold())
                            .monospacedDigit()
                            .foregroundStyle(RefundTheme.color(for: retailer.retailerName))
                        }
                        .refundGlassCard(
                            tint: RefundTheme.color(for: retailer.retailerName),
                            padding: 14
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
