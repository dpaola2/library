import SwiftUI

struct AddBookView: View {
    @StateObject private var supabase = SupabaseService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var selectedShelfId: UUID?
    @State private var shelfOptions: [Shelf]
    @State private var isSaving = false
    @State private var isLoadingShelves = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let onSave: () -> Void

    init(
        shelves: [Shelf],
        preselectedShelfId: UUID?,
        onSave: @escaping () -> Void
    ) {
        self._shelfOptions = State(initialValue: shelves)
        self._selectedShelfId = State(initialValue: preselectedShelfId ?? shelves.first?.id)
        self.onSave = onSave
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
                            description: Text("Create a shelf before adding books.")
                        )
                    } else {
                        Picker("Select Shelf", selection: $selectedShelfId) {
                            ForEach(shelfOptions) { shelf in
                                Text(shelf.name)
                                    .tag(shelf.id as UUID?)
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
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBook()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .task {
                await loadShelvesIfNeeded()
                if selectedShelfId == nil {
                    selectedShelfId = shelfOptions.first?.id
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
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedShelfId != nil
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
    }

    private func saveBook() {
        guard let shelfId = selectedShelfId else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        errorMessage = nil

        Task {
            do {
                _ = try await supabase.createBook(
                    title: trimmedTitle,
                    author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
                    shelfId: shelfId
                )
                await MainActor.run {
                    onSave()
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
