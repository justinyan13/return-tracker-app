import SwiftUI

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
                    symbolName: "truck.box.fill",
                    state: .completed
                )
            )
        } else {
            result.append(
                RefundTimelineEvent(
                    id: "started",
                    title: "Return started",
                    date: refund.returnDate,
                    symbolName: "arrow.uturn.backward.circle.fill",
                    state: .completed
                )
            )
        }

        result.append(
            RefundTimelineEvent(
                id: "expected",
                title: "Refund expected",
                date: refund.expectedRefundDate,
                symbolName: expectedSymbolName,
                state: expectedState
            )
        )

        if let actualDate = refund.actualRefundDate {
            result.append(
                RefundTimelineEvent(
                    id: "received",
                    title: "Refund received",
                    date: actualDate,
                    symbolName: "checkmark.circle.fill",
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

    private var expectedSymbolName: String {
        switch expectedState {
        case .completed:
            "calendar.badge.checkmark"
        case .upcoming:
            "calendar.badge.clock"
        case .attention:
            "exclamationmark.calendar.fill"
        case .inactive:
            "calendar"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Image(systemName: event.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(event.tint)
                            .frame(width: 30, height: 30)
                            .background(event.tint.opacity(0.12), in: Circle())

                        if index < events.count - 1 {
                            Rectangle()
                                .fill(.tertiary)
                                .frame(width: 2, height: 22)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))

                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(
                                event.state == .attention
                                    ? RefundTheme.coral
                                    : .secondary
                            )
                    }
                    .padding(.top, 2)

                    Spacer()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(event.title), \(event.date.formatted(date: .long, time: .omitted))"
                )
            }
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
    let symbolName: String
    let state: State

    var tint: Color {
        switch state {
        case .completed:
            RefundTheme.mint
        case .upcoming:
            RefundTheme.blue
        case .attention:
            RefundTheme.coral
        case .inactive:
            .secondary
        }
    }
}
