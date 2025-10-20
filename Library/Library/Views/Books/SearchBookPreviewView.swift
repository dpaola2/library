import SwiftUI
import UIKit

struct SearchBookPreviewView: View {
    let searchResult: BookSearchResult
    let defaultShelfId: UUID?
    let onBookAdded: () async -> Void
    let onCancel: () -> Void

    @StateObject private var supabase = SupabaseService.shared

    @State private var shelves: [Shelf] = []
    @State private var selectedShelfId: UUID?
    @State private var isLoadingShelves = false
    @State private var coverImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    coverView

                    VStack(alignment: .leading, spacing: 8) {
                        Text(searchResult.title)
                            .font(.headline)

                        if !searchResult.authors.isEmpty {
                            Text(searchResult.authors.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 6) {
                            if let publishYear = searchResult.publishYear {
                                Text(String(publishYear))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let publisher = searchResult.publisher, !publisher.isEmpty {
                                if searchResult.publishYear != nil {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(publisher)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let isbn = searchResult.isbn {
                            Text("ISBN: \(isbn)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }

                Section("Shelf") {
                    if isLoadingShelves && shelves.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if shelves.isEmpty {
                        ContentUnavailableView(
                            "No Shelves Available",
                            systemImage: "books.vertical",
                            description: Text("Create a shelf before adding books.")
                        )
                    } else {
                        Picker("Select a shelf", selection: $selectedShelfId) {
                            ForEach(shelves) { shelf in
                                Text(shelf.name).tag(shelf.id as UUID?)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveBook) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(selectedShelfId == nil || isSaving)
                }
            }
            .task {
                await loadShelvesIfNeeded()
                await loadCoverImage()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    private var coverView: some View {
        Group {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.1))
                    Image(systemName: "book.closed")
                        .font(.system(size: 72))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    private func loadShelvesIfNeeded() async {
        guard shelves.isEmpty else { return }
        isLoadingShelves = true
        defer { isLoadingShelves = false }

        do {
            shelves = try await supabase.fetchShelves()
            if let defaultShelfId,
               shelves.contains(where: { $0.id == defaultShelfId }) {
                selectedShelfId = defaultShelfId
            } else {
                selectedShelfId = shelves.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadCoverImage() async {
        guard coverImage == nil,
              let urlString = searchResult.coverImageURL,
              let url = URL(string: urlString) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else { return }
            guard let image = UIImage(data: data) else { return }

            await MainActor.run {
                coverImage = image
            }
        } catch {
            // best effort; ignore failures
        }
    }

    private func saveBook() {
        guard let shelfId = selectedShelfId else { return }

        isSaving = true

        Task {
            do {
                var uploadedCoverURL: URL?
                var bookId: UUID?

                if let coverImage,
                   let userId = supabase.getCurrentUserId() {
                    let generatedId = UUID()
                    do {
                        uploadedCoverURL = try await CoverImageService.shared.uploadCover(
                            image: coverImage,
                            bookId: generatedId,
                            userId: userId
                        )
                        bookId = generatedId
                    } catch {
                        // Unable to upload cover; continue without it
                        print("Cover upload failed: \(error)")
                        uploadedCoverURL = nil
                        bookId = nil
                    }
                }

                let author = searchResult.authors.isEmpty ? nil : searchResult.authors.joined(separator: ", ")

                _ = try await supabase.createBook(
                    id: bookId,
                    title: searchResult.title,
                    author: author,
                    shelfId: shelfId,
                    coverURL: uploadedCoverURL
                )

                await MainActor.run {
                    isSaving = false
                }

                await onBookAdded()
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    SearchBookPreviewView(
        searchResult: BookSearchResult(
            id: "1",
            title: "Sample Book",
            authors: ["Author"],
            isbn: "1234567890",
            coverImageURL: nil,
            publishYear: 2024,
            publisher: "Example Publisher"
        ),
        defaultShelfId: nil,
        onBookAdded: {},
        onCancel: {}
    )
}
