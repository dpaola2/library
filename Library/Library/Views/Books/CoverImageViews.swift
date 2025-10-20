import SwiftUI
import UIKit

struct BookCoverThumbnailView: View {
    let coverURL: URL?

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .frame(width: 50, height: 75)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: coverURL) {
            await loadImage()
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        Image(systemName: "book.closed")
            .foregroundStyle(.secondary)
    }

    @MainActor
    private func loadImage() async {
        guard let coverURL else {
            image = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            image = try await CoverImageService.shared.image(for: coverURL, size: .thumbnail)
        } catch {
            image = nil
        }
    }
}

struct BookCoverFullView: View {
    let coverURL: URL?
    @Binding var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 6, y: 4)
            } else if coverURL != nil {
                ProgressView()
                    .frame(height: 220)
            } else {
                placeholder
            }
        }
        .task(id: coverURL) {
            await loadFullImage()
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 200, height: 300)
            .overlay {
                Image(systemName: "book")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
            }
    }

    @MainActor
    private func loadFullImage() async {
        guard let coverURL else {
            image = nil
            return
        }

        do {
            image = try await CoverImageService.shared.image(for: coverURL, size: .full)
        } catch {
            image = nil
        }
    }
}
