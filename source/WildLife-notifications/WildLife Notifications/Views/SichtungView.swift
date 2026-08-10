// Edited by FBronski
// 20.07.2026

import SwiftUI

enum ActiveAlert {
    case first, second
}

struct SichtungView: View {
   
    @State var viewModel: RootViewModel
    
    let fileManager = FileManager.default
    @State var showAlert: Bool = false
    @State private var activeAlert: ActiveAlert = .first
    @State var timeRange: Range<TimeInterval> = 28800..<36000 // 08:00 - 10:00
    @State private var showTimeSheet = false
    @State private var isCanceled = false
    @Environment(\.timePickerStyle) private var style
    @State private var searchText = ""
    
    // Add automatic refresh timer
    @State private var refreshTimer: Task<Void, Never>? = nil
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                List {
                    ForEach(searchResults) { ws in
                        @State var item = ws
                        ZStack {
                            CardView(wildsichtung: ws, isPinned: ws.pinned).contextMenu {
                                Button {
                                    Task {
                                        
                                        await updateItem(item)
                                        
                                    }
                                } label: {
                                    Label("Update", systemImage: "arrow.trianglehead.clockwise.rotate.90")
                                }
                                .tint(.orange)
                                
                                Button {
                                    
                                         deleteItem(item)
   	        		 	     	   
  	  	     	     	  	    
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                                
                                /*Button {
                                    Task {
                                        
                                        await deleteImage(item)
                                        await deleteItem(item)
                                        
                                    }
                                } label: {
                                    Label("Delete image", systemImage: "arrow.up.trash")
                                }
                                .tint(.red)*/
   	         	 	     
      	    	        
                                if item.pinned {
                                    Button {
                                        pinItem(item)
                                    } label: {
                                        Label("UnPin", systemImage: "pin.slash")
                                    }
                                    .tint(.red)
                                } else {
                                    Button {
                                        pinItem(item)
                                    } label: {
                                        Label("Pin", systemImage: "pin")
                                    }
                                    .tint(.blue)
                                }
                                
                                Divider()
                                
                                Button {
                                    Task { await sendPlotCMDPerFTP(item) }
                                } label: {
                                    Label("Get Plotted", systemImage: "photo.artframe.circle")
                                }
                                .tint(.cyan)
                                if !item.imagebase64.isEmpty {
                                    
                                    let data = Data(base64Encoded: item.imagebase64)
                                    if(data != nil) {
                                        let uiImage = UIImage(data: data!)
                                        let shareImage = Image(uiImage: uiImage!)
                                        ShareLink(item: shareImage, preview: SharePreview("Wildsichtung", image: shareImage)) {
                                            Label("Share Photo", systemImage: "square.and.arrow.up")
                                        }.tint(.purple)
                                    }
                                }
                                
                            }
                            NavigationLink(destination: DetailView(wildsichtung: item)) {
                                
                                EmptyView()
                                
                            }
                            .opacity(0)
                        }/*.swipeActions(edge: .leading) {
                            Button {
                                Task {
                                    
                                    await updateItem(item)
                                    
                                }
                            } label: {
                                Label("Update", systemImage: "arrow.trianglehead.clockwise.rotate.90")
                            }
                            .tint(.orange)
                        }*/.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    
                }
                .navigationTitle("Wildsichtungen")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu("...") {
                            Button("Refresh View", systemImage: "arrow.trianglehead.clockwise.rotate.90", action: { print("Refreh selected")
                                
                                Task {
                                    isRefreshing = true
                                    viewModel.sichtungen = DatabaseManager.shared.getAllSichtungen()
                                    isRefreshing = false
                                }
                                
                            })
                            Button("Update All", systemImage: "arrow.trianglehead.2.clockwise.rotate.90", action: { print("Update All without Image")
                                
                                Task {
                                    isRefreshing = true
                                    viewModel.sichtungen = DatabaseManager.shared.getAllSichtungen()
                                    await updateAll()
                                    isRefreshing = false
                                }
                                
                            })
                            Button("Unpinned löschen",systemImage: "arrow.up.trash", action: { print("Unpinned löschen")
   	         	 	     
      	    	        
                                DatabaseManager.shared.deleteAllUnPinned()
                                
                                Task {
                                    isRefreshing = true
                                    await viewModel.fetchSichtungen()
                                    isRefreshing = false
                                }
                                
                            })
                           
                            Button("Lösche bis \(viewModel.draftDuration.timeString)",systemImage: "timeline.selection", action: { print("Immich löschen")
   	         	 	     
  	     	 	     
                                showTimeSheet.toggle()
   	   	  	    	 
      	    	   	     
                               })
                            Button("DB Löschen",systemImage: "document.on.trash", action: { print("Datenbank löschen")
                                
                                if(DatabaseManager.shared.IsAnyNotifyPinned()) {
                                    self.activeAlert = .first
                                    showAlert = true
                                }else{
                                    showAlert = false
                                    DatabaseManager.shared.deleteAndCreateNew()
                                }
   	   	      	    	 
      	    	   	     
                                Task {
                                    isRefreshing = true
                                    await viewModel.fetchSichtungen()
                                    isRefreshing = false
                                }
                                
                            })
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    Task {
                        isRefreshing = true
                        await viewModel.fetchSichtungen()
                        isRefreshing = false
                    }
                }.sheet(isPresented: $showTimeSheet,
                        onDismiss: {
                    self.activeAlert = .second
                    if(isCanceled == true){
                        
                        showAlert = false
                    }else{
                        
                        showAlert = true
                    }
                   
                    print("Modal dismissed. State now: \($viewModel.draftDuration)")
                  },
                  // 5
                  content: {
                    /*TimePickerSheet(
                      draftDuration: $viewModel.draftDuration,
                      value: $viewModel.duration,
                      isPresenting: $showTimeSheet,
                      isCanceled: $isCanceled,
                      title: "Lösche Bilder ab",
                      components: TimePickerComponents.hoursMinutesSeconds,
                      maximumHours: 23,
                      
                    )
                    .timePickerStyle(style)*/
                    TimeRangePicker($timeRange,isPresenting: $showTimeSheet, isCanceled: $isCanceled)
                  }).alert(isPresented: $showAlert, content: {
                    switch activeAlert {
                    case .first:
                        Alert(title: Text("Achtung Pinned Notify"),
                              message: Text("Es gibt Nachrichten die angehefted sind. Wenn sie löschen gehen diese verloren. Möchten Sie die Datenbank wirklich löschen?"),
                              primaryButton: Alert.Button.default(Text("Aktzeptiere"), action: {
                            DatabaseManager.shared.deleteAndCreateNew()
                            print("Datenbank trotzdem löschen")
                        }),
                              secondaryButton: .destructive(Text("Abbruch"))
                        )
                    case .second:
                        Alert(title: Text("Achtung Löschen von Bildern"),
                              message: Text("Möchten Sie alle Immich Bilder von  \(viewModel.draftDuration.timeString) von Immich in den Papierkorb schieben"),
                              primaryButton: Alert.Button.default(Text("Aktzeptiere"), action: {
                            
                            print("Bilder trotzdem löschen")
                        }),
                              secondaryButton: .destructive(Text("Abbruch"))
                        )
                        
                    }
                })
                
            } else {
                // Fallback on earlier versions
            }
                   
        }.searchable(text: $searchText)
        .onAppear {
            // Start automatic refresh when view appears
            startAutoRefresh()
            UNUserNotificationCenter.current().setBadgeCount(0)
           
        }.onDisappear {
            // Stop timer when view disappears
            stopAutoRefresh()
        }
    }
    
    // Add this function to start automatic refreshing
    private func startAutoRefresh() {
        // Stop any existing timer
        stopAutoRefresh()
        
        // Create new timer that refreshes every 30 seconds (adjust as needed)
        refreshTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30)) // Refresh every 30 seconds
                
                if !isRefreshing {
                    Task {
                        await viewModel.fetchSichtungen()
                    }
                }
            }
        }
    }
    
    // Add this function to stop automatic refreshing
    private func stopAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }
    
    var searchResults: [Wildsichtung] {
            if searchText.isEmpty {
                return viewModel.sichtungen
            } else {
                return viewModel.sichtungen.filter { $0.title.contains(searchText) || $0.yolostatus.contains(searchText) || $0.body.contains(searchText)} 
            }
        }
    
    func updateAll() async {
       for item in viewModel.sichtungen  {
           await updateItem(item)
        }
        
        Task { await viewModel.fetchSichtungen() }
    }
    
    func deleteItem(_ item: Wildsichtung) {
        DatabaseManager.shared.deleteSichtung(sichtungId: item.id)
       viewModel.sichtungen.removeAll(where: { $0.id == item.id })
        Task { await viewModel.fetchSichtungen() }
    }
    
    
    func sendPlotCMDPerFTP(_ item: Wildsichtung) async {
   	
   	  	
        let dateFormatter = DateFormatter()

        // Set Date Format
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        let dstr = dateFormatter.string(from: Date.now)
        let secs = Date.now.timeIntervalSince1970
   	
        let filename = "\(item.cameraid)_CMD_\(secs).txt" //this is the file. we will write to and read from it
        let replaced = item.body.replacingOccurrences(of: "Neue Sichtung ", with: "")
        let cm = CommandModel(id: UUID().uuidString, cmd: "GetPLOT", text: replaced, immichid: item.immichid, creationDate: Date.now.formattedString(dateFormat: "yyyy-MM-dd’T’HH:mm:ss"))
        let cmdText = cm.getJsonStringAsBase64()
        //let cmdText = "CMD:GetPLOT\r\nIMMICHID:\(item.immichid)\r\nDate:\(dstr)\r\n"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

            let fileURL = dir.appendingPathComponent(filename)

            //writing
            do {
                //try cmdText.write(to: fileURL, atomically: false, encoding: .utf8)
   	

                let credentials = FTPCredentials(host: UserDefaults.standard.string(forKey: "ftpIP")!, port: UInt16(UserDefaults.standard.string(forKey: "ftpPort")!)!, username: UserDefaults.standard.string(forKey: "ftpUser")!, password: UserDefaults.standard.string(forKey: "ftpPassword")!)
                let remotePath = ""
                let ftpClient = await FTPClient(credentials: credentials, remotePath: remotePath)
                let filesToUpload: [FTPUploadable] = [
                    //.file(url: fileURL, remoteFileName: filename),
                    .data(data: Data(cmdText.utf8), remoteFileName: filename)
                ]
                
                
                try await ftpClient.upload(files: filesToUpload) { progress in
                        print("Overall progress: \(progress.fractionCompleted * 100)%")
                    }
                    print("All files uploaded successfully.")
            }
            catch {
                    print("Error writing file \(error)")
            }

           
        }
    }
    
    func pinItem(_ item: Wildsichtung) {
        if(item.pinned) {
            DatabaseManager.shared.updatePinned(iid: item.immichid, pinned: false)
        }else{
            DatabaseManager.shared.updatePinned(iid: item.immichid, pinned: true)
        }
       print("pinned")
        
        Task { await viewModel.fetchSichtungen() }
    }
    
    func updateItem(_ item: Wildsichtung) async {
       
        do {
           
            let client = OpenAPIClientAPIConfiguration.shared
            client.basePath = UserDefaults.standard.string(forKey: "immichurltext")!+"/api"
            client.customHeaders = ["x-api-key":UserDefaults.standard.string(forKey: "immichapikey")!,"Accept":"application/octet-stream"]
   	   	  
   	 	    
            let version = try await ServerAPI.getVersionHistory(apiConfiguration: client)
            print("Immich Version: \(version)")
            
            
            let response =  try await AssetsAPI.downloadAsset(id: item.immichid, key: nil, apiConfiguration: client)
            
            let cachepath = response.path()
            let url = URL(fileURLWithPath: cachepath)

          
            let data = try Data(contentsOf: url)
            
            let dt = Data(data)
            let ab = (dt.base64EncodedString())
            let result = DatabaseManager.shared.updateImage(iid: item.immichid, imagebase64: ab)
   	   	  
   	 	    
            try fileManager.removeItem(at: url)
            Task { await viewModel.fetchSichtungen() }
          
        } catch{
            print("Get Image Date Error:\(error)")
        }
   
 	     
 	   	  
        withAnimation {
            
        }
        print("\(item) update")
    }

    func deleteImage(_ item: Wildsichtung) async {
       
        do {
           
            let client = OpenAPIClientAPIConfiguration.shared
            client.basePath = "https://immich/api"
            client.customHeaders = ["x-api-key":UserDefaults.standard.string(forKey: "immichapikey")!,"Accept":"application/octet-stream"]
   	   	  
   	 	    
            let version = try await ServerAPI.getVersionHistory(apiConfiguration: client)
            print("Immich Version: \(version)")
            
            var uuids: [String] = []
            uuids.append(item.immichid)
            let assetBulkDeleteDto = AssetBulkDeleteDto(force: false, ids: uuids)
            let response =  try await AssetsAPI.deleteAssetsWithRequestBuilder(assetBulkDeleteDto: assetBulkDeleteDto, apiConfiguration: client)
            //downloadAsset(id: item.immichid, key: nil, apiConfiguration: client)
            
            print(response)
          
        } catch{
            print("Delete Image Date Error:\(error)")
        }
   
 	     
 	   	  
        withAnimation {
            
        }
        print("\(item) update")
    }
    // Async function simulating a network request
       func fetchNewData() {
          
           withAnimation {
               viewModel.sichtungen = DatabaseManager.shared.getAllSichtungen()
           }
       }
}


#Preview {
    //SichtungView(viewModel: RootViewModel() )
}

struct SheetView: View {
   @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
           Button {
              dismiss()
           } label: {
               Image(systemName: "xmark.circle")
                 .font(.largeTitle)
                 .foregroundColor(.gray)
           }
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
         .padding()
    }
}

extension Date {
    func formattedString(dateFormat: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        return dateFormatter.string(from: self)
    }
}
