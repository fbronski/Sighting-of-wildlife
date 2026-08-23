// Edited by FBronski
// 20.07.2026

import ImageIO
import SwiftUI
import UIKit

struct CheckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Label {
                configuration.label
            } icon: {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
                    .accessibility(label: Text(configuration.isOn ? "Checked" : "Unchecked"))
                    .imageScale(.large)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum SichtungCardDensity {
    case full
    case medium
    case compact
    case thumbnail

    init(columnCount: Int) {
        switch columnCount {
        case 1:
            self = .full
        case 2:
            self = .medium
        case 3...4:
            self = .compact
        default:
            self = .thumbnail
        }
    }

    var imageHeight: CGFloat {
        switch self {
        case .full: 240
        case .medium: 170
        case .compact: 112
        case .thumbnail: 64
        }
    }

    var maxPixelSize: CGFloat {
        switch self {
        case .full: 900
        case .medium: 560
        case .compact: 340
        case .thumbnail: 180
        }
    }

    var contentPadding: CGFloat {
        switch self {
        case .full: 12
        case .medium: 9
        case .compact: 6
        case .thumbnail: 4
        }
    }

    var cornerRadius: CGFloat { 8 }
    var spacing: CGFloat { self == .thumbnail ? 3 : 6 }
    var titleFont: Font { self == .full ? .title3 : (self == .thumbnail ? .caption2 : .caption) }
    var statusFont: Font { self == .full ? .headline : .caption2 }
    var bodyFont: Font { self == .full ? .caption : .caption2 }
    var titleLineLimit: Int { self == .full ? 2 : 1 }
    var statusLineLimit: Int { self == .full ? 3 : 1 }
    var bodyLineLimit: Int { self == .full ? 4 : (self == .medium ? 2 : 0) }
    var showsStatus: Bool { self != .thumbnail }
    var showsBody: Bool { self == .full || self == .medium }
    var overlaysPinToggle: Bool { self == .compact || self == .thumbnail }
    var fetchesMissingImages: Bool { self == .full || self == .medium }
}

private struct DecodedImageResult: @unchecked Sendable {
    let image: UIImage?
    let cost: Int
}

struct CardView: View {
    
    @State var wildsichtung: Wildsichtung
    @AppStorage("languageIndex") private var languageIndex = 0
    @State public var isPinned: Bool
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var imageLoadTask: Task<Void, Never>?
    
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 180
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()

    private let fileManager = FileManager.default
    private let columnCount: Int
    private var density: SichtungCardDensity { SichtungCardDensity(columnCount: columnCount) }
    private var cacheKey: String { "\(wildsichtung.immichid)-\(Int(density.maxPixelSize))" }
    private var imageBackgroundColor: Color { Color(.systemBackground) }
    private var pinToggleColor: Color {
        if isPinned {
            return .accentColor
        }

        return density.overlaysPinToggle ? .primary : .secondary
    }
    
    init(wildsichtung: Wildsichtung, isPinned: Bool, columnCount: Int = 1) {
        self.wildsichtung = wildsichtung
        self.isPinned = isPinned
        self.columnCount = columnCount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: density.spacing) {
            ZStack(alignment: .topTrailing) {
                imageContent

                if density.overlaysPinToggle {
                    pinToggle
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: density.spacing) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(wildsichtung.title)
                        .font(density.titleFont.weight(.semibold))
                        .lineLimit(density.titleLineLimit)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !density.overlaysPinToggle {
                        pinToggle
                    }
                }

                if density.showsStatus {
                    Text(wildsichtung.yolostatus)
                        .lineLimit(density.statusLineLimit)
                        .font(density.statusFont)
                        .foregroundStyle(Color.green)
                }

                if density.showsBody {
                    Text(wildsichtung.body)
                        .lineLimit(density.bodyLineLimit)
                        .font(density.bodyFont)
                        .foregroundStyle(.primary)
                }
            }
            .padding(density.contentPadding)
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous)
                .stroke(Color(red: 150/255, green: 150/255, blue: 150/255, opacity: 0.22), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous))
        .onAppear {
            loadImageIfNeeded()
        }
        .onDisappear {
            imageLoadTask?.cancel()
            imageLoadTask = nil
            isLoading = false
        }
        .onChange(of: wildsichtung.imagebase64) {
            imageLoadTask?.cancel()
            imageLoadTask = nil
            image = nil
            loadImageIfNeeded()
        }
        .onChange(of: columnCount) {
            imageLoadTask?.cancel()
            imageLoadTask = nil
            image = nil
            loadImageIfNeeded()
        }
    }

    private var pinToggle: some View {
        Button {
            isPinned.toggle()
            _ = DatabaseManager.shared.updatePinned(iid: wildsichtung.immichid, pinned: isPinned)
            print(isPinned)
        } label: {
            Image(systemName: isPinned ? "checkmark.circle.fill" : "circle")
                .font(.system(size: density == .thumbnail ? 18 : 22, weight: .semibold))
                .foregroundStyle(pinToggleColor)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
                .shadow(color: density.overlaysPinToggle ? .black.opacity(0.25) : .clear, radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPinned ? "Checked" : "Unchecked")
    }
    
    private var imageContent: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: density == .full ? .fit : .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: density.imageHeight)
                    .clipped()
                    .background(imageBackgroundColor)
            } else if isLoading {
                if density == .thumbnail {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: density.imageHeight)
                        .background(imageBackgroundColor)
                } else {
                    ProgressView(appText(.imageLoading, languageIndex: languageIndex))
                        .frame(maxWidth: .infinity)
                        .frame(height: density.imageHeight)
                        .foregroundColor(.secondary)
                        .background(imageBackgroundColor)
                }
            } else {
                placeholderContent
                    .frame(maxWidth: .infinity)
                    .frame(height: density.imageHeight)
                    .background(imageBackgroundColor)
            }
        }
    }

    private var placeholderContent: some View {
        Group {
            if density == .thumbnail {
                Image(systemName: "photo")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            } else {
                Text(wildsichtung.imagebase64.isEmpty ? appText(.noImageAvailable, languageIndex: languageIndex) : appText(.imageLoadingFailed, languageIndex: languageIndex))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(6)
            }
        }
    }

    private func loadImageIfNeeded() {
        guard image == nil, imageLoadTask == nil else {
            return
        }

        let key = cacheKey as NSString
        if let cachedImage = Self.imageCache.object(forKey: key) {
            image = cachedImage
            return
        }

        if !wildsichtung.imagebase64.isEmpty {
            loadStoredImage(cacheKey: key)
            return
        }

        guard density.fetchesMissingImages else {
            return
        }

        isLoading = true
        imageLoadTask = Task {
            await fetchImageData(cacheKey: key)
            imageLoadTask = nil
            isLoading = false
        }
    }

    private func loadStoredImage(cacheKey: NSString) {
        let base64 = wildsichtung.imagebase64
        let maxPixelSize = density.maxPixelSize
        isLoading = true
        imageLoadTask = Task {
            let result = await Self.decodeBase64Image(base64, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }

            if let decodedImage = result.image {
                Self.imageCache.setObject(decodedImage, forKey: cacheKey, cost: result.cost)
                image = decodedImage
            }

            imageLoadTask = nil
            isLoading = false
        }
    }

    private func fetchImageData(cacheKey: NSString) async {
        do {
            let client = OpenAPIClientAPIConfiguration.shared
            client.basePath = UserDefaults.standard.string(forKey: "immichurltext")! + "/api"
            client.customHeaders = [
                "x-api-key": UserDefaults.standard.string(forKey: "immichapikey")!,
                "Accept": "application/octet-stream"
            ]

            let response = try await AssetsAPI.downloadAsset(id: wildsichtung.immichid, key: nil, apiConfiguration: client)
            try Task.checkCancellation()

            let url = URL(fileURLWithPath: response.path())
            defer {
                try? fileManager.removeItem(at: url)
            }

            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: url)
            }.value
            try Task.checkCancellation()

            async let decodedResult = Self.decodeImage(data, maxPixelSize: density.maxPixelSize)
            async let encodedImage = Task.detached(priority: .utility) {
                data.base64EncodedString()
            }.value

            let result = await decodedResult
            let imagebase64 = await encodedImage
            try Task.checkCancellation()

            if DatabaseManager.shared.updateImage(iid: wildsichtung.immichid, imagebase64: imagebase64) {
                wildsichtung.imagebase64 = imagebase64
                if let decodedImage = result.image {
                    Self.imageCache.setObject(decodedImage, forKey: cacheKey, cost: result.cost)
                    image = decodedImage
                }
            }
        } catch is CancellationError {
            return
        } catch {
            print("Get Image Date Error: \(error)")
        }
    }

    nonisolated private static func decodeBase64Image(_ base64: String, maxPixelSize: CGFloat) async -> DecodedImageResult {
        await Task.detached(priority: .utility) {
            guard let data = Data(base64Encoded: base64) else {
                return DecodedImageResult(image: nil, cost: 0)
            }

            return decodeImage(data, maxPixelSize: maxPixelSize)
        }.value
    }

    nonisolated private static func decodeImage(_ data: Data, maxPixelSize: CGFloat) -> DecodedImageResult {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return DecodedImageResult(image: UIImage(data: data), cost: data.count)
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize))
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return DecodedImageResult(image: UIImage(data: data), cost: data.count)
        }

        let image = UIImage(cgImage: cgImage)
        let bytesPerRow = cgImage.bytesPerRow
        let cost = bytesPerRow * cgImage.height
        return DecodedImageResult(image: image, cost: cost)
    }
}

#Preview {
    CardView(wildsichtung: Wildsichtung(id: 1, title: "titel", cameraid: "cameraid", subtitle: "subtitle", body: "body", immichid: "immichid", yolostatus: "status", imagebase64: "", creationDate: Date(), pinned: false), isPinned: true)
}
