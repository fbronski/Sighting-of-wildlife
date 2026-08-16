// Edited by FBronski
// 20.07.2026

import SwiftUI

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

struct CardView: View {
    
    @State var wildsichtung: Wildsichtung
    @AppStorage("languageIndex") private var languageIndex = 0
    @State public var isPinned: Bool
    @State private var imageData: Data? = nil
    @State private var isLoading = false
    @State private var imageLoadTask: Task<Void, Never>?
    
    private let fileManager = FileManager.default
    
    init(wildsichtung: Wildsichtung, isPinned: Bool) {
        self.wildsichtung = wildsichtung
        self.isPinned = isPinned
    }
    
    var body: some View {
        VStack {
            imageContent
            
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Text(wildsichtung.title)
                            .font(.title)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading).tint(Color.primary).fixedSize(horizontal: false, vertical: true)
                        
                        Toggle("", isOn: $isPinned)
                            .toggleStyle(CheckToggleStyle())
                            .onChange(of: isPinned) { _, pin in
                                _ = DatabaseManager.shared.updatePinned(iid: wildsichtung.immichid, pinned: pin)
                                print(pin)
                            }
                    }
                    
                    Text(wildsichtung.yolostatus)
                        .lineLimit(5).font(.headline).foregroundStyle(Color.green)
                    
                    Text(wildsichtung.body)
                        .lineLimit(5).font(.caption2).tint(Color.primary)
                }
            }
            .padding()
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 150/255, green: 150/255, blue: 150/255, opacity: 0.2), lineWidth: 1)
                .shadow(radius: 1)
        )
        .padding([.top, .horizontal])
        .onAppear {
            loadInitialImage()
        }
        .onDisappear {
            imageLoadTask?.cancel()
        }
        .onChange(of: wildsichtung.imagebase64) {
            imageData = decodedImageData
        }
    }
    
    private var imageContent: some View {
        Group {
            if let image = decodedUIImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 200)
            } else if isLoading {
                ProgressView(appText(.imageLoading, languageIndex: languageIndex))
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .foregroundColor(.secondary)
                    .background(Color(.secondarySystemGroupedBackground))
            } else {
                Text(wildsichtung.imagebase64.isEmpty ? appText(.noImageAvailable, languageIndex: languageIndex) : appText(.imageLoadingFailed, languageIndex: languageIndex))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color(.secondarySystemGroupedBackground))
            }
        }
    }

    private func loadInitialImage() {
        if let data = decodedImageData {
            imageData = data
            return
        }

        guard wildsichtung.imagebase64.isEmpty, imageLoadTask == nil else {
            return
        }

        isLoading = true
        imageLoadTask = Task {
            await fetchImageData()
            imageLoadTask = nil
            isLoading = false
        }
    }

    private func fetchImageData() async {
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

            let data = try Data(contentsOf: url)
            try Task.checkCancellation()

            let encodedImage = data.base64EncodedString()
            if DatabaseManager.shared.updateImage(iid: wildsichtung.immichid, imagebase64: encodedImage) {
                wildsichtung.imagebase64 = encodedImage
                imageData = data
            }
        } catch is CancellationError {
            return
        } catch {
            print("Get Image Date Error: \(error)")
        }
    }

    private var decodedImageData: Data? {
        guard !wildsichtung.imagebase64.isEmpty else {
            return nil
        }
        return Data(base64Encoded: wildsichtung.imagebase64)
    }

    private var decodedUIImage: UIImage? {
        guard let data = imageData ?? decodedImageData else {
            return nil
        }
        return UIImage(data: data)
    }
}

#Preview {
    CardView(wildsichtung: Wildsichtung(id: 1, title: "titel", cameraid: "cameraid", subtitle: "subtitle", body: "body", immichid: "immichid", yolostatus: "status", imagebase64: "", creationDate: Date(), pinned: false), isPinned: true)
}
