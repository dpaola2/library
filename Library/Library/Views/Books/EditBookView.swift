import SwiftUI

struct EditBookView: View {
    @StateObject private var supabase = SupabaseService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var author: String
    @State private var selectedShelfId: UUID
    @State private var shelfOptions: [Shelf]
    @State private var isSaving = false
    @State private var isLoadingShelves = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let onUpdate: (Book) -> Void
    private let originalBook: Book

    init(
        book: Book,
        shelves: [Shelf],
        onUpdate: @escaping (Book) -> Void
    ) {
        self.originalBook = book
        self._title = State(initialValue: book.title)
        self._author = State(initialValue: book.author ?? "")
        self._selectedShelfId = State(initialValue: book.shelfId)
        self._shelfOptions = State(initialValue: shelves)
        self.onUpdate = onUpdate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Details") {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                        .autocapitalization(.words)
                        .disabled(isSaving)

                    TextField("Author (optional)", text: $author)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .disabled(isSaving)
                }

                Section("Shelf") {
                    if isLoadingShelves && shelfOptions.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if shelfOptions.isEmpty {
                        ContentUnavailableView(
                            "No Shelves Available",
                            systemImage: "books.vertical",
                            description: Text("Create a shelf before editing books.")
                        )
                    } else {
                        Picker("Select Shelf", selection: $selectedShelfId) {
                            ForEach(shelfOptions) { shelf in
                                Text(shelf.name)
                                    .tag(shelf.id)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .navigationTitle("Edit Book")
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
                        updateBook()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .task {
                await loadShelvesIfNeeded()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func loadShelvesIfNeeded() async {
        guard shelfOptions.isEmpty else { return }
        isLoadingShelves = true
        defer { isLoadingShelves = false }

        do {
            shelfOptions = try await supabase.fetchShelves()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        if !shelfOptions.contains(where: { $0.id == selectedShelfId }) {
            selectedShelfId = shelfOptions.first?.id ?? selectedShelfId
        }
    }

    private func updateBook() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await supabase.updateBook(
                    id: originalBook.id,
                    title: trimmedTitle,
                    author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
                    shelfId: selectedShelfId
                )
                var updatedBook = originalBook
                updatedBook.title = trimmedTitle
                updatedBook.author = trimmedAuthor.isEmpty ? nil : trimmedAuthor
                updatedBook.shelfId = selectedShelfId

                await MainActor.run {
                    onUpdate(updatedBook)
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
