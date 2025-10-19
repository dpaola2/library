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
    @State private var showScanner = false
    @State private var showBookPreview = false
    @State private var scannedBookData: BookLookupResult?
    @State private var isLookingUpISBN = false

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
                        showScanner = true
                    } label: {
                        Label("Scan ISBN", systemImage: "barcode.viewfinder")
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
        .sheet(isPresented: $showScanner) {
            ISBNScannerView { isbn in
                Task {
                    await handleScannedISBN(isbn)
                }
            }
        }
        .sheet(isPresented: $showBookPreview) {
            if let bookData = scannedBookData {
                BookPreviewView(
                    bookData: bookData,
                    shelves: shelves,
                    defaultShelfId: shelf.id,
                    onConfirm: { title, author, shelfId in
                        Task {
                            await saveScannedBook(title: title, author: author, shelfId: shelfId)
                        }
                    },
                    onCancel: {
                        showBookPreview = false
                        scannedBookData = nil
                    }
                )
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
            ZStack {
                if isLoading && books.isEmpty {
                    ProgressView("Loading Books…")
                        .allowsHitTesting(false)
                }

                if isLookingUpISBN {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    ProgressView("Looking up ISBN…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func handleScannedISBN(_ isbn: String) async {
        await MainActor.run {
            isLookingUpISBN = true
        }

        do {
            let bookData = try await ISBNService.shared.lookupBook(isbn: isbn)
            guard !shelves.isEmpty else {
                await MainActor.run {
                    isLookingUpISBN = false
                    errorMessage = "Please create a shelf before adding scanned books."
                    showError = true
                }
                return
            }

            await MainActor.run {
                scannedBookData = bookData
                showBookPreview = true
                isLookingUpISBN = false
            }
        } catch {
            await MainActor.run {
                isLookingUpISBN = false
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                showError = true
            }
        }
    }

    private func saveScannedBook(title: String, author: String?, shelfId: UUID) async {
        do {
            _ = try await supabase.createBook(title: title, author: author, shelfId: shelfId)
            await MainActor.run {
                showBookPreview = false
                scannedBookData = nil
            }
            await loadBooks()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
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
