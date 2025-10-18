import SwiftUI

struct EditShelfView: View {
    @StateObject private var supabase = SupabaseService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    let shelf: Shelf
    let onUpdate: (String) -> Void

    init(shelf: Shelf, onUpdate: @escaping (String) -> Void) {
        self.shelf = shelf
        self._name = State(initialValue: shelf.name)
        self.onUpdate = onUpdate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Shelf Name") {
                    TextField("Shelf name", text: $name)
                        .textContentType(.nickname)
                        .disabled(isSaving)
                }
            }
            .navigationTitle("Edit Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        updateShelf()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateShelf() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await supabase.updateShelf(id: shelf.id, name: trimmedName)
                await MainActor.run {
                    onUpdate(trimmedName)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }

            await MainActor.run {
                isSaving = false
            }
        }
    }
}
