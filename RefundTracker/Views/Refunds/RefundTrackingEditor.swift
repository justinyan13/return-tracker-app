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
            Form {
                Section {
                    TextField("Tracking number", text: $trackingNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("detailTrackingNumberField")
                    TextField("Return carrier", text: $carrier)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("detailReturnCarrierField")
                } footer: {
                    Text("You can update these details at any point in the return.")
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
            Form {
                TextField(
                    "Confirmation details, contact history, or anything else",
                    text: $notes,
                    axis: .vertical
                )
                .lineLimit(8...16)
                .accessibilityIdentifier("detailNotesField")
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
    }
}
