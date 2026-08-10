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
    @State public var isPinned: Bool
    @State private var imageData: Data? = nil
    @State private var isLoading = false
    
    let fileManager = FileManager.default
    
    init(wildsichtung: Wildsichtung, isPinned: Bool) {
        self.wildsichtung = wildsichtung
        self.isPinned = isPinned
    }
    
    var body: some View {
        VStack {
            // Show image or loading state based on what we have
            if let data = imageData, !data.isEmpty {
                Image(uiImage: UIImage(data: data)!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minHeight: 200)
               
            } else if isLoading {
                // Show loading indicator when downloading image
                ProgressView("Loading image...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            } else {
                // Show no image available or base64 decoding failure
                if wildsichtung.imagebase64.isEmpty {
                    Text("No image available")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundColor(.secondary)
                } else {
                    // Try to decode existing base64 data
                    if let data = Data(base64Encoded: wildsichtung.imagebase64) {
                        Image(uiImage: UIImage(data: data)!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(minHeight: 200)
                    } else {
                        Text("Image loading failed")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Text(wildsichtung.title)
                            .font(.title)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading).tint(Color.primary).fixedSize(horizontal: false, vertical: true)
                        
                        Toggle("", isOn: $isPinned)
                            .toggleStyle(CheckToggleStyle())
                            .onChange(of: isPinned) { pin in
                                DatabaseManager.shared.updatePinned(iid: wildsichtung.immichid, pinned: pin)
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
    }
    
    // Load image when view appears
    private func loadInitialImage() {
        // Check if we already have base64 data in the model and try to decode it
        if !wildsichtung.imagebase64.isEmpty,
           let data = Data(base64Encoded: wildsichtung.imagebase64) {
            imageData = data
        } else if wildsichtung.imagebase64.isEmpty {
            // If no base64 data but the model has an empty image, download from API
            isLoading = true
            Task {
                await fetchDataAndRefresh()
                isLoading = false
            }
        }
    }
    
    // Async function to fetch image from API and refresh UI
    private func fetchDataAndRefresh() async {
        do {
            let client = OpenAPIClientAPIConfiguration.shared
            URL(string:  UserDefaults.standard.string(forKey: "immichurltext")!)
            //https://jagd.ossecm.de/api
            client.basePath = UserDefaults.standard.string(forKey: "immichurltext")!+"/api"
            //client.customHeaders = ["x-api-key":"tcWm2UOcGj7ICRtNMvN8l5P8qJpRpKeisNgktWplGo","Accept":"application/octet-stream"]
            client.customHeaders = ["x-api-key":UserDefaults.standard.string(forKey: "immichapikey")!,"Accept":"application/octet-stream"]
            let version = try await ServerAPI.getVersionHistory(apiConfiguration: client)
            print("Immich Version: \(version)")
            
            let response = try await AssetsAPI.downloadAsset(id: wildsichtung.immichid, key: nil, apiConfiguration: client)
            
            let cachepath = response.path()
            let url = URL(fileURLWithPath: cachepath)
            
            let data = try Data(contentsOf: url)
            
            // Update database with new base64
            let dt = Data(data)
            let ab = (dt.base64EncodedString())
            let result = DatabaseManager.shared.updateImage(iid: wildsichtung.immichid, imagebase64: ab)
            
            if result == true {
                // Update the model locally and our view data
                wildsichtung.imagebase64 = ab
                imageData = dt
                
                // Remove temp file
                try fileManager.removeItem(at: url)
                
                return
            }
            
            try fileManager.removeItem(at: url)
        } catch {
            print("Get Image Date Error: \(error)")
            isLoading = false
        }
    }
}

#Preview {
    CardView(wildsichtung: Wildsichtung(id: 1, title: "titel", cameraid: "cameraid", subtitle: "subtitle", body: "body", immichid: "immichid", yolostatus: "status", imagebase64: "", creationDate: Date(), pinned: false), isPinned: true)
}
