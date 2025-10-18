import SwiftUI

struct MoveToShelfView: View {
    @StateObject private var supabase = SupabaseService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedShelfId: UUID
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showError = false

    let book: Book
    let shelves: [Shelf]
    let onMove: (UUID) -> Void

    init(
        book: Book,
        shelves: [Shelf],
        onMove: @escaping (UUID) -> Void
    ) {
        self.book = book
        self.shelves = shelves
        self.onMove = onMove
        self._selectedShelfId = State(initialValue: book.shelfId)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(shelves) { shelf in
                    Button {
                        selectedShelfId = shelf.id
                    } label: {
                        HStack {
                            Text(shelf.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if shelf.id == selectedShelfId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .disabled(isUpdating)
                }
            }
            .navigationTitle("Move to Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUpdating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        moveBook()
                    }
                    .disabled(selectedShelfId == book.shelfId || isUpdating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    private func moveBook() {
        guard selectedShelfId != book.shelfId else { return }
        isUpdating = true
        errorMessage = nil

        Task {
            do {
                try await supabase.updateBook(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    shelfId: selectedShelfId
                )
                await MainActor.run {
                    onMove(selectedShelfId)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }

            await MainActor.run {
                isUpdating = false
            }
        }
    }
}
