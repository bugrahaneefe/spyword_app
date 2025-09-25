import SwiftUI

struct NameEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    var onSave: (String) -> Void

    init(currentName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: currentName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your name")) {
                    TextField("Type your name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Edit name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { dismiss(); return }
                        onSave(String(trimmed.prefix(18)))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
