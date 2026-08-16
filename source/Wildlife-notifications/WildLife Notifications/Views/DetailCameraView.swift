// Edited by FBronski
// 20.07.2026

import PhotosUI
import SwiftUI


struct DetailCameraView: View {
    
    @Environment(\.dismiss) private var dismiss
  
    @State var camera: WildsichtungCamera
    var onSave: (() -> Void)? = nil
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showSaveError = false
    @State private var showDeleteConfirmation = false
    @State private var isLoadingImage = false
    @AppStorage("languageIndex") private var languageIndex = 0
   
    let fileManager = FileManager.default
    
   
    var body: some View {

            VStack {
                cameraImageSection
               
                
                ScrollView {
                    
                    HStack {
                        VStack(alignment: .leading) {
                            
                            TextField(appText(.cameraLocation, languageIndex: languageIndex), text: $camera.CameraRealName)
                                .font(.title)
                                .textFieldStyle(.roundedBorder)
                                .padding()
                            
                            TextField(appText(.cameraName, languageIndex: languageIndex), text: $camera.CameraName)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                                .onChange(of: camera.CameraName) { _, newValue in
                                    if newValue.count > 4 {
                                        camera.CameraName = String(newValue.prefix(4))
                                    }
                                }
                            
                            TextField(appText(.cameraType, languageIndex: languageIndex), text: $camera.CameraType)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            Text(camera.creationDate.formattedString(dateFormat: "yyyy-MM-dd’T’HH:mm:ss"))
                                .foregroundColor(.secondary)
                                .padding()
                            
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label(appText(.cameraDelete, languageIndex: languageIndex), systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal)
                            .padding(.top, 12)
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward.circle.fill")
                            .tint(.black)
                    }
                    .font(.title)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appText(.save, languageIndex: languageIndex)) {
                        saveCamera()
                    }
                }
                
            }
            .alert(appText(.cameraSaveFailed, languageIndex: languageIndex), isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog(appText(.cameraDeleteQuestion, languageIndex: languageIndex), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button(appText(.cameraDelete, languageIndex: languageIndex), role: .destructive) {
                    deleteCamera()
                }
                Button(appText(.cancel, languageIndex: languageIndex), role: .cancel) {}
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    await loadPhoto(from: newValue)
                }
            }
            .refreshable {
                
            }
            .onAppear {
                
 
            }
            .onDisappear {
                
            }
    }
    
    private var cameraImageSection: some View {
        let selectedImage = cameraImage
        let pickerTitle = selectedImage == nil ? appText(.selectPhoto, languageIndex: languageIndex) : appText(.changePhoto, languageIndex: languageIndex)
        
        return VStack(spacing: 12) {
            if let uiImage = selectedImage {
                ZoomImageView(image: uiImage)
                    .maximumZoomScale(5.0)
                    .minimumZoomScale(0.5)
                    .showsHorizontalScrollIndicator(true)
                    .alwaysBounceVertical(true)
                    .doubleTapZoomScale(2.0)
                    .frame(minHeight: 240)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(appText(.noPhoto, languageIndex: languageIndex))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(Color(.secondarySystemGroupedBackground))
            }
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(pickerTitle, systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoadingImage)
            
            if isLoadingImage {
                ProgressView(appText(.imageLoading, languageIndex: languageIndex))
            }
        }
        .padding()
    }
    
    private var cameraImage: UIImage? {
        guard !camera.standOrt64.isEmpty,
              let data = Data(base64Encoded: camera.standOrt64) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    private func loadPhoto(from item: PhotosPickerItem) async {
        isLoadingImage = true
        defer { isLoadingImage = false }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let imageData = UIImage(data: data)?.jpegData(compressionQuality: 0.85) ?? data
            camera.standOrt64 = imageData.base64EncodedString()
        } catch {
            showSaveError = true
        }
    }
    
    private func saveCamera() {
        let didSave = DatabaseManager.shared.updateCamera(
            id: camera.id,
            CameraName: camera.CameraName,
            CameraRealName: camera.CameraRealName,
            CameraType: camera.CameraType,
            standOrt64: camera.standOrt64
        )
        
        if didSave {
            onSave?()
            dismiss()
        } else {
            showSaveError = true
        }
    }
    
    private func deleteCamera() {
        DatabaseManager.shared.deleteCamera(cameraId: camera.id)
        onSave?()
        dismiss()
    }
    
    // Async function simulating a network request
   
}

#Preview {
    
    NavigationStack {
        /*DetailView(wildsichtung: Wildsichtung(id: 1, title: "titel", subtitle: "subtitle", body: "body", immichid: "immichid", yolostatus: "status", imagebase64: "base64", creationDate: Date()))*/
    }
}
