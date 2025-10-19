import Foundation

struct BookLookupResult: Identifiable, Equatable {
    var id: String { isbn }
    let isbn: String
    let title: String
    let author: String?
    let coverURL: URL?
}

enum ISBNServiceError: LocalizedError {
    case invalidISBN
    case notFound
    case invalidResponse
    case networkFailure(Error)

    var errorDescription: String? {
        switch self {
        case .invalidISBN:
            return "That barcode does not appear to be a valid ISBN."
        case .notFound:
            return "We couldn't find book details for that ISBN."
        case .invalidResponse:
            return "The book service returned an unexpected response."
        case .networkFailure(let error):
            return error.localizedDescription
        }
    }
}

final class ISBNService {
    static let shared = ISBNService()

    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func lookupBook(isbn rawISBN: String) async throws -> BookLookupResult {
        let isbn = normalizeISBN(rawISBN)

        guard let isbn else {
            throw ISBNServiceError.invalidISBN
        }

        if let openLibraryResult = try await fetchFromOpenLibrary(isbn: isbn) {
            return openLibraryResult
        }

        if let googleBooksResult = try await fetchFromGoogleBooks(isbn: isbn) {
            return googleBooksResult
        }

        throw ISBNServiceError.notFound
    }

    private func normalizeISBN(_ isbn: String) -> String? {
        let cleaned = isbn
            .uppercased()
            .filter { $0.isNumber || $0 == "X" }

        guard cleaned.count == 10 || cleaned.count == 13 else {
            return nil
        }

        return cleaned
    }

    private func fetchFromOpenLibrary(isbn: String) async throws -> BookLookupResult? {
        guard let url = URL(string: "https://openlibrary.org/isbn/\(isbn).json") else {
            throw ISBNServiceError.invalidResponse
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ISBNServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let book = try decoder.decode(OpenLibraryBookResponse.self, from: data)

                let authorName = try await fetchOpenLibraryAuthorName(for: book.authors?.first?.key)
                let title = book.displayTitle
                let coverURL = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false")

                return BookLookupResult(
                    isbn: isbn,
                    title: title,
                    author: authorName,
                    coverURL: coverURL
                )
            case 404:
                return nil
            default:
                return nil
            }
        } catch let error as DecodingError {
            throw ISBNServiceError.invalidResponse
        } catch {
            throw ISBNServiceError.networkFailure(error)
        }
    }

    private func fetchOpenLibraryAuthorName(for key: String?) async throws -> String? {
        guard let key, let url = URL(string: "https://openlibrary.org\(key).json") else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let author = try JSONDecoder().decode(OpenLibraryAuthorResponse.self, from: data)
            return author.name
        } catch {
            return nil
        }
    }

    private func fetchFromGoogleBooks(isbn: String) async throws -> BookLookupResult? {
        let query = "https://www.googleapis.com/books/v1/volumes?q=isbn:\(isbn)&maxResults=1"
        guard let url = URL(string: query) else {
            throw ISBNServiceError.invalidResponse
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ISBNServiceError.invalidResponse
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if httpResponse.statusCode == 404 {
                    return nil
                }
                throw ISBNServiceError.invalidResponse
            }

            let googleResponse = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
            guard let item = googleResponse.items?.first else { return nil }

            let info = item.volumeInfo
            let title = info.title ?? "Unknown Title"
            let author = info.authors?.first
            let coverURL = info.imageLinks?.preferredURL

            return BookLookupResult(
                isbn: isbn,
                title: title,
                author: author,
                coverURL: coverURL
            )
        } catch let error as DecodingError {
            throw ISBNServiceError.invalidResponse
        } catch {
            throw ISBNServiceError.networkFailure(error)
        }
    }
}

// MARK: - Open Library Models

private struct OpenLibraryBookResponse: Decodable {
    struct AuthorReference: Decodable {
        let key: String
    }

    let title: String?
    let subtitle: String?
    let authors: [AuthorReference]?

    var displayTitle: String {
        if let title, let subtitle, !subtitle.isEmpty {
            return "\(title): \(subtitle)"
        }
        return title ?? "Unknown Title"
    }
}

private struct OpenLibraryAuthorResponse: Decodable {
    let name: String?
}

// MARK: - Google Books Models

private struct GoogleBooksResponse: Decodable {
    let items: [GoogleBookItem]?
}

private struct GoogleBookItem: Decodable {
    let volumeInfo: GoogleVolumeInfo
}

private struct GoogleVolumeInfo: Decodable {
    let title: String?
    let authors: [String]?
    let imageLinks: GoogleImageLinks?
}

private struct GoogleImageLinks: Decodable {
    let thumbnail: String?
    let smallThumbnail: String?

    var preferredURL: URL? {
        if let urlString = thumbnail ?? smallThumbnail {
            return URL(string: urlString.replacingOccurrences(of: "http://", with: "https://"))
        }
        return nil
    }
}
