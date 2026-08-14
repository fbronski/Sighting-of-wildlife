// Edited by FBronski
// 20.07.2026

import SwiftUI

enum ActiveAlert {
    case first, second, third
}

private enum DateDeletionMode: String, CaseIterable, Identifiable {
    case day = "Tag"
    case month = "Monat"
    case year = "Jahr"
    case range = "Datumsbereich"

    var id: String { rawValue }
}

private struct SichtungDateMarker: Equatable {
    let id: Int64
    let frame: CGRect
    let date: Date
}

private struct SichtungDateMarkerPreferenceKey: PreferenceKey {
    static let defaultValue: [SichtungDateMarker] = []

    static func reduce(value: inout [SichtungDateMarker], nextValue: () -> [SichtungDateMarker]) {
        value.append(contentsOf: nextValue())
    }
}

struct SichtungView: View {
   
    @State var viewModel: RootViewModel
    
    let fileManager = FileManager.default
    @State var showAlert: Bool = false
    @State private var activeAlert: ActiveAlert = .first
    @State var timeRange: Range<TimeInterval> = 28800..<36000 // 08:00 - 10:00
    @State private var showTimeSheet = false
    @State private var showDateDeleteSheet = false
    @State private var isCanceled = false
    @State private var deleteDateMode: DateDeletionMode = .day
    @State private var deleteReferenceDate = Date()
    @State private var deleteRangeStartDate: Date? = Date()
    @State private var deleteRangeEndDate: Date? = Date()
    @State private var pendingDateDeletionRange: Range<Date>?
    @State private var shouldConfirmDateDeletion = false
    @Environment(\.timePickerStyle) private var style
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    
    // Add automatic refresh timer
    @State private var refreshTimer: Task<Void, Never>? = nil
    @State private var isRefreshing = false
    @State private var dateMarkers: [SichtungDateMarker] = []
    @State private var dateBadgeLocation: CGPoint?
    @State private var dateBadgeText = ""
    @State private var showScrollToTopButton = false
    
    private static let scrollDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return formatter
    }()

    private static let deletionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return formatter
    }()
    
    private let topListID = "SichtungListTop"
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                ScrollViewReader { scrollProxy in
                List {
                    Color.clear
                        .frame(height: 0)
                        .id(topListID)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())

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
                        }
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: SichtungDateMarkerPreferenceKey.self,
                                    value: [
                                        SichtungDateMarker(
                                            id: ws.id,
                                            frame: proxy.frame(in: .named("SichtungScroll")),
                                            date: ws.creationDate
                                        )
                                    ]
                                )
                            }
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
                            Button("Zum Anfang", systemImage: "arrow.up.to.line") {
                                scrollToTop(using: scrollProxy)
                            }
                            
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
                            Button("Lösche Datum...", systemImage: "calendar.badge.minus") {
                                showDateDeleteSheet = true
                            }
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
                .coordinateSpace(name: "SichtungScroll")
                .onPreferenceChange(SichtungDateMarkerPreferenceKey.self) { markers in
                    updateListPositionState(with: markers)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .named("SichtungScroll"))
                        .onChanged { value in
                            updateDateBadge(at: value.location)
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.15)) {
                                dateBadgeLocation = nil
                            }
                        }
                )
                .overlay(alignment: .topLeading) {
                    if let dateBadgeLocation {
                        SichtungDateBadge(text: dateBadgeText)
                            .position(x: dateBadgeX(for: dateBadgeLocation.x), y: dateBadgeLocation.y)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if showScrollToTopButton {
                        Button {
                            scrollToTop(using: scrollProxy)
                        } label: {
                            Image(systemName: "arrow.up.to.line")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(.black.opacity(0.48), in: Circle())
                                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 18)
                        .padding(.bottom, 28)
                        .accessibilityLabel("Zum Anfang der Liste")
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
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
                  })
                .sheet(isPresented: $showDateDeleteSheet, onDismiss: {
                    presentPendingDateDeletionAlert()
                }, content: {
                    DateDeletionSelectionSheet(
                        mode: $deleteDateMode,
                        referenceDate: $deleteReferenceDate,
                        rangeStartDate: $deleteRangeStartDate,
                        rangeEndDate: $deleteRangeEndDate,
                        availableYears: availableDeletionYears,
                        onContinue: {
                            prepareDateDeletionConfirmation()
                        },
                        onCancel: {
                            shouldConfirmDateDeletion = false
                            pendingDateDeletionRange = nil
                            showDateDeleteSheet = false
                        }
                    )
                })
                .alert(isPresented: $showAlert, content: {
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
                        Alert(title: Text("Achtung Löschen von Immich Bildern"),
                              message: Text(deleteImagesConfirmationMessage),
                              primaryButton: Alert.Button.destructive(Text("In Papierkorb"), action: {
                            Task {
                                await deleteImagesInSelectedTimeRange()
                            }
                        }),
                              secondaryButton: .cancel(Text("Abbruch"))
                        )
                    case .third:
                        Alert(title: Text("Achtung Löschen von Immich Bildern"),
                              message: Text(dateDeletionConfirmationMessage),
                              primaryButton: Alert.Button.destructive(Text("In Papierkorb"), action: {
                            Task {
                                await deleteImagesInPendingDateRange()
                            }
                        }),
                              secondaryButton: .cancel(Text("Abbruch"))
                        )
                    }
                })
                }
                
            } else {
                // Fallback on earlier versions
            }
                   
        }.searchable(text: $searchText)
        .onAppear {
            // Start automatic refresh when view appears
            startAutoRefresh()
            clearAppIconBadge()
           
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                clearAppIconBadge()
            }
        }
        .onDisappear {
            // Stop timer when view disappears
            stopAutoRefresh()
        }
    }
    
    private func clearAppIconBadge() {
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                print("Error clearing the badge count: \(error)")
            }
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

    private var availableDeletionYears: [Int] {
        let years = Set(viewModel.sichtungen.map { Calendar.current.component(.year, from: $0.creationDate) })
        if years.isEmpty {
            return [Calendar.current.component(.year, from: Date())]
        }

        return years.sorted(by: >)
    }
    
    private var deleteImagesConfirmationMessage: String {
        let matchingCount = sichtungenInSelectedTimeRange.count
        return "Möchten Sie \(matchingCount) Immich Bilder im Zeitraum \(formattedSelectedTimeRange) in den Papierkorb schieben und aus der lokalen Datenbank entfernen? Die Bilder bleiben in Immich noch 30 Tage im Papierkorb."
    }

    private var dateDeletionConfirmationMessage: String {
        let matchingCount = sichtungenInPendingDateDeletionRange.count
        return "Möchten Sie \(matchingCount) Immich Bilder im Zeitraum \(formattedPendingDateDeletionRange) in den Papierkorb schieben und aus der lokalen Datenbank entfernen? Die Bilder bleiben in Immich noch 30 Tage im Papierkorb."
    }

    private var formattedSelectedTimeRange: String {
        "\(formattedTime(timeRange.lowerBound)) - \(formattedTime(timeRange.upperBound))"
    }

    private var formattedPendingDateDeletionRange: String {
        guard let range = pendingDateDeletionRange else {
            return "-"
        }

        return formattedDateRange(range)
    }

    private var selectedDateDeletionRange: Range<Date>? {
        let calendar = Calendar.current

        switch deleteDateMode {
        case .day:
            let start = calendar.startOfDay(for: deleteReferenceDate)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            return start..<end
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: deleteReferenceDate) else { return nil }
            return interval.start..<interval.end
        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: deleteReferenceDate) else { return nil }
            return interval.start..<interval.end
        case .range:
            guard let firstDate = deleteRangeStartDate ?? deleteRangeEndDate else { return nil }
            let secondDate = deleteRangeEndDate ?? firstDate
            let start = calendar.startOfDay(for: min(firstDate, secondDate))
            let lastDay = calendar.startOfDay(for: max(firstDate, secondDate))
            guard let end = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return nil }
            return start..<end
        }
    }

    private var sichtungenInSelectedTimeRange: [Wildsichtung] {
        viewModel.sichtungen.filter { sichtung in
            !sichtung.immichid.isEmpty && isDate(sichtung.creationDate, inTimeRange: timeRange)
        }
    }

    private var sichtungenInPendingDateDeletionRange: [Wildsichtung] {
        guard let range = pendingDateDeletionRange else {
            return []
        }

        return viewModel.sichtungen.filter { sichtung in
            !sichtung.immichid.isEmpty && range.contains(sichtung.creationDate)
        }
    }
    
    private func updateListPositionState(with markers: [SichtungDateMarker]) {
        dateMarkers = markers
        guard let firstID = searchResults.first?.id, !markers.isEmpty else {
            setScrollToTopButtonVisible(false)
            return
        }

        guard let firstMarker = markers.first(where: { $0.id == firstID }) else {
            setScrollToTopButtonVisible(true)
            return
        }

        setScrollToTopButtonVisible(firstMarker.frame.minY < -80)
    }

    private func setScrollToTopButtonVisible(_ isVisible: Bool) {
        guard showScrollToTopButton != isVisible else {
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            showScrollToTopButton = isVisible
        }
    }
    
    private func updateDateBadge(at location: CGPoint) {
        guard let marker = nearestDateMarker(to: location) else {
            return
        }

        dateBadgeText = Self.scrollDateFormatter.string(from: marker.date)
        withAnimation(.easeOut(duration: 0.08)) {
            dateBadgeLocation = location
        }
    }

    private func nearestDateMarker(to location: CGPoint) -> SichtungDateMarker? {
        let visibleMarkers = dateMarkers.filter { $0.frame.maxY >= 0 }
        return visibleMarkers.min { first, second in
            let firstDistance = abs(first.frame.midY - location.y)
            let secondDistance = abs(second.frame.midY - location.y)
            return firstDistance < secondDistance
        }
    }

    private func dateBadgeX(for touchX: CGFloat) -> CGFloat {
        touchX > 220 ? touchX - 112 : touchX + 112
    }
    
    private func scrollToTop(using proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(topListID, anchor: .top)
            showScrollToTopButton = false
        }
    }

    private func prepareDateDeletionConfirmation() {
        guard let range = selectedDateDeletionRange else {
            shouldConfirmDateDeletion = false
            pendingDateDeletionRange = nil
            showDateDeleteSheet = false
            return
        }

        pendingDateDeletionRange = range
        shouldConfirmDateDeletion = true
        showDateDeleteSheet = false
    }

    private func presentPendingDateDeletionAlert() {
        guard shouldConfirmDateDeletion else {
            return
        }

        shouldConfirmDateDeletion = false
        activeAlert = .third
        showAlert = true
    }

    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let normalizedTime = normalizedSecondsInDay(timeInterval)
        let hours = Int(normalizedTime) / 3600
        let minutes = (Int(normalizedTime) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func formattedDateRange(_ range: Range<Date>) -> String {
        let end = range.upperBound.addingTimeInterval(-1)
        return "\(Self.deletionDateFormatter.string(from: range.lowerBound)) - \(Self.deletionDateFormatter.string(from: end))"
    }

    private func isDate(_ date: Date, inTimeRange range: Range<TimeInterval>) -> Bool {
        let seconds = secondsSinceStartOfDay(for: date)
        let start = normalizedSecondsInDay(range.lowerBound)
        let end = normalizedSecondsInDay(range.upperBound)

        if start <= end {
            return seconds >= start && seconds < end
        } else {
            return seconds >= start || seconds < end
        }
    }

    private func secondsSinceStartOfDay(for date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0
        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    private func normalizedSecondsInDay(_ timeInterval: TimeInterval) -> TimeInterval {
        let secondsInDay: TimeInterval = 24 * 3600
        let normalized = timeInterval.truncatingRemainder(dividingBy: secondsInDay)
        return normalized >= 0 ? normalized : normalized + secondsInDay
    }

    private func deleteImagesInSelectedTimeRange() async {
        await deleteSichtungenFromImmichAndDatabase(sichtungenInSelectedTimeRange, context: "Uhrzeitbereich")
    }

    private func deleteImagesInPendingDateRange() async {
        await deleteSichtungenFromImmichAndDatabase(sichtungenInPendingDateDeletionRange, context: "Datumsbereich")
        pendingDateDeletionRange = nil
    }

    private func deleteSichtungenFromImmichAndDatabase(_ matchingSichtungen: [Wildsichtung], context: String) async {
        let assetIDs = Array(Set(matchingSichtungen.map(\.immichid)))
        guard !assetIDs.isEmpty else {
            print("Keine Immich Bilder im ausgewählten \(context) gefunden.")
            return
        }

        do {
            let client = OpenAPIClientAPIConfiguration.shared
            client.basePath = UserDefaults.standard.string(forKey: "immichurltext")! + "/api"
            client.customHeaders = [
                "x-api-key": UserDefaults.standard.string(forKey: "immichapikey")!,
                "Accept": "application/octet-stream"
            ]

            let deleteDto = AssetBulkDeleteDto(force: false, ids: assetIDs)
            try await AssetsAPI.deleteAssets(assetBulkDeleteDto: deleteDto, apiConfiguration: client)

            let deletedSichtungIDs = Set(matchingSichtungen.map(\.id))
            for sichtung in matchingSichtungen {
                DatabaseManager.shared.deleteSichtung(sichtungId: sichtung.id)
            }
            viewModel.sichtungen.removeAll { deletedSichtungIDs.contains($0.id) }
            print("\(assetIDs.count) Immich Bilder in den Papierkorb verschoben und \(matchingSichtungen.count) lokale Sichtungen gelöscht.")
        } catch {
            print("Delete images by \(context) error: \(error)")
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
   	

                let ftpHost = UserDefaults.standard.string(forKey: "ftpIP")!
                let ftpPort = UInt16(UserDefaults.standard.string(forKey: "ftpPort")!)!
                let normalizedFTPHost = ftpHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let ftpSecurityIndex = UserDefaults.standard.integer(forKey: "ftpSecurityIndex")
                let ftpSecurity: FTPConnectionSecurity = ftpSecurityIndex == 1 ? .explicitTLS : .none
                let allowsUntrustedCertificate = ftpSecurity == .explicitTLS && normalizedFTPHost == "upload.wildbild.cloud"
                let credentials = FTPCredentials(
                    host: ftpHost,
                    port: ftpPort,
                    username: UserDefaults.standard.string(forKey: "ftpUser")!,
                    password: UserDefaults.standard.string(forKey: "ftpPassword")!,
                    security: ftpSecurity,
                    allowsUntrustedTLSCertificate: allowsUntrustedCertificate
                )
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

private struct SichtungDateBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar.badge.clock")
                .imageScale(.small)
            Text(text)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.78), in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)
    }
}

private struct DateDeletionSelectionSheet: View {
    @Binding var mode: DateDeletionMode
    @Binding var referenceDate: Date
    @Binding var rangeStartDate: Date?
    @Binding var rangeEndDate: Date?
    let availableYears: [Int]
    let onContinue: () -> Void
    let onCancel: () -> Void

    private static let rangeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private var selectedMonth: Binding<Int> {
        Binding {
            Calendar.current.component(.month, from: referenceDate)
        } set: { month in
            updateReferenceDate(month: month)
        }
    }

    private var selectedYear: Binding<Int> {
        Binding {
            Calendar.current.component(.year, from: referenceDate)
        } set: { year in
            updateReferenceDate(year: year)
        }
    }

    private var rangeSummary: String {
        guard let start = rangeStartDate ?? rangeEndDate else {
            return "Kein Datumsbereich gewählt"
        }

        let end = rangeEndDate ?? start
        let first = min(start, end)
        let last = max(start, end)
        return "\(Self.rangeDateFormatter.string(from: first)) - \(Self.rangeDateFormatter.string(from: last))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Zeitraum", selection: $mode) {
                        ForEach(DateDeletionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    switch mode {
                    case .day:
                        DatePicker("Tag", selection: $referenceDate, displayedComponents: .date)
                    case .month:
                        Picker("Monat", selection: selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                            }
                        }
                        Picker("Jahr", selection: selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                    case .year:
                        Picker("Jahr", selection: selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                    case .range:
                        Text(rangeSummary)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.blue.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                        DateRangePicker(startDate: $rangeStartDate, endDate: $rangeEndDate)
                            .frame(minHeight: 360)
                    }
                }
            }
            .navigationTitle("Bilder löschen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbruch") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Weiter") {
                        onContinue()
                    }
                    .disabled(mode == .range && rangeStartDate == nil && rangeEndDate == nil)
                }
            }
        }
    }

    private func updateReferenceDate(month: Int? = nil, year: Int? = nil) {
        var components = Calendar.current.dateComponents([.year, .month], from: referenceDate)
        components.year = year ?? components.year
        components.month = month ?? components.month
        components.day = 1
        referenceDate = Calendar.current.date(from: components) ?? referenceDate
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
