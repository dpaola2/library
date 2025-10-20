import SwiftUI

struct BookSearchView: View {
    let defaultShelfId: UUID?
    let onBookAdded: () async -> Void

    @State private var titleQuery = ""
    @State private var authorQuery = ""
    @State private var searchResults: [BookSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedResult: BookSearchResult?
    @State private var showBookPreview = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Search for a book") {
                        TextField("Book Title", text: $titleQuery)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .onSubmit { performSearch() }

                        TextField("Author (optional)", text: $authorQuery)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .onSubmit { performSearch() }
                    }

                    Section {
                        Button(action: performSearch) {
                            HStack {
                                Spacer()
                                if isSearching {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text(isSearching ? "Searching…" : "Search")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(isSearching || titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .frame(maxHeight: 260)

                Divider()

                Group {
                    if isSearching {
                        ProgressView("Searching…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if hasSearched && searchResults.isEmpty {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "book.closed",
                            description: Text("Try a different search term.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !searchResults.isEmpty {
                        List {
                            Section("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")") {
                                ForEach(searchResults) { result in
                                    Button {
                                        selectedResult = result
                                        showBookPreview = true
                                    } label: {
                                        BookSearchResultRow(result: result)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    } else {
                        ContentUnavailableView(
                            "Search for Books",
                            systemImage: "magnifyingglass",
                            description: Text("Enter a book title to get started.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Search Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showBookPreview) {
                if let selectedResult {
                    SearchBookPreviewView(
                        searchResult: selectedResult,
                        defaultShelfId: defaultShelfId,
                        onBookAdded: {
                            await MainActor.run {
                                showBookPreview = false
                                selectedResult = nil
                                dismiss()
                            }
                            await onBookAdded()
                        },
                        onCancel: {
                            showBookPreview = false
                            selectedResult = nil
                        }
                    )
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    private func performSearch() {
        let trimmedTitle = titleQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = authorQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !isSearching else { return }

        isSearching = true
        hasSearched = true
        searchResults = []

        Task {
            do {
                let results = try await ISBNService.shared.searchBooks(
                    title: trimmedTitle,
                    author: trimmedAuthor.isEmpty ? nil : trimmedAuthor
                )

                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    showError = true
                    isSearching = false
                }
            }
        }
    }
}

struct BookSearchResultRow: View {
    let result: BookSearchResult

    var body: some View {
        HStack(spacing: 12) {
            coverThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !result.authors.isEmpty {
                    Text(result.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let publishYear = result.publishYear {
                        Text(String(publishYear))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let publisher = result.publisher, !publisher.isEmpty {
                        if result.publishYear != nil {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(publisher)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let urlString = result.coverImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(width: 50, height: 75)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            placeholder
                .frame(width: 50, height: 75)
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.1))
            Image(systemName: "book.closed")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(width: 50, height: 75)
    }
}

#Preview {
    BookSearchView(defaultShelfId: nil, onBookAdded: {})
}
