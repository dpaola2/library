
## Overview

Add book cover images to enhance the visual appeal of the library. Users can get covers from ISBN lookup, upload from photo library, or take a photo with the camera.

---

## Product Requirements

### Features

1. **Automatic cover from ISBN scan** - Download and store cover when scanning ISBN
2. **Manual photo upload** - Select image from photo library
3. **Camera capture** - Take a photo of the book cover
4. **Display covers** - Show thumbnails in book lists and full size in detail view
5. **Optional** - Books without covers still work fine

### User Flows

**Flow 1: ISBN Scan (Automatic)**

1. User scans ISBN barcode
2. App fetches book data including cover URL
3. App downloads cover image
4. App uploads to Supabase Storage
5. Cover URL stored in book record
6. Cover displays in app

**Flow 2: Manual Upload**

1. User taps "Add/Change Cover" on book detail
2. Sheet presents: Photo Library, Camera, or Remove
3. User selects/captures image
4. App uploads to Supabase Storage
5. Cover URL stored in book record
6. Cover displays in app

**Flow 3: Camera Capture**

1. User taps "Take Photo"
2. Camera opens
3. User takes photo of book cover
4. App uploads to Supabase Storage
5. Cover URL stored in book record
6. Cover displays in app

---

## Technical Architecture

### Storage Strategy: Supabase Storage (Recommended)

**Why Supabase Storage over PostgreSQL BYTEA:**

- ✅ Designed for files (images, PDFs, etc.)
- ✅ Built-in CDN for fast delivery
- ✅ Automatic image optimization
- ✅ Large file support (up to 5GB per file)
- ✅ Lower cost for image storage
- ✅ Easier to cache and serve
- ❌ PostgreSQL BYTEA max 1GB, slower, more expensive

**Supabase Storage Structure:**

```
book-covers/
  └── {user_id}/
      └── {book_id}.jpg
```

### Database Schema Update

```sql
-- Add cover_url column to books table
ALTER TABLE books 
ADD COLUMN cover_url TEXT;

-- Optional: Add cover metadata
ALTER TABLE books 
ADD COLUMN cover_uploaded_at TIMESTAMP WITH TIME ZONE;
```

### Supabase Storage Setup

```sql
-- Create storage bucket for book covers
INSERT INTO storage.buckets (id, name, public)
VALUES ('book-covers', 'book-covers', true);

-- Set up RLS policies for book-covers bucket
CREATE POLICY "Users can upload their own book covers"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'book-covers' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own book covers"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'book-covers' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own book covers"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'book-covers' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Book covers are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'book-covers');

-- 4. Verify the setup
SELECT * FROM storage.buckets WHERE id = 'book-covers';
```

---

## Cost Analysis

### Supabase Storage Pricing (Free Tier)

- **Storage**: 1GB free
- **Bandwidth**: 2GB/month free
- **Requests**: Unlimited

### Estimated Usage (Personal Library)

- **Average cover size**: ~100KB (after compression)
- **1,000 books**: 100MB storage
- **Monthly bandwidth**: Minimal (covers cached)

**Conclusion: Completely free for personal use under 1,000 books**

### Paid Tier (if needed)

- Pro Plan: $25/month
    - 100GB storage
    - 200GB bandwidth
    - Supports ~1 million books worth of covers

---

## Performance Optimizations

### 1. Image Caching Strategy

```swift
// Already implemented in CoverImageService
private let imageCache = NSCache<NSString, UIImage>()

// Cache configuration
imageCache.countLimit = 100  // Max 100 images in memory
// Automatic eviction when memory pressure occurs
```

### 2. Lazy Loading

- Only load covers when scrolling into view
- Use thumbnail size (50x75) in lists
- Full size (600x900) only in detail view

### 3. Image Compression

```swift
// Already implemented in uploadCoverImage
let resizedImage = image.resized(to: CGSize(width: 600, height: 900))
let imageData = resizedImage.jpegData(compressionQuality: 0.8)
```

**Benefits:**

- Reduces storage costs
- Faster uploads/downloads
- Better UX on slower connections

---

## Testing Checklist

### Functionality

- [ ] Upload image from photo library
- [ ] Capture image with camera
- [ ] Download cover from ISBN scan
- [ ] Display thumbnail in book list
- [ ] Display full size in detail view
- [ ] Update/replace existing cover
- [ ] Remove cover
- [ ] Delete book with cover (cover also deleted)

### Edge Cases

- [ ] Books without covers display placeholder
- [ ] Handle network errors gracefully
- [ ] Handle large images (>10MB)
- [ ] Handle corrupted images
- [ ] Handle offline mode
- [ ] Test with 100+ books (caching)

### Performance

- [ ] Scroll performance with many books
- [ ] Upload time < 3 seconds
- [ ] Download time < 2 seconds
- [ ] Memory usage reasonable

### Security

- [ ] Users can only upload to their own folder
- [ ] Users can only delete their own covers
- [ ] Covers are publicly readable (for sharing)
- [ ] Invalid images rejected

---

## User Experience Flows

### Flow 1: Scan ISBN with Cover

```
1. User taps "Scan ISBN"
2. Scans barcode
3. App shows preview with cover image
4. "Uploading cover..." appears briefly
5. Cover thumbnail shows in preview
6. User selects shelf and taps "Add"
7. Book appears in list with cover
```

### Flow 2: Manual Cover Upload

```
1. User opens book detail (no cover)
2. Taps "Add Cover" button
3. Chooses "Photo Library" or "Take Photo"
4. Selects/captures image
5. Cover uploads in background
6. Cover appears in detail view
7. Returns to list, thumbnail now visible
```

### Flow 3: Replace Existing Cover

```
1. User opens book with cover
2. Taps "Change Cover"
3. Selects new image
4. Old cover deleted, new one uploaded
5. New cover displays immediately
```

---

## Future Enhancements

### Phase 2 Features

- **Bulk cover import**: Match covers to multiple books at once
- **Cover search**: Google Images integration
- **Cover editing**: Crop/rotate before upload
- **Multiple images**: Front/back covers, dust jacket
- **AI cover generation**: Generate covers for books without images

### Phase 3 Features

- **Social sharing**: Share book covers with friends
- **Cover recommendations**: Suggest better quality covers
- **Historical covers**: Multiple cover editions
- **Cover statistics**: Track most common covers

---

## Migration Path for Existing Users

If users already have books without covers:

```swift
// Optional: Backfill covers for existing books
func backfillCoversFromISBN() async {
    let booksWithoutCovers = books.filter { $0.coverUrl == nil }
    
    for book in booksWithoutCovers {
        // Try to find ISBN in book metadata
        // Look up cover from Open Library
        // Upload and update book record
    }
}
```

---

## Summary

### What This Adds

✅ **Automatic covers** from ISBN scan  
✅ **Manual upload** from photo library  
✅ **Camera capture** for physical books  
✅ **Thumbnail display** in book lists  
✅ **Full-size display** in detail view  
✅ **Cover management** (add/change/remove)  
✅ **Efficient storage** via Supabase Storage  
✅ **Caching** for performance  
✅ **Free** for personal use

### Files to Create/Update

1. `CoverImageService.swift` - New file
2. `ImagePickerView.swift` - New file
3. `SupabaseService.swift` - Update models and methods
4. `BookDetailView.swift` - Update to show and manage covers
5. `ShelfDetailView.swift` - Update to show thumbnails
6. `BookPreviewView.swift` - Update to handle covers from ISBN
7. `Info.plist` - Add photo/camera permissions
8. Supabase SQL Editor - Run migration script

### Implementation Time Estimate

- Database setup: 10 minutes
- CoverImageService: 1 hour
- UI updates: 2-3 hours
- Testing: 1 hour
- **Total: 4-5 hours**foldername(name))[1] );

CREATE POLICY "Users can delete their own book covers" ON storage.objects FOR DELETE USING ( bucket_id = 'book-covers' AND auth.uid()::text = (storage.foldername(name))[1] );

CREATE POLICY "Book covers are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'book-covers');

````

---

## Implementation

### 1. Update Book Model

```swift
// Update Book model in SupabaseService.swift
struct Book: Identifiable, Codable {
    let id: UUID
    var title: String
    var author: String?
    var shelfId: UUID
    let userId: UUID
    let createdAt: Date
    let updatedAt: Date
    var coverUrl: String?  // NEW
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case shelfId = "shelf_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case coverUrl = "cover_url"  // NEW
    }
}

struct BookInsert: Encodable {
    let title: String
    let author: String?
    let shelfId: UUID
    let userId: UUID
    let coverUrl: String?  // NEW
    
    enum CodingKeys: String, CodingKey {
        case title
        case author
        case shelfId = "shelf_id"
        case userId = "user_id"
        case coverUrl = "cover_url"  // NEW
    }
}

struct BookUpdate: Encodable {
    let title: String
    let author: String?
    let shelfId: UUID
    let coverUrl: String?  // NEW
    
    enum CodingKeys: String, CodingKey {
        case title
        case author
        case shelfId = "shelf_id"
        case coverUrl = "cover_url"  // NEW
    }
}
````

### 2. Cover Image Service

```swift
// CoverImageService.swift
import Foundation
import UIKit
import Supabase

class CoverImageService {
    static let shared = CoverImageService()
    private let supabase = SupabaseService.shared.client
    private let imageCache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache
        imageCache.countLimit = 100 // Cache up to 100 images
    }
    
    // MARK: - Upload Cover Image
    
    func uploadCoverImage(_ image: UIImage, for bookId: UUID) async throws -> String {
        guard let userId = SupabaseService.shared.getCurrentUserId() else {
            throw CoverImageError.notAuthenticated
        }
        
        // Resize and compress image
        guard let resizedImage = image.resized(to: CGSize(width: 600, height: 900)),
              let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw CoverImageError.invalidImage
        }
        
        // Create file path: user_id/book_id.jpg
        let fileName = "\(userId)/\(bookId).jpg"
        
        // Upload to Supabase Storage
        _ = try await supabase.storage
            .from("book-covers")
            .upload(
                path: fileName,
                file: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true  // Replace if exists
                )
            )
        
        // Get public URL
        let publicURL = try supabase.storage
            .from("book-covers")
            .getPublicURL(path: fileName)
        
        return publicURL.absoluteString
    }
    
    // MARK: - Download Cover Image
    
    func downloadCoverImage(from urlString: String) async throws -> UIImage {
        // Check cache first
        let cacheKey = urlString as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else {
            throw CoverImageError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw CoverImageError.invalidImage
        }
        
        // Cache the image
        imageCache.setObject(image, forKey: cacheKey)
        
        return image
    }
    
    // MARK: - Delete Cover Image
    
    func deleteCoverImage(for bookId: UUID) async throws {
        guard let userId = SupabaseService.shared.getCurrentUserId() else {
            throw CoverImageError.notAuthenticated
        }
        
        let fileName = "\(userId)/\(bookId).jpg"
        
        _ = try await supabase.storage
            .from("book-covers")
            .remove(paths: [fileName])
    }
    
    // MARK: - Download and Upload External Cover
    
    func downloadAndUploadExternalCover(from externalURL: String, for bookId: UUID) async throws -> String {
        // Download from external source (e.g., Open Library)
        let image = try await downloadCoverImage(from: externalURL)
        
        // Upload to our Supabase Storage
        return try await uploadCoverImage(image, for: bookId)
    }
}

// MARK: - Extensions

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Determine the scale factor that preserves aspect ratio
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
}

enum CoverImageError: LocalizedError {
    case notAuthenticated
    case invalidImage
    case invalidURL
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User not authenticated"
        case .invalidImage: return "Invalid image data"
        case .invalidURL: return "Invalid image URL"
        case .uploadFailed: return "Failed to upload image"
        }
    }
}
```

### 3. Update SupabaseService

```swift
// Add to SupabaseService.swift

// Update createBook method to accept coverUrl
func createBook(title: String, author: String?, shelfId: UUID, coverUrl: String? = nil) async throws -> Book {
    guard let userId = getCurrentUserId() else {
        throw SupabaseError.notAuthenticated
    }
    
    let newBook = BookInsert(
        title: title,
        author: author,
        shelfId: shelfId,
        userId: userId,
        coverUrl: coverUrl  // NEW
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

// Update updateBook method to accept coverUrl
func updateBook(id: UUID, title: String, author: String?, shelfId: UUID, coverUrl: String? = nil) async throws {
    let update = BookUpdate(
        title: title,
        author: author,
        shelfId: shelfId,
        coverUrl: coverUrl  // NEW
    )
    
    try await client
        .from("books")
        .update(update)
        .eq("id", value: id.uuidString)
        .execute()
}

// New method to update only cover URL
func updateBookCover(id: UUID, coverUrl: String?) async throws {
    struct CoverUpdate: Encodable {
        let coverUrl: String?
        
        enum CodingKeys: String, CodingKey {
            case coverUrl = "cover_url"
        }
    }
    
    let update = CoverUpdate(coverUrl: coverUrl)
    
    try await client
        .from("books")
        .update(update)
        .eq("id", value: id.uuidString)
        .execute()
}
```

### 4. Update BookPreviewView (ISBN Scan)

```swift
// Update BookPreviewView.swift to handle cover upload

struct BookPreviewView: View {
    let bookData: BookLookupResult
    let onConfirm: (String, String?, UUID, String?) -> Void  // Added coverUrl parameter
    let onCancel: () -> Void
    
    @StateObject private var supabase = SupabaseService.shared
    @State private var shelves: [Shelf] = []
    @State private var selectedShelfId: UUID?
    @State private var coverImage: UIImage?
    @State private var uploadedCoverUrl: String?
    @State private var isUploadingCover = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let coverImage = coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .frame(maxWidth: .infinity)
                        
                        if isUploadingCover {
                            ProgressView("Uploading cover...")
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        Image(systemName: "book.closed")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bookData.title)
                            .font(.headline)
                        
                        if !bookData.authors.isEmpty {
                            Text(bookData.authors.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("ISBN: \(bookData.isbn)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Picker("Shelf", selection: $selectedShelfId) {
                        Text("Select a shelf").tag(nil as UUID?)
                        ForEach(shelves) { shelf in
                            Text(shelf.name).tag(shelf.id as UUID?)
                        }
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
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let shelfId = selectedShelfId {
                            let author = bookData.authors.isEmpty ? nil : bookData.authors.joined(separator: ", ")
                            onConfirm(bookData.title, author, shelfId, uploadedCoverUrl)
                        }
                    }
                    .disabled(selectedShelfId == nil || isUploadingCover)
                }
            }
            .task {
                await loadShelves()
                await loadAndUploadCover()
            }
        }
    }
    
    private func loadShelves() async {
        do {
            shelves = try await supabase.fetchShelves()
        } catch {
            print("Error loading shelves: \(error)")
        }
    }
    
    private func loadAndUploadCover() async {
        guard let urlString = bookData.coverImageURL,
              let url = URL(string: urlString) else {
            return
        }
        
        isUploadingCover = true
        
        do {
            // Download cover image
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }
            
            await MainActor.run {
                self.coverImage = image
            }
            
            // Generate temporary book ID for upload
            // (We'll use this same ID when creating the book)
            let tempBookId = UUID()
            
            // Upload to Supabase Storage
            let coverUrl = try await CoverImageService.shared.uploadCoverImage(image, for: tempBookId)
            
            await MainActor.run {
                self.uploadedCoverUrl = coverUrl
                self.isUploadingCover = false
            }
        } catch {
            print("Error handling cover: \(error)")
            await MainActor.run {
                self.isUploadingCover = false
            }
        }
    }
}
```

### 5. Image Picker for Manual Upload

```swift
// ImagePickerView.swift
import SwiftUI
import PhotosUI

struct ImagePickerView: View {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                    
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
            }
            .navigationTitle("Add Cover Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onImageSelected(image)
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView { image in
                    onImageSelected(image)
                    showCamera = false
                    dismiss()
                }
            }
        }
    }
}

// Camera Capture View
struct CameraCaptureView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        
        init(_ parent: CameraCaptureView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

### 6. Update BookDetailView

```swift
// Update BookDetailView to show cover and allow changes

struct BookDetailView: View {
    @State var book: Book  // Changed to @State so we can update it
    
    @StateObject private var supabase = SupabaseService.shared
    @State private var shelves: [Shelf] = []
    @State private var coverImage: UIImage?
    @State private var isLoadingCover = false
    @State private var showImagePicker = false
    @State private var showEditBook = false
    @State private var showMoveToShelf = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Book Cover
                VStack {
                    if isLoadingCover {
                        ProgressView()
                            .frame(width: 200, height: 300)
                    } else if let coverImage = coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 300)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    } else {
                        Image(systemName: "book.closed")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                            .frame(width: 200, height: 300)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button {
                        showImagePicker = true
                    } label: {
                        Text(coverImage == nil ? "Add Cover" : "Change Cover")
                            .font(.caption)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                
                // Book Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(book.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Author
                if let author = book.author, !author.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Author")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(author)
                            .font(.title3)
                    }
                }
                
                // Current Shelf
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Shelf")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    if let shelf = shelves.first(where: { $0.id == book.shelfId }) {
                        Text(shelf.name)
                            .font(.body)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        showMoveToShelf = true
                    } label: {
                        Label("Move to Shelf", systemImage: "arrow.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button {
                        showEditBook = true
                    } label: {
                        Label("Edit Book", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    if book.coverUrl != nil {
                        Button(role: .destructive) {
                            removeCover()
                        } label: {
                            Label("Remove Cover", systemImage: "photo.badge.minus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Book", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { image in
                Task {
                    await uploadCover(image)
                }
            }
        }
        .sheet(isPresented: $showEditBook) {
            EditBookView(book: book, shelves: shelves, onUpdate: {
                dismiss()
            })
        }
        .sheet(isPresented: $showMoveToShelf) {
            MoveToShelfView(book: book, shelves: shelves, onMove: {
                dismiss()
            })
        }
        .confirmationDialog("Delete Book", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteBook()
            }
        } message: {
            Text("Are you sure you want to delete \"\(book.title)\"?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            await loadShelves()
            await loadCover()
        }
    }
    
    private func loadShelves() async {
        do {
            shelves = try await supabase.fetchShelves()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func loadCover() async {
        guard let coverUrl = book.coverUrl else { return }
        
        isLoadingCover = true
        do {
            let image = try await CoverImageService.shared.downloadCoverImage(from: coverUrl)
            await MainActor.run {
                self.coverImage = image
                self.isLoadingCover = false
            }
        } catch {
            print("Error loading cover: \(error)")
            await MainActor.run {
                self.isLoadingCover = false
            }
        }
    }
    
    private func uploadCover(_ image: UIImage) async {
        do {
            let coverUrl = try await CoverImageService.shared.uploadCoverImage(image, for: book.id)
            try await supabase.updateBookCover(id: book.id, coverUrl: coverUrl)
            
            await MainActor.run {
                book.coverUrl = coverUrl
                coverImage = image
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func removeCover() {
        Task {
            do {
                try await CoverImageService.shared.deleteCoverImage(for: book.id)
                try await supabase.updateBookCover(id: book.id, coverUrl: nil)
                
                await MainActor.run {
                    book.coverUrl = nil
                    coverImage = nil
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func deleteBook() {
        Task {
            do {
                // Delete cover image if exists
                if book.coverUrl != nil {
                    try? await CoverImageService.shared.deleteCoverImage(for: book.id)
                }
                
                try await supabase.deleteBook(id: book.id)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
```

### 7. Update ShelfDetailView (List)

```swift
// Update ShelfDetailView to show thumbnails

struct ShelfDetailView: View {
    let shelf: Shelf
    
    @StateObject private var supabase = SupabaseService.shared
    @State private var books: [Book] = []
    @State private var coverImages: [UUID: UIImage] = [:]  // NEW
    // ... rest of state variables
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if books.isEmpty {
                ContentUnavailableView(
                    "No Books Yet",
                    systemImage: "book.closed",
                    description: Text("Add your first book to this shelf")
                )
            } else {
                List {
                    ForEach(books) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            HStack(spacing: 12) {
                                // Cover thumbnail
                                Group {
                                    if let coverImage = coverImages[book.id] {
                                        Image(uiImage: coverImage)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "book.closed")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                                .frame(width: 50, height: 75)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                
                                // Book info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    
                                    if let author = book.author, !author.isEmpty {
                                        Text(author)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteBook)
                }
            }
        }
        // ... rest of view
        .task {
            await loadBooks()
            await loadAllCovers()
        }
    }
    
    private func loadBooks() async {
        isLoading = true
        do {
            books = try await supabase.fetchBooks(shelfId: shelf.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    private func loadAllCovers() async {
        for book in books {
            guard let coverUrl = book.coverUrl else { continue }
            
            do {
                let image = try await CoverImageService.shared.downloadCoverImage(from: coverUrl)
                await MainActor.run {
                    coverImages[book.id] = image
                }
            } catch {
                print("Error loading cover for book \(book.id): \(error)")
            }
        }
    }
    
    // ... rest of methods
}
```

### 8. Update Info.plist

Add photo library permission:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select book cover images</string>
<key>NSCameraUsageDescription</key>
<string>We need camera access to take photos of book covers</string>
```

---

## Database Migration Script

```sql
-- Run this in Supabase SQL Editor to add cover support

-- 1. Add cover_url column to books table
ALTER TABLE books 
ADD COLUMN IF NOT EXISTS cover_url TEXT;

-- 2. Create storage bucket for book covers
INSERT INTO storage.buckets (id, name, public)
VALUES ('book-covers', 'book-covers', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Set up RLS policies for book-covers bucket
CREATE POLICY "Users can upload their own book covers"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'book-covers' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own book covers"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'book-covers' 
  AND auth.uid()::text = (storage.
```