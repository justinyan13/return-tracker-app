import SwiftUI

/// A single rule with dots on it: filled for what has happened, hollow for what
/// has not. No coloured icon wells.
struct RefundTimelineView: View {
    let refund: Refund

    private var events: [RefundTimelineEvent] {
        var result: [RefundTimelineEvent] = []

        if let shippedDate = refund.shippedDate {
            result.append(
                RefundTimelineEvent(
                    id: "shipped",
                    title: "Return shipped",
                    date: shippedDate,
                    state: .completed
                )
            )
        } else if refund.isAwaitingShipment, let shipByDate = refund.shipByDate {
            let isLate = refund.isShipmentOverdue()
            result.append(
                RefundTimelineEvent(
                    id: "shipBy",
                    title: isLate ? "Send it — deadline passed" : "Send by",
                    date: shipByDate,
                    state: isLate ? .attention : .upcoming
                )
            )
        } else {
            result.append(
                RefundTimelineEvent(
                    id: "started",
                    title: "Return started",
                    date: refund.returnDate,
                    state: .completed
                )
            )
        }

        result.append(
            RefundTimelineEvent(
                id: "expected",
                title: "Refund expected",
                date: refund.expectedRefundDate,
                state: expectedState
            )
        )

        if let actualDate = refund.actualRefundDate {
            result.append(
                RefundTimelineEvent(
                    id: "received",
                    title: "Refund received",
                    date: actualDate,
                    state: .completed
                )
            )
        }

        return result
    }

    private var effectiveStatus: RefundStatus {
        refund.effectiveStatus(on: .now, calendar: .current)
    }

    private var expectedState: RefundTimelineEvent.State {
        if refund.actualRefundDate != nil || effectiveStatus == .refunded {
            return .completed
        }

        switch effectiveStatus {
        case .overdue, .disputed:
            return .attention
        case .cancelled:
            return .inactive
        case .preparingReturn, .shipped, .deliveredToRetailer, .refundPending:
            return .upcoming
        case .refunded:
            return .completed
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        marker(for: event)
                            .frame(width: 9, height: 9)
                            .padding(.top, 5)

                        if index < events.count - 1 {
                            Rectangle()
                                .fill(RefundTheme.line)
                                .frame(width: RefundTheme.hairline)
                                .frame(maxHeight: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                    .frame(width: 9)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.system(.footnote).weight(.medium))
                            .foregroundStyle(
                                event.state == .attention
                                    ? RefundTheme.alert
                                    : RefundTheme.ink
                            )

                        Text(event.date, format: .dateTime.day().month(.wide).year())
                            .serif(14, relativeTo: .subheadline)
                            .foregroundStyle(RefundTheme.inkSoft)
                    }
                    .padding(.bottom, index < events.count - 1 ? 20 : 0)

                    Spacer(minLength: 0)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(event.title), \(event.date.formatted(date: .long, time: .omitted))"
                )
            }
        }
    }

    @ViewBuilder
    private func marker(for event: RefundTimelineEvent) -> some View {
        switch event.state {
        case .completed, .attention:
            Circle().fill(event.tint)
        case .upcoming, .inactive:
            Circle()
                .strokeBorder(event.tint, lineWidth: 1)
        }
    }
}

private struct RefundTimelineEvent: Identifiable {
    enum State {
        case completed
        case upcoming
        case attention
        case inactive
    }

    let id: String
    let title: String
    let date: Date
    let state: State

    var tint: Color {
        switch state {
        case .completed:
            RefundTheme.ink
        case .upcoming:
            RefundTheme.lineStrong
        case .attention:
            RefundTheme.alert
        case .inactive:
            RefundTheme.inkFaint
        }
    }
}
