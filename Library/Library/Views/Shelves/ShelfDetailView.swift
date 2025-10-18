import SwiftUI

struct ShelfDetailView: View {
    @StateObject private var supabase = SupabaseService.shared

    @State private var shelf: Shelf
    @State private var books: [Book] = []
    @State private var shelves: [Shelf] = []
    @State private var isLoading = false
    @State private var showAddBook = false
    @State private var showEditShelf = false
    @State private var bookToDelete: Book?
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var showError = false

    let onShelfUpdated: ((String) -> Void)?

    init(
        shelf: Shelf,
        onShelfUpdated: ((String) -> Void)? = nil
    ) {
        self._shelf = State(initialValue: shelf)
        self.onShelfUpdated = onShelfUpdated
    }

    var body: some View {
        List {
            if books.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Books Yet",
                    systemImage: "book.closed",
                    description: Text("Add your first book to this shelf.")
                )
                .listRowSeparator(.hidden)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(books) { book in
                    NavigationLink {
                        BookDetailView(
                            book: book,
                            shelves: shelves,
                            onUpdate: { updatedBook in
                                if let index = books.firstIndex(where: { $0.id == updatedBook.id }) {
                                    books[index] = updatedBook
                                } else {
                                    books.append(updatedBook)
                                }
                                Task { await reloadShelvesIfNeeded() }
                            },
                            onDelete: { deletedBook in
                                books.removeAll { $0.id == deletedBook.id }
                            }
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                            if let author = book.author, !author.isEmpty {
                                Text(author)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            bookToDelete = book
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .navigationTitle(shelf.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddBook = true
                    } label: {
                        Label("Add Book", systemImage: "plus")
                    }

                    Button {
                        showEditShelf = true
                    } label: {
                        Label("Edit Shelf", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showAddBook) {
            AddBookView(
                shelves: shelves,
                preselectedShelfId: shelf.id
            ) {
                Task { await loadData() }
            }
        }
        .sheet(isPresented: $showEditShelf) {
            EditShelfView(shelf: shelf) { newName in
                shelf.name = newName
                onShelfUpdated?(newName)
                Task { await loadData() }
            }
        }
        .confirmationDialog(
            "Delete Book?",
            isPresented: $showDeleteConfirmation,
            presenting: bookToDelete
        ) { book in
            Button("Delete \"\(book.title)\"", role: .destructive) {
                Task { await deleteBook(book) }
            }
        } message: { book in
            Text("Removing this book cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
        .overlay {
            if isLoading && books.isEmpty {
                ProgressView("Loading Books…")
            }
        }
    }

    @MainActor
    private func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        await loadBooks()
        await reloadShelvesIfNeeded(force: true)
    }

    @MainActor
    private func loadBooks() async {
        do {
            books = try await supabase.fetchBooks(shelfId: shelf.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    @MainActor
    private func reloadShelvesIfNeeded(force: Bool = false) async {
        guard force || shelves.isEmpty else { return }
        do {
            shelves = try await supabase.fetchShelves()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    @MainActor
    private func deleteBook(_ book: Book) async {
        do {
            try await supabase.deleteBook(id: book.id)
            books.removeAll { $0.id == book.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
