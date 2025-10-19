import SwiftUI

struct BookPreviewView: View {
    let bookData: BookLookupResult
    let shelves: [Shelf]
    let defaultShelfId: UUID?
    let onConfirm: (String, String?, UUID) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var author: String
    @State private var selectedShelfId: UUID?

    init(
        bookData: BookLookupResult,
        shelves: [Shelf],
        defaultShelfId: UUID?,
        onConfirm: @escaping (String, String?, UUID) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.bookData = bookData
        self.shelves = shelves
        self.defaultShelfId = defaultShelfId
        self.onConfirm = onConfirm
        self.onCancel = onCancel

        _title = State(initialValue: bookData.title)
        _author = State(initialValue: bookData.author ?? "")
        if let defaultShelfId, shelves.contains(where: { $0.id == defaultShelfId }) {
            _selectedShelfId = State(initialValue: defaultShelfId)
        } else {
            _selectedShelfId = State(initialValue: shelves.first?.id)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Details") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let coverURL = bookData.coverURL {
                            AsyncImage(url: coverURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 200)
                                        .cornerRadius(12)
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, alignment: .center)
                                case .failure:
                                    placeholderCover
                                @unknown default:
                                    placeholderCover
                                }
                            }
                        } else {
                            placeholderCover
                        }

                        Text("ISBN: \(bookData.isbn)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Title", text: $title)
                        .textContentType(.none)
                        .autocapitalization(.words)

                    TextField("Author", text: $author)
                        .textContentType(.name)
                        .autocapitalization(.words)
                }

                if !shelves.isEmpty {
                    Section("Shelf") {
                        Picker("Select Shelf", selection: $selectedShelfId) {
                            ForEach(shelves) { shelf in
                                Text(shelf.name).tag(shelf.id as UUID?)
                            }
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "No Shelves Available",
                            systemImage: "books.vertical",
                            description: Text("Create a shelf before adding this book.")
                        )
                    }
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        confirm()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 180)
            .overlay {
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
    }

    private var isFormValid: Bool {
        guard let selectedShelfId else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && shelves.contains(where: { $0.id == selectedShelfId })
    }

    private func confirm() {
        guard let shelfId = selectedShelfId else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        onConfirm(trimmedTitle, trimmedAuthor.isEmpty ? nil : trimmedAuthor, shelfId)
    }
}
