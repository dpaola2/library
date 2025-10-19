import SwiftUI

struct ShelvesListView: View {
    @StateObject private var supabase = SupabaseService.shared

    @State private var shelves: [Shelf] = []
    @State private var isLoading = false
    @State private var showAddShelf = false
    @State private var shelfToEdit: Shelf?
    @State private var shelfToDelete: Shelf?
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(shelves) { shelf in
                    NavigationLink {
                        ShelfDetailView(
                            shelf: shelf,
                            onShelfUpdated: { updatedName in
                                if let index = shelves.firstIndex(where: { $0.id == shelf.id }) {
                                    shelves[index].name = updatedName
                                }
                            }
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "books.vertical")
                                .foregroundStyle(.tint)
                            Text(shelf.name)
                                .font(.headline)
                        }
                    }
                    .swipeActions {
                        Button("Edit") {
                            shelfToEdit = shelf
                        }
                        .tint(.blue)

                        Button("Delete", role: .destructive) {
                            shelfToDelete = shelf
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if isLoading && shelves.isEmpty {
                    ProgressView("Loading Shelves…")
                        .allowsHitTesting(false)
                } else if shelves.isEmpty {
                    ContentUnavailableView(
                        "No Shelves Yet",
                        systemImage: "books.vertical",
                        description: Text("Create your first shelf to start organizing your books.")
                    )
                    .allowsHitTesting(false)
                }
            }
            .refreshable {
                await loadShelves()
            }
            .navigationTitle("My Shelves")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddShelf = true
                    } label: {
                        Label("Add Shelf", systemImage: "plus")
                    }
                }
            }
            .task {
                await loadShelves()
            }
            .sheet(isPresented: $showAddShelf) {
                AddShelfView {
                    Task { await loadShelves() }
                }
            }
            .sheet(item: $shelfToEdit) { shelf in
                EditShelfView(shelf: shelf) { newName in
                    if let index = shelves.firstIndex(where: { $0.id == shelf.id }) {
                        shelves[index].name = newName
                    }
                    Task { await loadShelves() }
                }
            }
            .confirmationDialog(
                "Delete Shelf?",
                isPresented: $showDeleteConfirmation,
                presenting: shelfToDelete
            ) { shelf in
                Button("Delete \(shelf.name)", role: .destructive) {
                    Task { await deleteShelf(shelf) }
                }
            } message: { shelf in
                Text("Deleting \"\(shelf.name)\" will remove all books on it. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    @MainActor
    private func loadShelves() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            shelves = try await supabase.fetchShelves()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func signOut() {
        Task {
            do {
                try await supabase.signOut()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    @MainActor
    private func deleteShelf(_ shelf: Shelf) async {
        do {
            try await supabase.deleteShelf(id: shelf.id)
            shelves.removeAll { $0.id == shelf.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
