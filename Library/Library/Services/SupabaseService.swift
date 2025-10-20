import Combine
import Foundation
import Supabase

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient

    @Published var currentUser: User?
    @Published var isAuthenticated = false

    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )

        Task {
            await checkSession()
        }
    }

    // MARK: - Authentication

    func checkSession() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        currentUser = response.user
        isAuthenticated = true
    }

    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        currentUser = response.user
        isAuthenticated = true
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    func getCurrentUserId() -> UUID? {
        currentUser?.id
    }

    // MARK: - Shelves

    func fetchShelves() async throws -> [Shelf] {
        try await client
            .from("shelves")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createShelf(name: String) async throws -> Shelf {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.notAuthenticated
        }

        let newShelf = ShelfInsert(
            name: name,
            userId: userId
        )

        return try await client
            .from("shelves")
            .insert(newShelf)
            .select()
            .single()
            .execute()
            .value
    }

    func updateShelf(id: UUID, name: String) async throws {
        let update = ShelfUpdate(name: name)

        try await client
            .from("shelves")
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteShelf(id: UUID) async throws {
        try await client
            .from("shelves")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Books

    func fetchBooks(shelfId: UUID) async throws -> [Book] {
        try await client
            .from("books")
            .select()
            .eq("shelf_id", value: shelfId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createBook(
        id: UUID? = nil,
        title: String,
        author: String?,
        shelfId: UUID,
        coverURL: URL? = nil
    ) async throws -> Book {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.notAuthenticated
        }

        let newBook = BookInsert(
            id: id,
            title: title,
            author: author,
            shelfId: shelfId,
            userId: userId,
            coverUrl: coverURL?.absoluteString
        )

        return try await client
            .from("books")
            .insert(newBook)
            .select()
            .single()
            .execute()
            .value
    }

    func updateBook(id: UUID, title: String, author: String?, shelfId: UUID) async throws {
        let update = BookUpdate(
            title: title,
            author: author,
            shelfId: shelfId
        )

        try await client
            .from("books")
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func updateBookCover(id: UUID, coverURL: URL?) async throws {
        let update = BookCoverUpdate(coverUrl: coverURL?.absoluteString)

        try await client
            .from("books")
            .update(update)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteBook(id: UUID) async throws {
        try await client
            .from("books")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - Models

struct Shelf: Identifiable, Codable {
    let id: UUID
    var name: String
    let userId: UUID
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ShelfInsert: Encodable {
    let name: String
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case name
        case userId = "user_id"
    }
}

struct ShelfUpdate: Encodable {
    let name: String
}

struct Book: Identifiable, Codable {
    let id: UUID
    var title: String
    var author: String?
    var shelfId: UUID
    let userId: UUID
    var coverURL: URL?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case shelfId = "shelf_id"
        case userId = "user_id"
        case coverURL = "cover_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BookInsert: Encodable {
    let id: UUID?
    let title: String
    let author: String?
    let shelfId: UUID
    let userId: UUID
    let coverUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case shelfId = "shelf_id"
        case userId = "user_id"
        case coverUrl = "cover_url"
    }
}

struct BookUpdate: Encodable {
    let title: String
    let author: String?
    let shelfId: UUID

    enum CodingKeys: String, CodingKey {
        case title
        case author
        case shelfId = "shelf_id"
    }
}

private struct BookCoverUpdate: Encodable {
    let coverUrl: String?

    enum CodingKeys: String, CodingKey {
        case coverUrl = "cover_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let coverUrl {
            try container.encode(coverUrl, forKey: .coverUrl)
        } else {
            try container.encodeNil(forKey: .coverUrl)
        }
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        }
    }
}
