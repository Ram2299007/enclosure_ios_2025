//
//  CachedAsyncImage.swift
//  Enclosure
//
//  Created by ChatGPT on 19/11/25.
//

import SwiftUI
import CryptoKit
import UIKit

final class LocalImageCache {
    static let shared = LocalImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let directoryURL: URL

    private init() {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directoryURL = cachesDirectory.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }

        let fileURL = directoryURL.appendingPathComponent(fileName(for: url))
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            cache.setObject(image, forKey: key as NSString)
            return image
        }

        return nil
    }

    func save(image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        cache.setObject(image, forKey: key as NSString)

        let fileURL = directoryURL.appendingPathComponent(fileName(for: url))
        guard let data = image.pngData() ?? image.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString
    }

    private func fileName(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension
        return ext.isEmpty ? hash : "\(hash).\(ext)"
    }
}

final class ImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private var currentURL: URL?
    private var task: URLSessionDataTask?

    func update(url: URL?) {
        guard currentURL != url else { return }
        currentURL = url
        image = nil
        loadImage()
    }

    private func loadImage() {
        guard let url = currentURL else {
            print("⚠️ [CachedAsyncImage] loadImage called but currentURL is nil")
            return
        }
        
        print("🖼️ [CachedAsyncImage] loadImage called for: \(url.absoluteString)")
        print("🖼️ [CachedAsyncImage] isFileURL: \(url.isFileURL)")

        if let cached = LocalImageCache.shared.image(for: url) {
            print("✅ [CachedAsyncImage] Found cached image for: \(url.absoluteString)")
            self.image = cached
            return
        }

        // Handle local file URLs (matching Android local file loading)
        if url.isFileURL {
            print("📁 [CachedAsyncImage] Loading from local file: \(url.path)")
            // Load directly from file system
            if let data = try? Data(contentsOf: url) {
                print("📁 [CachedAsyncImage] File data loaded, size: \(data.count) bytes")
                if let uiImage = UIImage(data: data) {
                    print("✅ [CachedAsyncImage] UIImage created from local file, size: \(uiImage.size)")
                    LocalImageCache.shared.save(image: uiImage, for: url)
                    DispatchQueue.main.async {
                        if self.currentURL == url {
                            self.image = uiImage
                            print("✅ [CachedAsyncImage] Image set successfully from local file")
                        }
                    }
                } else {
                    print("❌ [CachedAsyncImage] Failed to create UIImage from local file data")
                }
            } else {
                print("❌ [CachedAsyncImage] Failed to load data from local file: \(url.path)")
            }
            return
        }

        // Handle remote URLs
        print("🌐 [CachedAsyncImage] Loading from network URL: \(url.absoluteString)")
        task?.cancel()
        task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ [CachedAsyncImage] Network error: \(error.localizedDescription)")
                return
            }
            
            guard let self = self, let data = data else {
                print("❌ [CachedAsyncImage] No data received from network")
                return
            }
            
            print("🌐 [CachedAsyncImage] Network data received, size: \(data.count) bytes")
            
            if let uiImage = UIImage(data: data) {
                print("✅ [CachedAsyncImage] UIImage created from network data, size: \(uiImage.size)")
                LocalImageCache.shared.save(image: uiImage, for: url)
                DispatchQueue.main.async {
                    if self.currentURL == url {
                        self.image = uiImage
                        print("✅ [CachedAsyncImage] Image set successfully from network")
                    }
                }
            } else {
                print("❌ [CachedAsyncImage] Failed to create UIImage from network data")
            }
        }
        task?.resume()
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @StateObject private var loader = ImageLoader()

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.update(url: url)
        }
        .onChange(of: url?.absoluteString ?? "") { _ in
            loader.update(url: url)
        }
    }
}


