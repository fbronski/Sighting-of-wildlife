// Edited by FBronski
// 20.07.2026

import SwiftUI
import UIKit

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

private struct SichtungGridRow: Identifiable {
    let id: Int64
    let items: [Wildsichtung]
}

private struct BackupOperationProgress: Equatable {
    let title: String
    let message: String
    let progress: Double

    var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var percentText: String {
        "\(Int((clampedProgress * 100).rounded()))%"
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
    @State private var showStatisticsSheet = false
    @State private var isCanceled = false
    @State private var deleteDateMode: DateDeletionMode = .day
    @State private var deleteReferenceDate = Date()
    @State private var deleteRangeStartDate: Date? = Date()
    @State private var deleteRangeEndDate: Date? = Date()
    @State private var pendingDateDeletionRange: Range<Date>?
    @State private var shouldConfirmDateDeletion = false
    @Environment(\.timePickerStyle) private var style
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSichtungViewActive = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    
    // Add automatic refresh timer
    @State private var refreshTimer: Task<Void, Never>? = nil
    @State private var isRefreshing = false
    @State private var isBackupOperationRunning = false
    @State private var backupProgress = BackupOperationProgress(
        title: "Backup",
        message: "Backup wird vorbereitet",
        progress: 0
    )
    @State private var backupAlertTitle = "Backup"
    @State private var backupAlertMessage = ""
    @State private var showBackupAlert = false
    @State private var backupImportCandidates: [WebDAVBackupFile] = []
    @State private var showBackupImportPicker = false
    @State private var pendingBackupImport: WebDAVBackupFile?
    @State private var showBackupImportConfirmation = false
    @State private var dateMarkers: [SichtungDateMarker] = []
    @State private var dateBadgeLocation: CGPoint?
    @State private var dateBadgeText = ""
    @State private var scrollPositionProgress: CGFloat = 0
    @State private var showScrollToTopButton = false
    @State private var isFastScrollHandleActive = false
    @State private var showFastScrollHint = false
    @AppStorage("hasSeenSichtungFastScrollHint") private var hasSeenFastScrollHint = false
    @AppStorage("languageIndex") private var languageIndex = 0
    @AppStorage("sichtungGridColumnCount") private var phoneGridColumnCount = 1
    @AppStorage("sichtungPadGridColumnCount") private var padGridColumnCount = 2
    
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
    private let gridColumnOptions = [1, 2, 4, 8]

    private var effectiveGridColumnCount: Int {
        gridColumnOptions.contains(selectedGridColumnCount) ? selectedGridColumnCount : defaultGridColumnCount
    }

    private var selectedGridColumnCount: Int {
        isPad ? padGridColumnCount : phoneGridColumnCount
    }

    private var gridColumnCountBinding: Binding<Int> {
        Binding {
            selectedGridColumnCount
        } set: { newValue in
            if isPad {
                padGridColumnCount = newValue
            } else {
                phoneGridColumnCount = newValue
            }
        }
    }

    private var defaultGridColumnCount: Int {
        isPad ? 2 : 1
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var gridSpacing: CGFloat {
        effectiveGridColumnCount == 1 ? 12 : 8
    }

    private var gridHorizontalPadding: CGFloat {
        effectiveGridColumnCount == 1 ? 12 : 14
    }

    private var listBackgroundColor: Color {
        Color(.systemBackground)
    }

    private func t(_ key: AppTextKey) -> String {
        appText(key, languageIndex: languageIndex)
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                ScrollViewReader { scrollProxy in
                sichtungContent(availableWidth: geometry.size.width)
                .scrollContentBackground(.hidden)
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .background(listBackgroundColor)
                .navigationTitle(t(.wildSightings))
                .navigationDestination(for: Int64.self) { itemID in
                    if let item = sichtung(for: itemID) {
                        DetailView(wildsichtung: item)
                    } else {
                        Text(t(.wildSightings))
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Picker("Spalten", selection: gridColumnCountBinding) {
                            ForEach(gridColumnOptions, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 156)
                        .accessibilityLabel("Spalten")
                    }

                    if isPad {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            Button {
                                scrollToTop(using: scrollProxy)
                            } label: {
                                Image(systemName: "arrow.up.to.line")
                            }
                            .accessibilityLabel(t(.topOfList))

                            Button {
                                refreshSichtungenFromDatabase()
                            } label: {
                                Image(systemName: "arrow.trianglehead.clockwise.rotate.90")
                            }
                            .disabled(isRefreshing)
                            .accessibilityLabel(t(.refreshView))

                            Button {
                                updateAllSichtungen()
                            } label: {
                                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            }
                            .disabled(isRefreshing)
                            .accessibilityLabel(t(.updateAll))
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if !isPad {
                                Button(t(.topOfList), systemImage: "arrow.up.to.line") {
                                    scrollToTop(using: scrollProxy)
                                }

                                Button(t(.refreshView), systemImage: "arrow.trianglehead.clockwise.rotate.90") {
                                    refreshSichtungenFromDatabase()
                                }
                                .disabled(isRefreshing)

                                Button(t(.updateAll), systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                                    updateAllSichtungen()
                                }
                                .disabled(isRefreshing)

                                Divider()
                            }

                            Button("Statistik", systemImage: "chart.bar.xaxis") {
                                showStatisticsSheet = true
                            }

                            Menu {
                                Button("Backup exportieren", systemImage: "icloud.and.arrow.up") {
                                    Task {
                                        await exportBackupToWebDAV()
                                    }
                                }
                                .disabled(isBackupOperationRunning)

                                Button("Backup importieren", systemImage: "icloud.and.arrow.down") {
                                    Task {
                                        await loadBackupsForImport()
                                    }
                                }
                                .disabled(isBackupOperationRunning)
                            } label: {
                                Label("Backup", systemImage: "externaldrive.badge.icloud")
                            }

                            Menu {
                                Button(t(.unpinnedDelete), systemImage: "arrow.up.trash") {
                                    deleteUnpinnedSichtungen()
                                }

                                Button("\(t(.delete)) \(viewModel.draftDuration.timeString)", systemImage: "timeline.selection") {
                                    print("Immich löschen")
                                    showTimeSheet.toggle()
                                }

                                Button(t(.dateDelete), systemImage: "calendar.badge.minus") {
                                    showDateDeleteSheet = true
                                }

                                Button(t(.databaseDelete), systemImage: "document.on.trash") {
                                    requestDatabaseDeletion()
                                }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        } label: {
                            Label("Mehr", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollIndicators(.hidden)
                .coordinateSpace(name: "SichtungScroll")
                .onPreferenceChange(SichtungDateMarkerPreferenceKey.self) { markers in
                    updateListPositionState(with: markers)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .named("SichtungScroll"))
                        .onChanged { value in
                            guard showsDateScrollControls else { return }
                            updateDateBadge(at: value.location)
                        }
                        .onEnded { _ in
                            guard showsDateScrollControls else { return }
                            withAnimation(.easeOut(duration: 0.15)) {
                                dateBadgeLocation = nil
                            }
                        }
                )
                .overlay(alignment: .topLeading) {
                    if let dateBadgeLocation, showsDateScrollControls {
                        SichtungScrollPositionBadge(text: dateBadgeText, progress: scrollPositionProgress)
                            .position(x: dateBadgeX(for: dateBadgeLocation.x), y: dateBadgeLocation.y)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .trailing) {
                    if showScrollToTopButton && showsDateScrollControls {
                        GeometryReader { proxy in
                            FastScrollHandle(isActive: isFastScrollHandleActive)
                                .frame(width: 72, height: proxy.size.height)
                                .contentShape(Rectangle())
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                        .onChanged { value in
                                            isFastScrollHandleActive = true
                                            fastScroll(to: value.location, in: proxy.size, using: scrollProxy)
                                        }
                                        .onEnded { _ in
                                            isFastScrollHandleActive = false
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                dateBadgeLocation = nil
                                            }
                                        }
                                )
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            if showFastScrollHint {
                                FastScrollHintView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                                    .padding(.trailing, 28)
                                    .padding(.top, 116)
                                    .onTapGesture {
                                        dismissFastScrollHint()
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                        .transition(.opacity)
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
                        .accessibilityLabel(t(.topOfList))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .overlay {
                    if isBackupOperationRunning {
                        BackupProgressOverlay(progress: backupProgress)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            .allowsHitTesting(true)
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: isBackupOperationRunning)
                .animation(.easeInOut(duration: 0.18), value: backupProgress)
                .refreshable {
                    Task {
                        isRefreshing = true
                        viewModel.fetchSichtungen()
                        isRefreshing = false
                    }
                }
                .sheet(isPresented: $showStatisticsSheet) {
                    StatisticsSheetView()
                }
                .sheet(isPresented: $showTimeSheet,
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
                        Alert(title: Text(t(.alertPinnedTitle)),
                              message: Text(t(.pinnedWarningMessage)),
                              primaryButton: Alert.Button.default(Text(t(.accept)), action: {
                            DatabaseManager.shared.deleteAndCreateNew()
                            print("Datenbank trotzdem löschen")
                        }),
                              secondaryButton: .destructive(Text(t(.cancel)))
                        )
                    case .second:
                        Alert(title: Text(t(.deleteImmichTitle)),
                              message: Text(deleteImagesConfirmationMessage),
                              primaryButton: Alert.Button.destructive(Text(t(.deleteToTrash)), action: {
                            Task {
                                await deleteImagesInSelectedTimeRange()
                            }
                        }),
                              secondaryButton: .cancel(Text(t(.cancel)))
                        )
                    case .third:
                        Alert(title: Text(t(.deleteImmichTitle)),
                              message: Text(dateDeletionConfirmationMessage),
                              primaryButton: Alert.Button.destructive(Text(t(.deleteToTrash)), action: {
                            Task {
                                await deleteImagesInPendingDateRange()
                            }
                        }),
                              secondaryButton: .cancel(Text(t(.cancel)))
                        )
                    }
                })
                .confirmationDialog("Backup importieren", isPresented: $showBackupImportPicker, titleVisibility: .visible) {
                    ForEach(backupImportCandidates) { backup in
                        Button(backup.displayName) {
                            pendingBackupImport = backup
                            showBackupImportConfirmation = true
                        }
                    }

                    Button(t(.cancel), role: .cancel) {}
                } message: {
                    Text("Wähle ein WebDAV-Backup aus. Der Import ersetzt nach weiterer Bestätigung die lokale Datenbank auf diesem Gerät.")
                }
                .alert("Lokale Daten überschreiben?", isPresented: $showBackupImportConfirmation, presenting: pendingBackupImport) { backup in
                    Button("Importieren", role: .destructive) {
                        Task {
                            await importBackupFromWebDAV(backup)
                        }
                    }

                    Button(t(.cancel), role: .cancel) {
                        pendingBackupImport = nil
                    }
                } message: { backup in
                    Text("Das Backup \(backup.name) ersetzt die aktuelle lokale WildSichtung-Datenbank. Vor dem Ersetzen wird automatisch eine Sicherheitskopie erstellt.")
                }
                .alert(backupAlertTitle, isPresented: $showBackupAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(backupAlertMessage)
                }
            }
        }
    }
                   
        .searchable(text: $searchText)
        .onAppear {
            // Start automatic refresh when view appears
            isSichtungViewActive = true
            startAutoRefresh()
            setSichtungViewBadgeResetActive(true)
           
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if isSichtungViewActive {
                    setSichtungViewBadgeResetActive(true)
                }
            } else {
                setSichtungViewBadgeResetActive(false)
            }
        }
        .onChange(of: selectedGridColumnCount) {
            if !showsDateScrollControls {
                resetDateScrollControls()
            }
        }
        .onDisappear {
            // Stop timer when view disappears
            isSichtungViewActive = false
            stopAutoRefresh()
            setSichtungViewBadgeResetActive(false)
        }
    }
    
    private func setSichtungViewBadgeResetActive(_ isActive: Bool) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.setSichtungViewVisible(isActive)

            if isActive {
                appDelegate.resetSichtungBadgeCount()
            }
        }
    }

    private func refreshSichtungenFromDatabase() {
        print("Refreh selected")

        Task {
            isRefreshing = true
            viewModel.sichtungen = DatabaseManager.shared.getAllSichtungen()
            isRefreshing = false
        }
    }

    private func updateAllSichtungen() {
        print("Update All without Image")

        Task {
            isRefreshing = true
            viewModel.sichtungen = DatabaseManager.shared.getAllSichtungen()
            await updateAll()
            isRefreshing = false
        }
    }

    private func deleteUnpinnedSichtungen() {
        print("Unpinned löschen")
        DatabaseManager.shared.deleteAllUnPinned()

        Task {
            isRefreshing = true
            viewModel.fetchSichtungen()
            isRefreshing = false
        }
    }

    private func requestDatabaseDeletion() {
        print("Datenbank löschen")

        if DatabaseManager.shared.IsAnyNotifyPinned() {
            activeAlert = .first
            showAlert = true
        } else {
            showAlert = false
            DatabaseManager.shared.deleteAndCreateNew()
        }

        Task {
            isRefreshing = true
            viewModel.fetchSichtungen()
            isRefreshing = false
        }
    }

    private func exportBackupToWebDAV() async {
        guard !isBackupOperationRunning else { return }
        isBackupOperationRunning = true
        startBackupProgress(title: "Backup exportieren", message: "WebDAV-Einstellungen werden geprüft")
        defer {
            isBackupOperationRunning = false
        }

        do {
            updateBackupProgress(progress: 0.08, message: "WebDAV-Verbindung wird vorbereitet")
            let client = try WebDAVBackupClient(configuration: WebDAVConfiguration.current())

            updateBackupProgress(progress: 0.18, message: "Lokale Datenbank wird gesichert")
            let backupURL = try DatabaseManager.shared.makeBackupFile()
            defer {
                try? fileManager.removeItem(at: backupURL)
            }

            updateBackupProgress(progress: 0.34, message: "Backup-Datei wird hochgeladen")
            let remoteURL = try await client.uploadBackup(from: backupURL) { progress in
                Task { @MainActor in
                    updateBackupProgress(
                        progress: 0.34 + (progress * 0.58),
                        message: "Backup-Datei wird hochgeladen"
                    )
                }
            }
            await completeBackupProgress(message: "Export abgeschlossen")
            showBackupMessage(
                title: "Backup exportiert",
                message: "Das Backup wurde nach WebDAV hochgeladen:\n\(remoteURL.lastPathComponent)"
            )
        } catch {
            updateBackupProgress(progress: backupProgress.clampedProgress, message: "Export wurde abgebrochen")
            showBackupMessage(
                title: "Backup Export fehlgeschlagen",
                message: error.localizedDescription
            )
        }
    }

    private func loadBackupsForImport() async {
        guard !isBackupOperationRunning else { return }
        isBackupOperationRunning = true
        startBackupProgress(title: "Backup importieren", message: "WebDAV-Einstellungen werden geprüft")
        defer {
            isBackupOperationRunning = false
        }

        do {
            updateBackupProgress(progress: 0.18, message: "WebDAV-Verbindung wird vorbereitet")
            let client = try WebDAVBackupClient(configuration: WebDAVConfiguration.current())

            updateBackupProgress(progress: 0.42, message: "Backup-Liste wird geladen")
            let backups = try await client.listBackups()
            guard !backups.isEmpty else {
                await completeBackupProgress(message: "Keine Backups gefunden")
                showBackupMessage(
                    title: "Kein Backup gefunden",
                    message: "Im WebDAV-Ordner wurden keine .wildsichtungbackup-Dateien gefunden."
                )
                return
            }

            updateBackupProgress(progress: 0.88, message: "Backup-Liste wird vorbereitet")
            backupImportCandidates = backups
            await completeBackupProgress(message: "Backups geladen")
            showBackupImportPicker = true
        } catch {
            updateBackupProgress(progress: backupProgress.clampedProgress, message: "Import-Vorbereitung wurde abgebrochen")
            showBackupMessage(
                title: "Backup Import fehlgeschlagen",
                message: error.localizedDescription
            )
        }
    }

    private func importBackupFromWebDAV(_ backup: WebDAVBackupFile) async {
        guard !isBackupOperationRunning else { return }
        isBackupOperationRunning = true
        startBackupProgress(title: "Backup importieren", message: "Download wird vorbereitet")
        defer {
            isBackupOperationRunning = false
            pendingBackupImport = nil
        }

        do {
            updateBackupProgress(progress: 0.08, message: "WebDAV-Verbindung wird vorbereitet")
            let client = try WebDAVBackupClient(configuration: WebDAVConfiguration.current())

            updateBackupProgress(progress: 0.14, message: "Backup wird heruntergeladen")
            let localBackupURL = try await client.downloadBackup(backup) { progress in
                Task { @MainActor in
                    updateBackupProgress(
                        progress: 0.14 + (progress * 0.46),
                        message: "Backup wird heruntergeladen"
                    )
                }
            }
            defer {
                try? fileManager.removeItem(at: localBackupURL)
            }

            try DatabaseManager.shared.replaceDatabase(withBackupAt: localBackupURL) { progress, message in
                updateBackupProgress(progress: progress, message: message)
            }
            updateBackupProgress(progress: 0.96, message: "Sichtungen werden neu geladen")
            viewModel.fetchSichtungen()

            await completeBackupProgress(message: "Import abgeschlossen")
            showBackupMessage(
                title: "Backup importiert",
                message: "Die lokale Datenbank wurde durch \(backup.name) ersetzt."
            )
        } catch {
            updateBackupProgress(progress: backupProgress.clampedProgress, message: "Import wurde abgebrochen")
            showBackupMessage(
                title: "Backup Import fehlgeschlagen",
                message: error.localizedDescription
            )
        }
    }

    private func startBackupProgress(title: String, message: String) {
        backupProgress = BackupOperationProgress(title: title, message: message, progress: 0)
    }

    private func updateBackupProgress(progress: Double, message: String) {
        backupProgress = BackupOperationProgress(title: backupProgress.title, message: message, progress: progress)
    }

    private func completeBackupProgress(message: String) async {
        updateBackupProgress(progress: 1, message: message)
        try? await Task.sleep(nanoseconds: 350_000_000)
    }

    private func showBackupMessage(title: String, message: String) {
        backupAlertTitle = title
        backupAlertMessage = message
        showBackupAlert = true
    }

    private var shouldScrollGridRowsHorizontally: Bool {
        effectiveGridColumnCount > 2
    }

    private var showsDateScrollControls: Bool {
        effectiveGridColumnCount <= 2
    }

    private var minimumScrollableCardWidth: CGFloat {
        effectiveGridColumnCount == 4 ? 118 : 82
    }

    private func scrollableGridCardWidth(availableWidth: CGFloat) -> CGFloat {
        let columnCount = CGFloat(effectiveGridColumnCount)
        let contentWidth = max(availableWidth - (gridHorizontalPadding * 2), 1)
        let totalSpacing = CGFloat(max(effectiveGridColumnCount - 1, 0)) * gridSpacing
        let fittedWidth = max((contentWidth - totalSpacing) / columnCount, 1)

        return max(fittedWidth, minimumScrollableCardWidth)
    }

    private var scrollableGridRowMinHeight: CGFloat {
        effectiveGridColumnCount == 4 ? 166 : 88
    }

    @ViewBuilder
    private func sichtungContent(availableWidth: CGFloat) -> some View {
        if effectiveGridColumnCount == 1 {
            sichtungListContent(availableWidth: availableWidth)
        } else {
            sichtungLazyGridContent(availableWidth: availableWidth)
        }
    }

    private func sichtungListContent(availableWidth: CGFloat) -> some View {
        List {
            Color.clear
                .frame(height: 0)
                .id(topListID)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(listBackgroundColor)

            ForEach(groupedSearchResults) { row in
                sichtungGridRow(row, availableWidth: availableWidth)
                    .padding(.vertical, gridSpacing / 2)
                    .background {
                        if let markerItem = row.items.first {
                            sichtungDateMarker(for: markerItem)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(listBackgroundColor)
            }
        }
    }

    private func sichtungLazyGridContent(availableWidth: CGFloat) -> some View {
        let scrollAxes: Axis.Set = shouldScrollGridRowsHorizontally ? [.vertical, .horizontal] : .vertical

        return ScrollView(scrollAxes, showsIndicators: false) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .id(topListID)

                LazyVGrid(
                    columns: lazyGridColumns(availableWidth: availableWidth),
                    alignment: .leading,
                    spacing: gridSpacing
                ) {
                    ForEach(searchResults) { item in
                        sichtungCardCell(item)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .contentShape(Rectangle())
                            .id(sichtungCardIdentity(for: item))
                            .contextMenu {
                                sichtungContextMenu(for: item)
                            } preview: {
                                sichtungContextPreview(for: item)
                            }
                            .background {
                                sichtungDateMarker(for: item)
                            }
                    }
                }
                .padding(.horizontal, gridHorizontalPadding)
                .padding(.vertical, gridSpacing / 2)
                .frame(width: lazyGridContentWidth(availableWidth: availableWidth), alignment: .topLeading)
            }
            .frame(maxWidth: shouldScrollGridRowsHorizontally ? nil : .infinity, alignment: .topLeading)
        }
    }

    private func lazyGridColumns(availableWidth: CGFloat) -> [GridItem] {
        if shouldScrollGridRowsHorizontally {
            let cardWidth = scrollableGridCardWidth(availableWidth: availableWidth)
            return Array(
                repeating: GridItem(.fixed(cardWidth), spacing: gridSpacing, alignment: .top),
                count: effectiveGridColumnCount
            )
        }

        return Array(
            repeating: GridItem(.flexible(minimum: 1), spacing: gridSpacing, alignment: .top),
            count: effectiveGridColumnCount
        )
    }

    private func lazyGridContentWidth(availableWidth: CGFloat) -> CGFloat? {
        guard shouldScrollGridRowsHorizontally else {
            return nil
        }

        let cardWidth = scrollableGridCardWidth(availableWidth: availableWidth)
        let totalSpacing = CGFloat(max(effectiveGridColumnCount - 1, 0)) * gridSpacing
        let calculatedWidth = (CGFloat(effectiveGridColumnCount) * cardWidth) + totalSpacing + (gridHorizontalPadding * 2)
        return max(availableWidth, calculatedWidth)
    }

    private func sichtungDateMarker(for item: Wildsichtung) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SichtungDateMarkerPreferenceKey.self,
                value: [
                    SichtungDateMarker(
                        id: item.id,
                        frame: proxy.frame(in: .named("SichtungScroll")),
                        date: item.creationDate
                    )
                ]
            )
        }
    }

    @ViewBuilder
    private func sichtungGridRow(_ row: SichtungGridRow, availableWidth: CGFloat) -> some View {
        if shouldScrollGridRowsHorizontally {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: gridSpacing) {
                    ForEach(row.items) { item in
                        sichtungCardCell(item)
                            .frame(width: scrollableGridCardWidth(availableWidth: availableWidth), alignment: .top)
                            .contentShape(Rectangle())
                            .id(sichtungCardIdentity(for: item))
                            .contextMenu {
                                sichtungContextMenu(for: item)
                            } preview: {
                                sichtungContextPreview(for: item)
                            }
                            .clipped()
                    }
                }
                .padding(.horizontal, gridHorizontalPadding)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: scrollableGridRowMinHeight, alignment: .top)
        } else if effectiveGridColumnCount == 1 {
            sichtungFittingGridRow(row)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if let item = row.items.first {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label(t(.delete), systemImage: "trash")
                        }
                    }
                }
        } else {
            sichtungFittingGridRow(row)
        }
    }

    private func sichtungFittingGridRow(_ row: SichtungGridRow) -> some View {
        HStack(alignment: .top, spacing: gridSpacing) {
            ForEach(row.items) { item in
                sichtungCardCell(item)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .contentShape(Rectangle())
                    .id(sichtungCardIdentity(for: item))
                    .contextMenu {
                        sichtungContextMenu(for: item)
                    } preview: {
                        sichtungContextPreview(for: item)
                    }
            }

            ForEach(0..<emptyGridSlots(for: row), id: \.self) { _ in
                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, gridHorizontalPadding)
    }

    @ViewBuilder
    private func sichtungCardCell(_ item: Wildsichtung) -> some View {
        CardView(
            wildsichtung: item,
            isPinned: item.pinned,
            columnCount: effectiveGridColumnCount,
            onOpen: {
                navigationPath.append(item.id)
            },
            onPinnedChange: { isPinned in
                setPinned(isPinned, for: item.id)
            }
        )
    }

    private func sichtungCardIdentity(for item: Wildsichtung) -> String {
        "\(item.id)-\(item.immichid)-\(effectiveGridColumnCount)"
    }

    @ViewBuilder
    private func sichtungContextMenu(for item: Wildsichtung) -> some View {
        Button {
            Task {
                await updateItem(item)
            }
        } label: {
            Label(t(.update), systemImage: "arrow.trianglehead.clockwise.rotate.90")
        }
        .tint(.orange)

        Button {
            deleteItem(item)
        } label: {
            Label(t(.delete), systemImage: "trash")
        }
        .tint(.red)

        if item.pinned {
            Button {
                pinItem(item)
            } label: {
                Label(t(.unpin), systemImage: "pin.slash")
            }
            .tint(.red)
        } else {
            Button {
                pinItem(item)
            } label: {
                Label(t(.pin), systemImage: "pin")
            }
            .tint(.blue)
        }

        Divider()

        Button {
            Task { await sendPlotCMDPerFTP(item) }
        } label: {
            Label(t(.getPlotted), systemImage: "photo.artframe.circle")
        }
        .tint(.cyan)

        if let shareImage = shareImage(for: item) {
            ShareLink(item: shareImage, preview: SharePreview(t(.wildSightings), image: shareImage)) {
                Label(t(.sharePhoto), systemImage: "square.and.arrow.up")
            }
            .tint(.purple)
        }
    }

    @ViewBuilder
    private func sichtungContextPreview(for item: Wildsichtung) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let uiImage = uiImage(for: item) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 280, height: 180)
                    .clipped()
            } else {
                ZStack {
                    Color(.secondarySystemBackground)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 280, height: 180)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                if !item.yolostatus.isEmpty {
                    Text(item.yolostatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(width: 280, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func shareImage(for item: Wildsichtung) -> Image? {
        guard let uiImage = uiImage(for: item) else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    private func uiImage(for item: Wildsichtung) -> UIImage? {
        guard !item.imagebase64.isEmpty,
              let data = Data(base64Encoded: item.imagebase64),
              let uiImage = UIImage(data: data) else {
            return nil
        }

        return uiImage
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
                        viewModel.fetchSichtungen()
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

    private func sichtung(for id: Int64) -> Wildsichtung? {
        viewModel.sichtungen.first { $0.id == id }
    }

    private func setPinned(_ isPinned: Bool, for id: Int64) {
        guard let index = viewModel.sichtungen.firstIndex(where: { $0.id == id }) else {
            return
        }

        viewModel.sichtungen[index].pinned = isPinned
    }

    private var groupedSearchResults: [SichtungGridRow] {
        let results = searchResults
        let columnCount = effectiveGridColumnCount
        guard columnCount > 1 else {
            return results.map { SichtungGridRow(id: $0.id, items: [$0]) }
        }

        return stride(from: 0, to: results.count, by: columnCount).map { startIndex in
            let endIndex = min(startIndex + columnCount, results.count)
            let items = Array(results[startIndex..<endIndex])
            return SichtungGridRow(id: items.first?.id ?? Int64(startIndex), items: items)
        }
    }

    private func emptyGridSlots(for row: SichtungGridRow) -> Int {
        max(0, effectiveGridColumnCount - row.items.count)
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
        let results = searchResults
        guard let firstID = results.first?.id, !markers.isEmpty else {
            scrollPositionProgress = 0
            setScrollToTopButtonVisible(false)
            return
        }

        updateScrollPositionProgress(with: markers, results: results)

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

        if isVisible {
            presentFastScrollHintIfNeeded()
        }
    }

    private func presentFastScrollHintIfNeeded() {
        guard showsDateScrollControls, !hasSeenFastScrollHint, !showFastScrollHint else { return }

        showFastScrollHint = true
        Task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                dismissFastScrollHint()
            }
        }
    }

    private func dismissFastScrollHint() {
        guard showFastScrollHint else { return }

        hasSeenFastScrollHint = true
        withAnimation(.easeOut(duration: 0.18)) {
            showFastScrollHint = false
        }
    }

    private func resetDateScrollControls() {
        dateBadgeLocation = nil
        showFastScrollHint = false
        isFastScrollHandleActive = false
        scrollPositionProgress = min(max(scrollPositionProgress, 0), 1)
    }

    private func updateScrollPositionProgress(with markers: [SichtungDateMarker], results: [Wildsichtung]) {
        guard results.count > 1 else {
            scrollPositionProgress = 0
            return
        }

        let visibleMarkers = markers.filter { $0.frame.maxY >= 0 }
        guard let topMarker = visibleMarkers.min(by: { $0.frame.midY < $1.frame.midY }) else {
            return
        }

        updateScrollPositionProgress(for: topMarker.id, results: results)
    }

    private func updateScrollPositionProgress(for id: Int64, results: [Wildsichtung]? = nil) {
        let currentResults = results ?? searchResults
        guard currentResults.count > 1,
              let index = currentResults.firstIndex(where: { $0.id == id }) else {
            scrollPositionProgress = 0
            return
        }

        let progress = CGFloat(index) / CGFloat(currentResults.count - 1)
        scrollPositionProgress = min(max(progress, 0), 1)
    }
    
    private func updateDateBadge(at location: CGPoint) {
        guard showsDateScrollControls,
              let marker = nearestDateMarker(to: location) else {
            return
        }

        updateScrollPositionProgress(for: marker.id)
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

    private func fastScroll(to location: CGPoint, in size: CGSize, using proxy: ScrollViewProxy) {
        let results = searchResults
        guard !results.isEmpty else { return }

        let normalizedPosition = min(max(location.y / max(size.height, 1), 0), 1)
        let rawIndex = (CGFloat(results.count - 1) * normalizedPosition).rounded()
        let targetIndex = min(max(Int(rawIndex), 0), results.count - 1)
        let target = results[targetIndex]

        proxy.scrollTo(target.id, anchor: .top)
        scrollPositionProgress = normalizedPosition
        dateBadgeText = Self.scrollDateFormatter.string(from: target.creationDate)
        dateBadgeLocation = CGPoint(x: max(size.width - 32, 32), y: min(max(location.y, 32), size.height - 32))
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
            let client = try ImmichAPIConfiguration.current()

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
        
        viewModel.fetchSichtungen()
    }
    
    func deleteItem(_ item: Wildsichtung) {
        DatabaseManager.shared.deleteSichtung(sichtungId: item.id)
       viewModel.sichtungen.removeAll(where: { $0.id == item.id })
        viewModel.fetchSichtungen()
    }
    
    
    func sendPlotCMDPerFTP(_ item: Wildsichtung) async {
        let secs = Date.now.timeIntervalSince1970
   	
        let filename = "\(item.cameraid)_CMD_\(secs).txt" //this is the file. we will write to and read from it
        let replaced = item.body.replacingOccurrences(of: "Neue Sichtung ", with: "")
        let cm = CommandModel(id: UUID().uuidString, cmd: "GetPLOT", text: replaced, immichid: item.immichid, creationDate: Date.now.formattedString(dateFormat: "yyyy-MM-dd’T’HH:mm:ss"))
        let cmdText = cm.getJsonStringAsBase64()

        do {
            let ftpHost = (UserDefaults.standard.string(forKey: "ftpIP") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let ftpPortText = (UserDefaults.standard.string(forKey: "ftpPort") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let ftpUser = (UserDefaults.standard.string(forKey: "ftpUser") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let ftpPassword = UserDefaults.standard.string(forKey: "ftpPassword") ?? ""
            guard !ftpHost.isEmpty,
                  let ftpPort = UInt16(ftpPortText),
                  !ftpUser.isEmpty,
                  !ftpPassword.isEmpty else {
                print("FTP Einstellungen sind unvollständig oder der Port ist ungültig.")
                return
            }

            let normalizedFTPHost = ftpHost.lowercased()
            let ftpSecurityIndex = UserDefaults.standard.integer(forKey: "ftpSecurityIndex")
            let ftpSecurity: FTPConnectionSecurity = ftpSecurityIndex == 1 ? .explicitTLS : .none
            let allowsUntrustedCertificate = ftpSecurity == .explicitTLS && normalizedFTPHost == "upload.wildbild.cloud"
            let credentials = FTPCredentials(
                host: ftpHost,
                port: ftpPort,
                username: ftpUser,
                password: ftpPassword,
                security: ftpSecurity,
                allowsUntrustedTLSCertificate: allowsUntrustedCertificate
            )
            let ftpClient = FTPClient(credentials: credentials, remotePath: "")
            let filesToUpload: [FTPUploadable] = [
                .data(data: Data(cmdText.utf8), remoteFileName: filename)
            ]

            try await ftpClient.upload(files: filesToUpload) { progress in
                print("Overall progress: \(progress.fractionCompleted * 100)%")
            }
            print("All files uploaded successfully.")
        } catch {
            print("Error writing file \(error)")
        }
    }
    
    func pinItem(_ item: Wildsichtung) {
        let newPinnedState = !item.pinned
        _ = DatabaseManager.shared.updatePinned(iid: item.immichid, pinned: newPinnedState)
        setPinned(newPinnedState, for: item.id)
        print("pinned")
        
        viewModel.fetchSichtungen()
    }
    
    func updateItem(_ item: Wildsichtung) async {
       
        do {
           
            let client = try ImmichAPIConfiguration.current()
   	   	  
   	 	    
            let version = try await ServerAPI.getVersionHistory(apiConfiguration: client)
            print("Immich Version: \(version)")
            
            
            let response =  try await AssetsAPI.downloadAsset(id: item.immichid, key: nil, apiConfiguration: client)
            
            let cachepath = response.path()
            let url = URL(fileURLWithPath: cachepath)

          
            let data = try Data(contentsOf: url)
            
            let dt = Data(data)
            let ab = (dt.base64EncodedString())
            _ = DatabaseManager.shared.updateImage(iid: item.immichid, imagebase64: ab)
   	   	  
   	 	    
            try fileManager.removeItem(at: url)
            viewModel.fetchSichtungen()
          
        } catch{
            print("Get Image Date Error:\(error)")
        }
   
 	     
 	   	  
        withAnimation {
            
        }
        print("\(item) update")
    }

    func deleteImage(_ item: Wildsichtung) async {
       
        do {
           
            let client = try ImmichAPIConfiguration.current()
   	   	  
   	 	    
            let version = try await ServerAPI.getVersionHistory(apiConfiguration: client)
            print("Immich Version: \(version)")
            
            var uuids: [String] = []
            uuids.append(item.immichid)
            let assetBulkDeleteDto = AssetBulkDeleteDto(force: false, ids: uuids)
            try await AssetsAPI.deleteAssets(assetBulkDeleteDto: assetBulkDeleteDto, apiConfiguration: client)
            //downloadAsset(id: item.immichid, key: nil, apiConfiguration: client)
            
            print("Immich image moved to trash: \(item.immichid)")
          
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

private struct BackupProgressOverlay: View {
    let progress: BackupOperationProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.icloud")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(progress.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(progress.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 10)

                    Text(progress.percentText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .frame(minWidth: 58, alignment: .trailing)
                }

                ProgressView(value: progress.clampedProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .scaleEffect(x: 1, y: 1.3, anchor: .center)
                    .accessibilityLabel("Backup Fortschritt")
                    .accessibilityValue(progress.percentText)
            }
            .padding(18)
            .frame(maxWidth: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

private struct SichtungScrollPositionBadge: View {
    let text: String
    let progress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .imageScale(.small)
                Text(text)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }

            ScrollProgressBar(progress: progress)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)
    }
}

private struct ScrollProgressBar: View {
    @AppStorage("languageIndex") private var languageIndex = 0
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)
            let thumbX = clampedProgress * max(proxy.size.width - 10, 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(height: 4)
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: max(10, proxy.size.width * clampedProgress), height: 4)
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .offset(x: thumbX)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 160, height: 12)
        .accessibilityLabel(appText(.scrollPosition, languageIndex: languageIndex))
    }
}

private struct FastScrollHandle: View {
    @AppStorage("languageIndex") private var languageIndex = 0
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.clear
            Capsule()
                .fill(.black.opacity(isActive ? 0.42 : 0.24))
                .frame(width: isActive ? 14 : 10, height: isActive ? 168 : 128)
                .padding(.trailing, 8)
        }
        .padding(.vertical, 56)
        .accessibilityLabel(appText(.scrollHint, languageIndex: languageIndex))
    }
}

private struct FastScrollHintView: View {
    @AppStorage("languageIndex") private var languageIndex = 0

    var body: some View {
        HStack(spacing: 8) {
            Text(appText(.scrollHint, languageIndex: languageIndex))
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "arrow.right")
                .imageScale(.small)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.78), in: Capsule())
        .shadow(color: .black.opacity(0.24), radius: 8, x: 0, y: 3)
        .accessibilityLabel(appText(.scrollHintAccessibility, languageIndex: languageIndex))
    }
}

private struct DateDeletionSelectionSheet: View {
    @AppStorage("languageIndex") private var languageIndex = 0
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
            .navigationTitle(appText(.deleteDateTitle, languageIndex: languageIndex))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appText(.cancel, languageIndex: languageIndex)) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appText(.continueAction, languageIndex: languageIndex)) {
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
