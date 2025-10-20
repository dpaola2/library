import SwiftUI
import UIKit

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
    @State private var isUpdatingCover = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var coverImage: UIImage?
    @State private var showCoverActions = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: ImagePickerView.Source?

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
                VStack(spacing: 16) {
                    BookCoverFullView(coverURL: book.coverURL, image: $coverImage)

                    Button {
                        showCoverActions = true
                    } label: {
                        Label(book.coverURL == nil ? "Add Cover" : "Change Cover", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUpdatingCover || isDeleting)

                    if book.coverURL != nil {
                        Button("Remove Cover", role: .destructive) {
                            Task { await removeCover() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUpdatingCover || isDeleting)
                    }
                }

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
                    .disabled(isDeleting || isUpdatingCover)

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Book", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting || isUpdatingCover)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Book", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting || isUpdatingCover)
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
                coverImage = nil
                onUpdate(updatedBook)
                Task { await loadShelvesIfNeeded(force: true) }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            if let source = imagePickerSource {
                ImagePickerView(source: source) { image in
                    Task { await handlePickedImage(image) }
                } onCancel: {
                    showImagePicker = false
                }
            }
        }
        .confirmationDialog("Delete Book?", isPresented: $showDeleteConfirmation) {
            Button("Delete \"\(book.title)\"", role: .destructive) {
                deleteBook()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting this book cannot be undone.")
        }
        .confirmationDialog("Cover Options", isPresented: $showCoverActions) {
            Button("Choose from Library") {
                presentPicker(.photoLibrary)
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    presentPicker(.camera)
                }
            }

            if book.coverURL != nil {
                Button("Remove Cover", role: .destructive) {
                    Task { await removeCover() }
                }
            }

            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
        .overlay {
            if isDeleting || isUpdatingCover {
                ProgressView(isDeleting ? "Deleting…" : "Updating Cover…")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var currentShelfName: String {
        shelves.first(where: { $0.id == book.shelfId })?.name ?? "Unknown Shelf"
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
            await CoverImageService.shared.deleteCover(for: book)
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

    private func presentPicker(_ source: ImagePickerView.Source) {
        imagePickerSource = source
        showCoverActions = false
        showImagePicker = true
    }

    private func handlePickedImage(_ image: UIImage) async {
        showImagePicker = false
        isUpdatingCover = true
        defer { isUpdatingCover = false }

        do {
            guard let userId = supabase.getCurrentUserId() else {
                throw CoverImageError.missingUser
            }

            let uploadedURL = try await CoverImageService.shared.uploadCover(
                image: image,
                bookId: book.id,
                userId: userId
            )

            try await supabase.updateBookCover(id: book.id, coverURL: uploadedURL)

            await MainActor.run {
                coverImage = image
                book.coverURL = uploadedURL
                onUpdate(book)
                CoverImageService.shared.clearCache(for: uploadedURL)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func removeCover() async {
        guard book.coverURL != nil else { return }
        showCoverActions = false
        isUpdatingCover = true
        defer { isUpdatingCover = false }

        await CoverImageService.shared.deleteCover(for: book)

        do {
            try await supabase.updateBookCover(id: book.id, coverURL: nil)
            await MainActor.run {
                coverImage = nil
                book.coverURL = nil
                onUpdate(book)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
