import SwiftUI

struct BookDetailView: View {
    @StateObject private var supabase = SupabaseService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var book: Book
    @State private var shelves: [Shelf]
    @State private var isLoadingShelves = false
    @State private var showMoveSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showError = false

    let onUpdate: (Book) -> Void
    let onDelete: (Book) -> Void

    init(
        book: Book,
        shelves: [Shelf],
        onUpdate: @escaping (Book) -> Void,
        onDelete: @escaping (Book) -> Void
    ) {
        self._book = State(initialValue: book)
        self._shelves = State(initialValue: shelves)
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(book.title)
                        .font(.title2.bold())

                    if let author = book.author, !author.isEmpty {
                        Label(author, systemImage: "person.fill")
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Label(currentShelfName, systemImage: "books.vertical")
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                VStack(spacing: 12) {
                    Button {
                        showMoveSheet = true
                    } label: {
                        Label("Move to Shelf", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDeleting)

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Book", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Book", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting)
                }
            }
            .padding()
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadShelvesIfNeeded(force: shelves.isEmpty)
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveToShelfView(book: book, shelves: shelves) { newShelfId in
                book.shelfId = newShelfId
                onUpdate(book)
                Task { await loadShelvesIfNeeded(force: true) }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditBookView(book: book, shelves: shelves) { updatedBook in
                book = updatedBook
                onUpdate(updatedBook)
                Task { await loadShelvesIfNeeded(force: true) }
            }
        }
        .confirmationDialog(
            "Delete Book?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete \"\(book.title)\"", role: .destructive) {
                deleteBook()
            }
        } message: {
            Text("Deleting this book cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
        .overlay {
            if isDeleting {
                ProgressView("Deleting…")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var currentShelfName: String {
        if let shelf = shelves.first(where: { $0.id == book.shelfId }) {
            return shelf.name
        }
        return "Unknown Shelf"
    }

    @MainActor
    private func loadShelvesIfNeeded(force: Bool = false) async {
        guard force || shelves.isEmpty else { return }
        isLoadingShelves = true
        defer { isLoadingShelves = false }

        do {
            shelves = try await supabase.fetchShelves()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteBook() {
        guard !isDeleting else { return }
        isDeleting = true

        Task {
            do {
                try await supabase.deleteBook(id: book.id)
                await MainActor.run {
                    onDelete(book)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }

            await MainActor.run {
                isDeleting = false
            }
        }
    }
}
