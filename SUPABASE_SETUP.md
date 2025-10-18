Here's the best way to set up Supabase keys in your iOS app:

## Use a Config.swift file

Create a `Config.swift` file:

```swift
// Config.swift
import Foundation

enum Config {
    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-anon-key-here"
}
```

Then add to your `.gitignore`:

```
Config.swift
```

And create a `Config.example.swift` (commit this one):

```swift
// Config.example.swift
// Copy this file to Config.swift and add your actual keys
import Foundation

enum Config {
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY_HERE"
}
```

**Usage in your code:**

```swift
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey
)
```

**Steps:**

1. Create `Config.swift` with your real keys
2. Add `Config.swift` to `.gitignore`
3. Create `Config.example.swift` and commit it
4. Add a note in your README about copying the example file

**To get your Supabase keys:**

1. Go to your Supabase project dashboard
2. Click on "Settings" (gear icon)
3. Click "API"
4. Copy the "Project URL" and "anon public" key

Need help with the next step of setting up your SupabaseService class?

## SupabaseService class implementation example

Below is a complete `SupabaseService.swift` implementation. Here's what's included:

## Key Features:

**Authentication:**

- ✅ Sign up with email/password
- ✅ Sign in
- ✅ Sign out
- ✅ Session checking on init
- ✅ Published properties for reactive UI (`isAuthenticated`, `currentUser`)

**Shelves CRUD:**

- ✅ Fetch all shelves for current user
- ✅ Create shelf
- ✅ Update shelf
- ✅ Delete shelf

**Books CRUD:**

- ✅ Fetch books by shelf
- ✅ Create book
- ✅ Update book (including moving to different shelf)
- ✅ Delete book

**Models:**

- Full `Shelf` and `Book` models with proper `Codable` conformance
- Separate Insert/Update models for API calls
- Snake_case to camelCase mapping via `CodingKeys`

**Architecture:**

- Singleton pattern (`shared`) for easy access
- `@MainActor` for thread safety with SwiftUI
- `ObservableObject` for SwiftUI reactivity
- All async/await for modern Swift concurrency

## Usage Example:

```swift
// In your view
@StateObject private var supabase = SupabaseService.shared

// Sign in
Task {
    try await supabase.signIn(email: email, password: password)
}

// Fetch shelves
Task {
    let shelves = try await supabase.fetchShelves()
}

// Create a book
Task {
    let book = try await supabase.createBook(
        title: "1984",
        author: "George Orwell",
        shelfId: shelfId
    )
}
```

```swift
// SupabaseService.swift
import Foundation
import Supabase

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        
        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Authentication
    
    func checkSession() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        self.currentUser = response.user
        self.isAuthenticated = true
    }
    
    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        self.currentUser = response.user
        self.isAuthenticated = true
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    func getCurrentUserId() -> UUID? {
        return currentUser?.id
    }
    
    // MARK: - Shelves
    
    func fetchShelves() async throws -> [Shelf] {
        let response: [Shelf] = try await client
            .from("shelves")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func createShelf(name: String) async throws -> Shelf {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.notAuthenticated
        }
        
        let newShelf = ShelfInsert(
            name: name,
            userId: userId
        )
        
        let response: Shelf = try await client
            .from("shelves")
            .insert(newShelf)
            .select()
            .single()
            .execute()
            .value
        
        return response
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
        let response: [Book] = try await client
            .from("books")
            .select()
            .eq("shelf_id", value: shelfId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func createBook(title: String, author: String?, shelfId: UUID) async throws -> Book {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.notAuthenticated
        }
        
        let newBook = BookInsert(
            title: title,
            author: author,
            shelfId: shelfId,
            userId: userId
        )
        
        let response: Book = try await client
            .from("books")
            .insert(newBook)
            .select()
            .single()
            .execute()
            .value
        
        return response
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
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case shelfId = "shelf_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BookInsert: Encodable {
    let title: String
    let author: String?
    let shelfId: UUID
    let userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case title
        case author
        case shelfId = "shelf_id"
        case userId = "user_id"
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
```

