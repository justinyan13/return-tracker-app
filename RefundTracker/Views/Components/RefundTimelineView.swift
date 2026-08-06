import SwiftUI

struct RefundTimelineView: View {
    let refund: Refund

    private var events: [RefundTimelineEvent] {
        var result = [
            RefundTimelineEvent(
                title: "Return created",
                date: refund.createdDate,
                symbolName: "plus.circle.fill",
                state: .completed
            )
        ]

        if let shippedDate = refund.shippedDate {
            result.append(
                RefundTimelineEvent(
                    title: "Return shipped",
                    date: shippedDate,
                    symbolName: "truck.box.fill",
                    state: .completed
                )
            )
        }

        if let receivedDate = refund.retailerReceivedDate {
            result.append(
                RefundTimelineEvent(
                    title: "Return delivered",
                    date: receivedDate,
                    symbolName: "shippingbox.and.arrow.backward.fill",
                    state: .completed
                )
            )
        }

        result.append(
            RefundTimelineEvent(
                title: "Refund expected",
                date: refund.expectedRefundDate,
                symbolName: "calendar",
                state: refund.isOverdue ? .attention : .upcoming
            )
        )

        if let actualDate = refund.actualRefundDate {
            result.append(
                RefundTimelineEvent(
                    title: "Refund received",
                    date: actualDate,
                    symbolName: "checkmark.circle.fill",
                    state: .completed
                )
            )
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Image(systemName: event.symbolName)
                            .font(.body)
                            .foregroundStyle(event.tint)
                            .frame(width: 28, height: 28)
                            .background(event.tint.opacity(0.12), in: Circle())

                        if index < events.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.22))
                                .frame(width: 2, height: 31)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(event.state == .attention ? .red : .secondary)
                    }
                    .padding(.top, 3)

                    Spacer()
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct RefundTimelineEvent: Identifiable {
    enum State {
        case completed
        case upcoming
        case attention
    }

    let id = UUID()
    let title: String
    let date: Date
    let symbolName: String
    let state: State

    var tint: Color {
        switch state {
        case .completed:
            .green
        case .upcoming:
            .blue
        case .attention:
            .red
        }
    }
}
