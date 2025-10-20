import Foundation
import Supabase
import UIKit

enum CoverImageSize {
    case thumbnail
    case full

    var targetSize: CGSize {
        switch self {
        case .thumbnail:
            return CGSize(width: 50, height: 75)
        case .full:
            return CGSize(width: 600, height: 900)
        }
    }
}

enum CoverImageError: LocalizedError {
    case missingUser
    case invalidImage
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "You must be signed in to manage cover images."
        case .invalidImage:
            return "The selected image could not be processed."
        case .invalidResponse:
            return "The cover service returned an unexpected response."
        }
    }
}

final class CoverImageService {
    static let shared = CoverImageService()

    private let bucketName = "book-covers"
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let client: SupabaseClient

    private init(
        client: SupabaseClient = SupabaseService.shared.client,
        session: URLSession = .shared
    ) {
        self.client = client
        self.session = session
        cache.countLimit = 100
    }

    // MARK: - Public API

    func uploadCover(image: UIImage, bookId: UUID, userId: UUID) async throws -> URL {
        guard let resized = image.resizedMaintainingAspectRatio(maxSize: CoverImageSize.full.targetSize),
              let prepared = resized.jpegData(compressionQuality: 0.8) else {
            throw CoverImageError.invalidImage
        }

        let path = storagePath(userId: userId, bookId: bookId)
        let storage = client.storage.from(bucketName)

        try await storage.upload(
            path,
            data: prepared,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )

        cache.removeObject(forKey: cacheKey(for: path, size: .full))
        cache.removeObject(forKey: cacheKey(for: path, size: .thumbnail))

        return try storage.getPublicURL(path: path)
    }

    func deleteCover(for book: Book) async {
        guard book.coverURL != nil else { return }
        let path = storagePath(userId: book.userId, bookId: book.id)
        let storage = client.storage.from(bucketName)

        do {
            try await storage.remove(paths: [path])
        } catch {
            // swallow errors - cleanup best effort
        }

        cache.removeObject(forKey: cacheKey(for: path, size: .full))
        cache.removeObject(forKey: cacheKey(for: path, size: .thumbnail))
    }

    func image(for url: URL, size: CoverImageSize) async throws -> UIImage {
        let path = url.path.replacingOccurrences(of: "/storage/v1/object/public/\(bucketName)/", with: "")
        if let cached = cache.object(forKey: cacheKey(for: path, size: size)) {
            return cached
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw CoverImageError.invalidResponse
        }

        guard let image = UIImage(data: data) else {
            throw CoverImageError.invalidImage
        }

        let finalImage: UIImage
        if size == .full {
            finalImage = image.resizedMaintainingAspectRatio(maxSize: size.targetSize) ?? image
        } else {
            finalImage = image.resizedMaintainingAspectRatio(maxSize: size.targetSize) ?? image
        }

        cache.setObject(finalImage, forKey: cacheKey(for: path, size: size))
        return finalImage
    }

    func clearCache(for url: URL?) {
        guard let url else { return }
        let path = url.path.replacingOccurrences(of: "/storage/v1/object/public/\(bucketName)/", with: "")
        cache.removeObject(forKey: cacheKey(for: path, size: .full))
        cache.removeObject(forKey: cacheKey(for: path, size: .thumbnail))
    }

    func downloadRemoteImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw CoverImageError.invalidResponse
        }
        guard let image = UIImage(data: data) else {
            throw CoverImageError.invalidImage
        }
        return image
    }

    // MARK: - Helpers

    private func storagePath(userId: UUID, bookId: UUID) -> String {
        let userComponent = userId.uuidString.lowercased()
        let bookComponent = "\(bookId.uuidString.lowercased()).jpg"
        return "\(userComponent)/\(bookComponent)"
    }

    private func cacheKey(for path: String, size: CoverImageSize) -> NSString {
        NSString(string: "\(size)_\(path)")
    }
}

private extension UIImage {
    func resizedMaintainingAspectRatio(maxSize: CGSize) -> UIImage? {
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let scaleRatio = min(widthRatio, heightRatio, 1.0)
        let targetSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
