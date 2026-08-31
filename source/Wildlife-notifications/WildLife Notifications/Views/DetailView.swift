// Edited by FBronski
// 20.07.2026

import SwiftUI
import UIKit


struct DetailView: View {
    
    @Environment(\.dismiss) private var dismiss
  
    @State var wildsichtung: Wildsichtung
   
    let fileManager = FileManager.default
    
   
    var body: some View {
        Group {
            if isPad {
                iPadLayout
            } else {
                phoneLayout
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
        }
        .refreshable {
            await getImageData()
        }
        .onAppear {
            if(wildsichtung.imagebase64.isEmpty) {
                Task {
                    await getImageData()
                }
            }
        }
        .onDisappear {

        }
    }

    private var phoneLayout: some View {
        VStack {
            imageSection
            detailContent
        }
    }

    private var iPadLayout: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                HStack(alignment: .top, spacing: 24) {
                    imageSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    detailContent
                        .frame(width: detailPanelWidth(for: geometry.size.width))
                        .frame(maxHeight: .infinity)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(24)
            } else {
                VStack(spacing: 16) {
                    imageSection
                        .frame(height: portraitImageHeight(for: geometry.size.height))
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    detailContent
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var imageSection: some View {
        if let data = Data(base64Encoded: wildsichtung.imagebase64), let uiImage = UIImage(data: data) {
            ZoomImageView(image: uiImage)
                .maximumZoomScale(5.0)
                .minimumZoomScale(0.5)
                .showsHorizontalScrollIndicator(true)
                .alwaysBounceVertical(true)
                .doubleTapZoomScale(2.0)
        } else {
            Color.clear
                .onAppear {
                    print("Detailview no Image")
                }
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(wildsichtung.title)
                    .font(.title)
                    .padding()

                Text(wildsichtung.yolostatus)
                    .padding()

                Text(wildsichtung.body)
                    .padding()

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailPanelWidth(for width: CGFloat) -> CGFloat {
        min(420, max(320, width * 0.36))
    }

    private func portraitImageHeight(for height: CGFloat) -> CGFloat {
        min(max(height * 0.58, 360), 620)
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // Async function simulating a network request
    func getImageData() async {
           
           do {
              
               let client = try ImmichAPIConfiguration.current()
            
               
               
               let version = try await ServerAPI.getVersionHistory(apiConfiguration: client)
               print("Immich Version: \(version)")
               
               
               let response =  try await AssetsAPI.downloadAsset(id: wildsichtung.immichid, key: nil, apiConfiguration: client)
               
               let cachepath = response.path()
               let url = URL(fileURLWithPath: cachepath)

             
               let data = try Data(contentsOf: url)
               
               let dt = Data(data)
               let ab = (dt.base64EncodedString())
               let result = DatabaseManager.shared.updateImage(iid: wildsichtung.immichid, imagebase64: ab)
               
               if(result == true){
                   wildsichtung.imagebase64 = ab
               }
               
               try fileManager.removeItem(at: url)
             
           } catch{
               print("Get Image Date Error:\(error)")
           }
         
           
          
          
           withAnimation {
               
           }
       }
}

#Preview {
    
    NavigationStack {
        /*DetailView(wildsichtung: Wildsichtung(id: 1, title: "titel", subtitle: "subtitle", body: "body", immichid: "immichid", yolostatus: "status", imagebase64: "base64", creationDate: Date()))*/
    }
}
