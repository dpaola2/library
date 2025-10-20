## Overview
A simple iOS app for organizing books into shelves, using Supabase as the backend and SwiftUI for the interface.

---

## Supabase Configuration
Create `Library/Library/Config.swift` from the provided `Config.example.swift` template and supply your Supabase project URL and anon key. Keep the real config file out of source control.

---

## Data Model

### Database Schema (PostgreSQL/Supabase)

```sql
-- Users table (managed by Supabase Auth)
-- auth.users is built-in, we'll reference it via user_id

-- Shelves
CREATE TABLE shelves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_shelves_user_id ON shelves(user_id);

-- Books
CREATE TABLE books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    author TEXT,
    shelf_id UUID NOT NULL REFERENCES shelves(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_books_shelf_id ON books(shelf_id);
CREATE INDEX idx_books_user_id ON books(user_id);

-- Row Level Security (RLS) Policies
ALTER TABLE shelves ENABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;

-- Shelves policies
CREATE POLICY "Users can view their own shelves"
    ON shelves FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own shelves"
    ON shelves FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own shelves"
    ON shelves FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own shelves"
    ON shelves FOR DELETE
    USING (auth.uid() = user_id);

-- Books policies
CREATE POLICY "Users can view their own books"
    ON books FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own books"
    ON books FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own books"
    ON books FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own books"
    ON books FOR DELETE
    USING (auth.uid() = user_id);
```

---

## App Architecture

### Tech Stack
- **iOS**: Swift 5, SwiftUI
- **Backend**: Supabase (PostgreSQL database + Auth + Realtime)
- **Storage**: No local persistence (Core Data), all data via Supabase
- **Authentication**: Supabase Auth (email/password)

### Key Dependencies
- `supabase-swift` - Official Supabase Swift client
- SwiftUI for all UI

### Project Structure
```
BookShelvesApp/
├── Models/
│   ├── Book.swift
│   ├── Shelf.swift
│   └── User.swift
├── Services/
│   └── SupabaseService.swift
├── Views/
│   ├── Auth/
│   │   ├── SignUpView.swift
│   │   └── LoginView.swift
│   ├── Shelves/
│   │   ├── ShelvesListView.swift
│   │   ├── AddShelfView.swift
│   │   └── EditShelfView.swift
│   └── Books/
│       ├── ShelfDetailView.swift
│       ├── BookDetailView.swift
│       ├── AddBookView.swift
│       └── EditBookView.swift
└── BookShelvesApp.swift
```

---

## Screen Specifications

### 1. Sign Up / Login View
**Purpose**: Authenticate users via Supabase Auth

**Components**:
- Email text field
- Password text field (secure)
- "Sign Up" button
- "Log In" button
- Toggle between sign up and login modes
- Error message display

**Behavior**:
- On successful auth, navigate to Shelves List
- Store session in Supabase client
- Handle auth errors (invalid email, weak password, etc.)

---

### 2. Shelves List View (Home Screen)
**Purpose**: Display all user's shelves

**Components**:
- Navigation bar with "My Shelves" title and logout button
- List of shelves (tappable rows)
- "Add a Shelf" button (bottom or toolbar)
- Empty state message if no shelves

**Behavior**:
- Fetch shelves from Supabase on appear
- Tap shelf → navigate to Shelf Detail View
- Tap "Add a Shelf" → present Add Shelf View (sheet/modal)
- Swipe to delete shelf (with confirmation)

---

### 3. Shelf Detail View
**Purpose**: Display books in a specific shelf

**Components**:
- Navigation bar with shelf name as title
- Edit button (navigates to Edit Shelf)
- List of books (tappable rows showing title and author)
- "Add a Book" button
- Empty state if no books in shelf

**Behavior**:
- Fetch books for this shelf from Supabase
- Tap book → navigate to Book Detail View
- Tap "Add a Book" → present Add Book View
- Swipe to delete book (with confirmation)

---

### 4. Book Detail View
**Purpose**: Display book information with actions

**Components**:
- Book title (large, bold)
- Author name
- Current shelf name (read-only display)
- "Move to Shelf" button (shows picker of other shelves)
- "Edit" button (navigates to Edit Book)
- "Delete" button (with confirmation)

**Behavior**:
- Display current book data
- "Move to Shelf" → present shelf picker, update book's shelf_id
- "Edit" → navigate to Edit Book View
- "Delete" → confirm and delete, navigate back

---

### 5. Add Book View
**Purpose**: Create a new book

**Components**:
- "Add Book" title
- Title text field (required)
- Author text field (optional)
- Shelf picker (required, defaults to current shelf if coming from Shelf Detail)
- "Save" button (enabled when title filled)
- "Cancel" button

**Behavior**:
- Validate title is not empty
- Insert book into Supabase with user_id
- On success, dismiss view and refresh parent list
- Show error if save fails

---

### 6. Edit Book View
**Purpose**: Update existing book

**Components**:
- "Edit Book" title
- Title text field (pre-filled)
- Author text field (pre-filled)
- Shelf picker (pre-selected)
- "Update" button
- "Cancel" button

**Behavior**:
- Pre-populate fields with current book data
- Update book in Supabase
- On success, dismiss and refresh
- Show error if update fails

---

### 7. Add Shelf View
**Purpose**: Create a new shelf

**Components**:
- "Add Shelf" title
- Name text field (required)
- "Save" button (enabled when name filled)
- "Cancel" button

**Behavior**:
- Validate name is not empty
- Insert shelf into Supabase with user_id
- On success, dismiss and refresh shelves list
- Show error if save fails

---

### 8. Edit Shelf View
**Purpose**: Update existing shelf

**Components**:
- "Edit Shelf" title
- Name text field (pre-filled)
- "Update" button
- "Cancel" button

**Behavior**:
- Pre-populate name field
- Update shelf in Supabase
- On success, dismiss and refresh
- Show error if update fails

---

## API Integration

### SupabaseService.swift
Core service class handling all Supabase operations:

**Authentication**:
- `signUp(email: String, password: String)`
- `signIn(email: String, password: String)`
- `signOut()`
- `getCurrentUser()`

**Shelves**:
- `fetchShelves() -> [Shelf]`
- `createShelf(name: String) -> Shelf`
- `updateShelf(id: UUID, name: String)`
- `deleteShelf(id: UUID)`

**Books**:
- `fetchBooks(shelfId: UUID) -> [Book]`
- `createBook(title: String, author: String?, shelfId: UUID) -> Book`
- `updateBook(id: UUID, title: String, author: String?, shelfId: UUID)`
- `deleteBook(id: UUID)`

---

## Data Models

### Shelf Model
```swift
struct Shelf: Identifiable, Codable {
    let id: UUID
    var name: String
    let userId: UUID
    let createdAt: Date
    let updatedAt: Date
}
```

### Book Model
```swift
struct Book: Identifiable, Codable {
    let id: UUID
    var title: String
    var author: String?
    var shelfId: UUID
    let userId: UUID
    let createdAt: Date
    let updatedAt: Date
}
```

---

## Implementation Phases

### Phase 1: Setup & Auth
1. Create Xcode project with SwiftUI
2. Add Supabase Swift SDK via SPM
3. Set up Supabase project and configure API keys
4. Create database schema in Supabase SQL editor
5. Implement SupabaseService authentication methods
6. Build Sign Up / Login views

### Phase 2: Shelves
1. Implement Shelves List View
2. Add Create Shelf functionality
3. Add Edit Shelf functionality
4. Add Delete Shelf functionality

### Phase 3: Books
1. Implement Shelf Detail View (books list)
2. Add Create Book functionality
3. Implement Book Detail View
4. Add Edit Book functionality
5. Add "Move to Shelf" functionality
6. Add Delete Book functionality

### Phase 4: Polish
1. Error handling and loading states
2. Empty states for lists
3. Confirmation dialogs for destructive actions
4. Pull to refresh on lists
5. Basic styling and UX improvements

---

## Security Considerations

- All database operations secured via RLS policies
- Users can only access their own data
- Supabase API keys stored securely (not in code)
- Use environment variables or Info.plist for configuration
- Validate all user input before sending to Supabase

---

## Future Enhancements
- Search/filter books
- Book covers (Active Storage)
- Notes on books
- ISBN lookup integration
- Sorting options (by title, author, date added)
- Share shelves with other users
- Dark mode support
- iPad/Mac optimization
