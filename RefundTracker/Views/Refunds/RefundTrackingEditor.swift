import SwiftUI

struct RefundTrackingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trackingNumber: String
    @State private var carrier: String
    let onSave: (String, String) -> Void

    init(
        trackingNumber: String,
        carrier: String,
        onSave: @escaping (String, String) -> Void
    ) {
        _trackingNumber = State(initialValue: trackingNumber)
        _carrier = State(initialValue: carrier)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        RefundFormField(label: "Tracking number") {
                            TextField("Tracking number", text: $trackingNumber)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(.callout).monospaced())
                                .accessibilityIdentifier("detailTrackingNumberField")
                        }

                        RefundFormField(label: "Return carrier") {
                            TextField("Return carrier", text: $carrier)
                                .textInputAutocapitalization(.words)
                                .font(.system(.body))
                                .accessibilityIdentifier("detailReturnCarrierField")
                        }

                        Text("You can update these details at any point in the return.")
                            .font(.system(.footnote))
                            .foregroundStyle(RefundTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Return tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trackingNumber, carrier)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("saveTrackingButton")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(6)
        .tint(RefundTheme.ink)
    }
}

struct RefundNotesEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String
    let onSave: (String) -> Void

    init(notes: String, onSave: @escaping (String) -> Void) {
        _notes = State(initialValue: notes)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                ScrollView {
                    RefundFormField(label: "Notes") {
                        TextField(
                            "Confirmation details, contact history, or anything else",
                            text: $notes,
                            axis: .vertical
                        )
                        .lineLimit(8...16)
                        .font(.system(.callout))
                        .accessibilityIdentifier("detailNotesField")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(notes)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("saveNotesButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(6)
        .tint(RefundTheme.ink)
    }
}
