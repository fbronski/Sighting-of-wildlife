// Edited by FBronski
// 20.07.2026
import SwiftUI


struct CameraView: View {
    
    @State var camera: WildsichtungCamera
    @AppStorage("languageIndex") private var languageIndex = 0
   
    @State private var imageData: Data? = nil
    @State private var isLoading = false
    
    let fileManager = FileManager.default
    
    init(camera: WildsichtungCamera) {
        self.camera = camera
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
                ProgressView(appText(.imageLoading, languageIndex: languageIndex))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            } else {
                // Show no image available or base64 decoding failure
                if camera.standOrt64.isEmpty {
                    Text(appText(.noImageAvailable, languageIndex: languageIndex))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundColor(.secondary)
                } else {
                    // Try to decode existing base64 data
                    if let data = Data(base64Encoded: camera.standOrt64) {
                        Image(uiImage: UIImage(data: data)!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(minHeight: 200)
                    } else {
                        Text(appText(.imageLoadingFailed, languageIndex: languageIndex))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Text(camera.CameraName)
                            .font(.title)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading).tint(Color.primary).fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Text(camera.CameraRealName)
                        .lineLimit(5).font(.headline).foregroundStyle(Color.green)
                    
                    Text(camera.CameraType)
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
        if !camera.standOrt64.isEmpty,
           let data = Data(base64Encoded: camera.standOrt64) {
            imageData = data
        } else if camera.standOrt64.isEmpty {
            // If no base64 data but the model has an empty image, download from API
            isLoading = true
            /*Task {
                await fetchDataAndRefresh()
                isLoading = false
            }*/
        }
    }
    
    
}

#Preview {
    CardView(wildsichtung: Wildsichtung(id: 1, title: "titel", cameraid: "cameraid", subtitle: "subtitle", body: "body", immichid: "immichid", yolostatus: "status", imagebase64: "", creationDate: Date(), pinned: false), isPinned: true)
}
