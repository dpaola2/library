

## Overview

Add a one-tap ISBN barcode scanner to quickly add books to your library by scanning their ISBN barcode with the camera.

---

## Product Requirements

### User Flow

1. User taps "Scan ISBN" button from Shelf Detail View or Add Book screen
2. Camera view opens with barcode detection overlay
3. User points camera at ISBN barcode (13-digit or 10-digit)
4. App automatically detects and reads barcode
5. App looks up book details from ISBN API
6. App shows preview with: title, author, cover image
7. User confirms and selects shelf
8. Book is added to database

### Success Criteria

- Scan completes in < 3 seconds
- 95%+ accuracy on clear barcodes
- Works in various lighting conditions
- Graceful fallback if book not found
- No cost or low cost per lookup

---

## API Research & Recommendation

### Option 1: Open Library API (FREE - RECOMMENDED)

**Pros:**

- Completely free, no rate limits
- Run by Internet Archive (reliable)
- Good coverage of books
- Simple REST API
- No authentication required

**Cons:**

- Less complete metadata than commercial services
- Occasionally slower response times

**Endpoint:**

```
https://openlibrary.org/isbn/{ISBN}.json
```

### Option 2: Google Books API (FREE)

**Pros:**

- Free with generous limits (1000 requests/day)
- Excellent book coverage
- High-quality metadata and cover images

**Cons:**

- Requires API key
- Rate limited

**Endpoint:**

```
https://www.googleapis.com/books/v1/volumes?q=isbn:{ISBN}
```

### Option 3: ISBNdb.com (PAID - $10-49/mo)

**Pros:**

- Most comprehensive database
- Fast and reliable
- Rich metadata

**Cons:**

- Costs money ($10/mo for 500 requests)
- Overkill for personal use

**Endpoint:**

```
https://api2.isbndb.com/book/{ISBN}
Header: Authorization: {YOUR_API_KEY}
```

### Recommendation: Start with Open Library

Use Open Library API as primary, with Google Books as fallback. Both are free and sufficient for personal use.

---

## Technical Architecture

### Components Needed

1. **Barcode Scanner** - Use Apple's Vision framework (built-in, free)
2. **ISBN API Client** - HTTP requests to Open Library/Google Books
3. **Image Loader** - URLSession for cover images
4. **New Views:**
    - `ISBNScannerView` - Camera + barcode detection
    - `BookPreviewView` - Show scanned book before saving

### Data Flow

```
Camera → Vision Framework → ISBN String → API Lookup → 
Book Data → User Confirms → Supabase Insert
```

---

## Implementation

### 1. Info.plist Configuration

Add camera permission:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan book ISBN barcodes</string>
```

### 2. ISBN API Service

```swift
// ISBNService.swift
import Foundation

struct BookLookupResult {
    let isbn: String
    let title: String
    let authors: [String]
    let coverImageURL: String?
}

class ISBNService {
    static let shared = ISBNService()
    
    // Try Open Library first, fallback to Google Books
    func lookupBook(isbn: String) async throws -> BookLookupResult {
        // Clean ISBN (remove hyphens, spaces)
        let cleanISBN = isbn.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
        
        // Try Open Library first
        if let result = try? await lookupOpenLibrary(isbn: cleanISBN) {
            return result
        }
        
        // Fallback to Google Books
        return try await lookupGoogleBooks(isbn: cleanISBN)
    }
    
    private func lookupOpenLibrary(isbn: String) async throws -> BookLookupResult {
        let urlString = "https://openlibrary.org/isbn/\(isbn).json"
        guard let url = URL(string: urlString) else {
            throw ISBNError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ISBNError.bookNotFound
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let title = json?["title"] as? String else {
            throw ISBNError.invalidResponse
        }
        
        // Extract authors
        var authors: [String] = []
        if let authorsList = json?["authors"] as? [[String: Any]] {
            // Authors are references, need to fetch separately or use name if available
            // For simplicity, we'll get author keys and fetch them
            for authorDict in authorsList {
                if let authorKey = authorDict["key"] as? String {
                    // Could fetch author name here, but simplifying
                    authors.append(authorKey.components(separatedBy: "/").last ?? "")
                }
            }
        }
        
        // Get cover image
        var coverURL: String?
        if let covers = json?["covers"] as? [Int], let firstCover = covers.first {
            coverURL = "https://covers.openlibrary.org/b/id/\(firstCover)-M.jpg"
        }
        
        return BookLookupResult(
            isbn: isbn,
            title: title,
            authors: authors,
            coverImageURL: coverURL
        )
    }
    
    private func lookupGoogleBooks(isbn: String) async throws -> BookLookupResult {
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)"
        guard let url = URL(string: urlString) else {
            throw ISBNError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ISBNError.bookNotFound
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let items = json?["items"] as? [[String: Any]],
              let firstItem = items.first,
              let volumeInfo = firstItem["volumeInfo"] as? [String: Any],
              let title = volumeInfo["title"] as? String else {
            throw ISBNError.bookNotFound
        }
        
        let authors = volumeInfo["authors"] as? [String] ?? []
        
        var coverURL: String?
        if let imageLinks = volumeInfo["imageLinks"] as? [String: String] {
            coverURL = imageLinks["thumbnail"] ?? imageLinks["smallThumbnail"]
        }
        
        return BookLookupResult(
            isbn: isbn,
            title: title,
            authors: authors,
            coverImageURL: coverURL
        )
    }
}

enum ISBNError: LocalizedError {
    case invalidURL
    case bookNotFound
    case invalidResponse
    case scanningFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .bookNotFound: return "Book not found in database"
        case .invalidResponse: return "Invalid response from server"
        case .scanningFailed: return "Failed to scan barcode"
        }
    }
}
```

### 3. ISBN Scanner View

```swift
// ISBNScannerView.swift
import SwiftUI
import AVFoundation
import Vision

struct ISBNScannerView: View {
    let onISBNDetected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isScanning = true
    @State private var detectedISBN: String?
    
    var body: some View {
        ZStack {
            CameraPreview(isScanning: $isScanning, onBarcodeDetected: { isbn in
                if detectedISBN == nil {
                    detectedISBN = isbn
                    isScanning = false
                    onISBNDetected(isbn)
                }
            })
            .edgesIgnoringSafeArea(.all)
            
            // Scanning overlay
            VStack {
                Spacer()
                
                // Scanning guide
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 280, height: 160)
                    .overlay(
                        Text("Position barcode within frame")
                            .foregroundColor(.white)
                            .padding(.top, 180)
                    )
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
                .padding()
            }
        }
        .navigationBarHidden(true)
    }
}

// Camera Preview with Barcode Detection
struct CameraPreview: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    let onBarcodeDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.isScanning = isScanning
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeDetected: onBarcodeDetected)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let onBarcodeDetected: (String) -> Void
        
        init(onBarcodeDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
        }
        
        func didDetectBarcode(_ code: String) {
            onBarcodeDetected(code)
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didDetectBarcode(_ code: String)
}

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    var isScanning = true
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let sequenceHandler = VNSequenceRequestHandler()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isScanning else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let results = request.results as? [VNBarcodeObservation],
                  let firstBarcode = results.first,
                  let payload = firstBarcode.payloadStringValue else {
                return
            }
            
            // Check if it's an ISBN (10 or 13 digits)
            let cleanPayload = payload.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
            if cleanPayload.count == 10 || cleanPayload.count == 13 {
                DispatchQueue.main.async {
                    self?.delegate?.didDetectBarcode(cleanPayload)
                }
            }
        }
        
        request.symbologies = [.ean13, .ean8] // ISBN barcodes are EAN
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
}
```

### 4. Book Preview View

```swift
// BookPreviewView.swift
import SwiftUI

struct BookPreviewView: View {
    let bookData: BookLookupResult
    let onConfirm: (String, String?, UUID) -> Void
    let onCancel: () -> Void
    
    @StateObject private var supabase = SupabaseService.shared
    @State private var shelves: [Shelf] = []
    @State private var selectedShelfId: UUID?
    @State private var coverImage: UIImage?
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
                            onConfirm(bookData.title, author, shelfId)
                        }
                    }
                    .disabled(selectedShelfId == nil)
                }
            }
            .task {
                await loadShelves()
                await loadCoverImage()
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
    
    private func loadCoverImage() async {
        guard let urlString = bookData.coverImageURL,
              let url = URL(string: urlString) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.coverImage = image
                }
            }
        } catch {
            print("Error loading cover: \(error)")
        }
    }
}
```

### 5. Integration with ShelfDetailView

Add scan button to the toolbar:

```swift
// Update ShelfDetailView
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Menu {
            Button {
                showAddBook = true
            } label: {
                Label("Add Book Manually", systemImage: "plus")
            }
            
            Button {
                showScanner = true
            } label: {
                Label("Scan ISBN", systemImage: "barcode.viewfinder")
            }
            
            Button {
                showEditShelf = true
            } label: {
                Label("Edit Shelf", systemImage: "pencil")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
.sheet(isPresented: $showScanner) {
    ISBNScannerView { isbn in
        Task {
            await handleScannedISBN(isbn)
        }
    }
}
.sheet(isPresented: $showBookPreview) {
    if let bookData = scannedBookData {
        BookPreviewView(
            bookData: bookData,
            onConfirm: { title, author, shelfId in
                Task {
                    await saveScannedBook(title: title, author: author, shelfId: shelfId)
                }
            },
            onCancel: {
                showBookPreview = false
                scannedBookData = nil
            }
        )
    }
}

// Add state variables
@State private var showScanner = false
@State private var showBookPreview = false
@State private var scannedBookData: BookLookupResult?

// Add helper methods
private func handleScannedISBN(_ isbn: String) async {
    showScanner = false
    
    do {
        let bookData = try await ISBNService.shared.lookupBook(isbn: isbn)
        scannedBookData = bookData
        showBookPreview = true
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}

private func saveScannedBook(title: String, author: String?, shelfId: UUID) async {
    do {
        _ = try await supabase.createBook(title: title, author: author, shelfId: shelfId)
        showBookPreview = false
        scannedBookData = nil
        await loadBooks()
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
}
```

---

## Testing Plan

1. **Barcode Detection**
    
    - Test with real book barcodes
    - Test with ISBN-10 and ISBN-13
    - Test in various lighting conditions
    - Test with damaged/partial barcodes
2. **API Integration**
    
    - Test with popular books (high chance of success)
    - Test with obscure books
    - Test with invalid ISBNs
    - Test network failures
3. **User Experience**
    
    - Time from tap to scan: < 3 seconds
    - Preview shows correctly
    - Book saves to correct shelf
    - Cancel works at each step

---

## Future Enhancements

- **Manual ISBN entry** - Fallback if camera doesn't work
- **Bulk scanning** - Scan multiple books in a row
- **ISBN history** - Remember recently scanned ISBNs
- **Cover image storage** - Save cover to Supabase Storage
- **Better author parsing** - Handle multiple authors better
- **Flashlight toggle** - For scanning in low light
- **Additional metadata** - Publisher, publication date, page count

---

## Cost Analysis

**Current Setup (Free):**

- Open Library API: Free, unlimited
- Google Books fallback: Free, 1000/day
- Apple Vision Framework: Free (built into iOS)

**Total: $0/month**

**If scaling to ISBNdb:**

- Basic Plan: $10/mo for 500 lookups
- Premium: $49/mo for 10,000 lookups

**Recommendation:** Start free, upgrade only if needed.