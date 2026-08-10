// Edited by FBronski
// 20.07.2026

import SwiftUI


struct DetailView: View {
    
    @Environment(\.dismiss) private var dismiss
  
    @State var wildsichtung: Wildsichtung
   
    let fileManager = FileManager.default
    
   
    var body: some View {

            VStack {
                
                if let data = Data(base64Encoded: wildsichtung.imagebase64), let uiImage = UIImage(data: data) {
                    /*Image(uiImage: uiImage) .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(totalMagnification * currentMagnification)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    currentMagnification = value.magnification
                                }
                                .onEnded { value in
                                    totalMagnification *= value.magnification
                                    currentMagnification = 1.0
                                }
                        )*/
                    ZoomImageView(image: uiImage)
                                    .maximumZoomScale(5.0)
                                    .minimumZoomScale(0.5)
                                    .showsHorizontalScrollIndicator(true)
                                    .alwaysBounceVertical(true)
                                    .doubleTapZoomScale(2.0)
                                    //.frame(width: 300, height: 200)
                                    //.border(Color.gray) // Optional to see the component's bounds
                        

                } else {
                    let _ = print("Detailview no Image")
                   
                   
                }
               
                
                ScrollView {
                    
                    HStack {
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
    
    // Async function simulating a network request
    func getImageData() async {
           
           do {
              
               let client = OpenAPIClientAPIConfiguration.shared
               client.basePath = UserDefaults.standard.string(forKey: "immichurltext")!+"/api"
               client.customHeaders = ["x-api-key":UserDefaults.standard.string(forKey: "immichapikey")!,"Accept":"application/octet-stream"]
            
               
               
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
