// Edited by FBronski
// 31.08.2026

import SwiftUI
import UIKit

struct StatisticsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StatisticsSheetViewModel()
    @State private var showCompactConfirmation = false
    @State private var compactResultMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isLoading && viewModel.localStatistics == nil {
                        StatisticsLoadingView()
                    }

                    if let localStatistics = viewModel.localStatistics {
                        LocalStatisticsSection(
                            statistics: localStatistics,
                            isCompacting: viewModel.isCompacting,
                            onCompact: {
                                showCompactConfirmation = true
                            }
                        )
                    }

                    if let appStorage = viewModel.appStorage {
                        AppStorageSection(storage: appStorage)
                    } else if viewModel.isAppStorageLoading {
                        AppStorageLoadingSection()
                    }

                    if let deviceStorage = viewModel.deviceStorage {
                        DeviceStorageSection(storage: deviceStorage)
                    }

                    ImmichStatisticsSection(snapshot: viewModel.immichStatistics)

                    if let lastUpdated = viewModel.lastUpdated {
                        Text("Aktualisiert: \(lastUpdated.formatted(date: .abbreviated, time: .standard))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Statistik")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.load()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading || viewModel.isCompacting)
                    .accessibilityLabel("Statistik aktualisieren")
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .alert("Datenbank komprimieren?", isPresented: $showCompactConfirmation) {
                Button("Komprimieren", role: .destructive) {
                    Task {
                        compactResultMessage = await viewModel.compactDatabase()
                    }
                }

                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("SQLite wird per VACUUM neu aufgebaut. Das kann kurz dauern und benötigt währenddessen temporär freien Speicher ungefähr in Größe der aktuellen Datenbank.")
            }
            .alert(
                "Datenbank",
                isPresented: Binding(
                    get: { compactResultMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            compactResultMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(compactResultMessage ?? "")
            }
        }
    }
}

@MainActor
@Observable
private final class StatisticsSheetViewModel {
    var isLoading = false
    var isCompacting = false
    var isAppStorageLoading = false
    var localStatistics: LocalDatabaseStatistics?
    var appStorage: AppStorageStatistics?
    var deviceStorage: DeviceStorageStatistics?
    var immichStatistics = ImmichStatisticsSnapshot()
    var lastUpdated: Date?

    func load() async {
        guard !isLoading, !isCompacting else {
            StatisticsDebugLog.skip("Statistik laden", detail: "läuft bereits")
            return
        }

        let loadStartedAt = StatisticsDebugLog.start("Statistik laden")
        isLoading = true

        let localStatisticsStartedAt = StatisticsDebugLog.start("SQLite localStatistics")
        localStatistics = DatabaseManager.shared.localStatistics()
        StatisticsDebugLog.finish(
            "SQLite localStatistics",
            since: localStatisticsStartedAt,
            detail: "db=\(StatisticsFormat.bytes(localStatistics?.databaseSizeBytes ?? 0)), frei=\(StatisticsFormat.bytes(localStatistics?.freeDatabaseBytes ?? 0))"
        )

        startAppStorageLoad()

        let deviceStorageStartedAt = StatisticsDebugLog.start("DeviceStorageStatistics.current")
        deviceStorage = DeviceStorageStatistics.current()
        StatisticsDebugLog.finish(
            "DeviceStorageStatistics.current",
            since: deviceStorageStartedAt,
            detail: "frei=\(StatisticsFormat.bytes(deviceStorage?.freeBytes ?? 0))"
        )

        var snapshot = ImmichStatisticsSnapshot()

        do {
            let configurationStartedAt = StatisticsDebugLog.start("ImmichAPIConfiguration.current")
            let configuration = try ImmichAPIConfiguration.current()
            StatisticsDebugLog.finish(
                "ImmichAPIConfiguration.current",
                since: configurationStartedAt,
                detail: configuration.basePath
            )

            do {
                let startedAt = StatisticsDebugLog.start("Immich AssetsAPI.getAssetStatistics")
                snapshot.assetStats = try await AssetsAPI.getAssetStatistics(apiConfiguration: configuration)
                StatisticsDebugLog.finish(
                    "Immich AssetsAPI.getAssetStatistics",
                    since: startedAt,
                    detail: "images=\(snapshot.assetStats?.images ?? 0), videos=\(snapshot.assetStats?.videos ?? 0), total=\(snapshot.assetStats?.total ?? 0)"
                )
            } catch {
                StatisticsDebugLog.fail("Immich AssetsAPI.getAssetStatistics", error: error)
                snapshot.messages.append("Immich Bilder konnten nicht geladen werden: \(message(for: error))")
            }

            do {
                let startedAt = StatisticsDebugLog.start("Immich ServerAPI.getServerStatistics")
                snapshot.serverStats = try await ServerAPI.getServerStatistics(apiConfiguration: configuration)
                StatisticsDebugLog.finish(
                    "Immich ServerAPI.getServerStatistics",
                    since: startedAt,
                    detail: "photos=\(snapshot.serverStats?.photos ?? 0), videos=\(snapshot.serverStats?.videos ?? 0), usage=\(StatisticsFormat.bytes(snapshot.serverStats?.usage ?? 0))"
                )
            } catch {
                StatisticsDebugLog.fail("Immich ServerAPI.getServerStatistics", error: error)
                snapshot.messages.append("Server-Statistik konnte nicht geladen werden: \(message(for: error))")
            }

            do {
                let startedAt = StatisticsDebugLog.start("Immich ServerAPI.getStorage")
                snapshot.storage = try await ServerAPI.getStorage(apiConfiguration: configuration)
                StatisticsDebugLog.finish(
                    "Immich ServerAPI.getStorage",
                    since: startedAt,
                    detail: "used=\(StatisticsFormat.bytes(snapshot.storage?.diskUseRaw ?? 0)), free=\(StatisticsFormat.bytes(snapshot.storage?.diskAvailableRaw ?? 0))"
                )
            } catch {
                StatisticsDebugLog.fail("Immich ServerAPI.getStorage", error: error)
                snapshot.messages.append("Server-Speicher konnte nicht geladen werden: \(message(for: error))")
            }
        } catch {
            StatisticsDebugLog.fail("ImmichAPIConfiguration.current", error: error)
            snapshot.messages.append(message(for: error))
        }

        immichStatistics = snapshot
        lastUpdated = Date()
        isLoading = false
        StatisticsDebugLog.finish("Statistik laden", since: loadStartedAt)
    }

    func compactDatabase() async -> String {
        guard !isCompacting else {
            StatisticsDebugLog.skip("SQLite compactDatabase", detail: "läuft bereits")
            return "Die Datenbank wird bereits komprimiert."
        }

        let compactStartedAt = StatisticsDebugLog.start("SQLite compactDatabase")
        isCompacting = true
        await Task.yield()
        let previousStorageBytes = localStatistics?.totalStorageBytes ?? 0

        do {
            let vacuumStartedAt = StatisticsDebugLog.start("DatabaseManager.compactDatabase")
            localStatistics = try DatabaseManager.shared.compactDatabase()
            StatisticsDebugLog.finish(
                "DatabaseManager.compactDatabase",
                since: vacuumStartedAt,
                detail: "vorher=\(StatisticsFormat.bytes(previousStorageBytes)), nachher=\(StatisticsFormat.bytes(localStatistics?.totalStorageBytes ?? 0))"
            )

            let appStorageStartedAt = StatisticsDebugLog.start("AppStorageStatistics.current nach VACUUM")
            appStorage = await Self.loadAppStorageInBackground()
            StatisticsDebugLog.finish(
                "AppStorageStatistics.current nach VACUUM",
                since: appStorageStartedAt,
                detail: "gesamt=\(StatisticsFormat.bytes(appStorage?.totalBytes ?? 0))"
            )

            let deviceStorageStartedAt = StatisticsDebugLog.start("DeviceStorageStatistics.current nach VACUUM")
            deviceStorage = DeviceStorageStatistics.current()
            StatisticsDebugLog.finish(
                "DeviceStorageStatistics.current nach VACUUM",
                since: deviceStorageStartedAt,
                detail: "frei=\(StatisticsFormat.bytes(deviceStorage?.freeBytes ?? 0))"
            )
            lastUpdated = Date()

            let currentStorageBytes = localStatistics?.totalStorageBytes ?? 0
            let releasedBytes = max(previousStorageBytes - currentStorageBytes, 0)
            isCompacting = false
            StatisticsDebugLog.finish(
                "SQLite compactDatabase",
                since: compactStartedAt,
                detail: "freigegeben=\(StatisticsFormat.bytes(releasedBytes))"
            )

            if releasedBytes > 0 {
                return "Die SQLite-Datenbank wurde komprimiert. Freigegeben: \(StatisticsFormat.bytes(releasedBytes))."
            }

            return "Die SQLite-Datenbank wurde komprimiert. Es war kein zusätzlicher freigebbarer Speicher messbar."
        } catch {
            isCompacting = false
            StatisticsDebugLog.fail("SQLite compactDatabase", since: compactStartedAt, error: error)
            return "Die SQLite-Datenbank konnte nicht komprimiert werden: \(message(for: error))"
        }
    }

    private func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription {
            return errorDescription
        }

        if let errorResponse = error as? ErrorResponse {
            return errorResponse.debugMessage
        }

        return error.localizedDescription
    }

    private func startAppStorageLoad() {
        guard !isAppStorageLoading else {
            StatisticsDebugLog.skip("AppStorageStatistics.current", detail: "läuft bereits")
            return
        }

        isAppStorageLoading = true
        let appStorageStartedAt = StatisticsDebugLog.start("AppStorageStatistics.current Hintergrund")

        Task { @MainActor in
            let storage = await Self.loadAppStorageInBackground()
            appStorage = storage
            isAppStorageLoading = false
            StatisticsDebugLog.finish(
                "AppStorageStatistics.current Hintergrund",
                since: appStorageStartedAt,
                detail: "gesamt=\(StatisticsFormat.bytes(storage.totalBytes))"
            )
        }
    }

    private static func loadAppStorageInBackground() async -> AppStorageStatistics {
        await Task.detached(priority: .utility) {
            AppStorageStatistics.current()
        }.value
    }

}

private struct ImmichStatisticsSnapshot: Equatable {
    var assetStats: AssetStatsResponseDto?
    var serverStats: ServerStatsResponseDto?
    var storage: ServerStorageResponseDto?
    var messages: [String] = []

    var hasServerData: Bool {
        assetStats != nil || serverStats != nil || storage != nil
    }
}

struct DeviceStorageStatistics: Equatable, Sendable {
    let totalBytes: Int64
    let freeBytes: Int64

    var usedBytes: Int64 {
        max(totalBytes - freeBytes, 0)
    }

    static func current(fileManager: FileManager = .default) -> DeviceStorageStatistics? {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let totalBytes = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
            let freeBytes = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0

            guard totalBytes > 0 else { return nil }
            return DeviceStorageStatistics(totalBytes: totalBytes, freeBytes: max(freeBytes, 0))
        } catch {
            print("Unable to read device storage statistics. Error: \(error)")
            return nil
        }
    }
}

struct AppStorageStatistics: Equatable, Sendable {
    let documentsBytes: Int64
    let libraryBytes: Int64
    let cachesBytes: Int64
    let temporaryBytes: Int64
    let appGroupBytes: Int64

    var totalBytes: Int64 {
        documentsBytes + libraryBytes + cachesBytes + temporaryBytes + appGroupBytes
    }

    static func current(fileManager: FileManager = .default) -> AppStorageStatistics {
        let startedAt = StatisticsDebugLog.start("AppStorage Verzeichnisse")
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? homeURL.appendingPathComponent("Documents", isDirectory: true)
        let libraryURL = homeURL.appendingPathComponent("Library", isDirectory: true)
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? libraryURL.appendingPathComponent("Caches", isDirectory: true)
        let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.de.unicomedv.WildSichtung")

        let cachesBytes = allocatedSize(at: cachesURL, label: "Caches", fileManager: fileManager)
        let libraryBytes = allocatedSize(
            at: libraryURL,
            label: "Library ohne Caches",
            excluding: [cachesURL],
            fileManager: fileManager
        )
        let documentsBytes = allocatedSize(at: documentsURL, label: "Documents", fileManager: fileManager)
        let temporaryBytes = allocatedSize(at: temporaryURL, label: "Temp", fileManager: fileManager)
        let appGroupBytes = allocatedSize(at: appGroupURL, label: "App-Gruppe", fileManager: fileManager)

        StatisticsDebugLog.finish(
            "AppStorage Verzeichnisse",
            since: startedAt,
            detail: "gesamt=\(StatisticsFormat.bytes(documentsBytes + libraryBytes + cachesBytes + temporaryBytes + appGroupBytes))"
        )

        return AppStorageStatistics(
            documentsBytes: documentsBytes,
            libraryBytes: libraryBytes,
            cachesBytes: cachesBytes,
            temporaryBytes: temporaryBytes,
            appGroupBytes: appGroupBytes
        )
    }

    private static func allocatedSize(
        at url: URL?,
        label: String,
        excluding excludedURLs: [URL] = [],
        fileManager: FileManager
    ) -> Int64 {
        let startedAt = StatisticsDebugLog.start("AppStorage \(label)")
        guard let url else {
            StatisticsDebugLog.finish("AppStorage \(label)", since: startedAt, detail: "URL fehlt")
            return 0
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            StatisticsDebugLog.finish("AppStorage \(label)", since: startedAt, detail: "nicht vorhanden: \(url.path)")
            return 0
        }

        guard isDirectory.boolValue else {
            let bytes = allocatedFileSize(at: url)
            StatisticsDebugLog.finish(
                "AppStorage \(label)",
                since: startedAt,
                detail: "datei=\(StatisticsFormat.bytes(bytes))"
            )
            return bytes
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ]
        let excludedPaths = Set(excludedURLs.map { $0.standardizedFileURL.path })

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            StatisticsDebugLog.finish("AppStorage \(label)", since: startedAt, detail: "Enumerator fehlt")
            return 0
        }

        var totalBytes: Int64 = 0
        var fileCount = 0
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory == true,
               excludedPaths.contains(fileURL.standardizedFileURL.path) {
                enumerator.skipDescendants()
                continue
            }

            let fileBytes = allocatedFileSize(at: fileURL)
            if fileBytes > 0 {
                fileCount += 1
                totalBytes += fileBytes
            }
        }

        StatisticsDebugLog.finish(
            "AppStorage \(label)",
            since: startedAt,
            detail: "files=\(fileCount), size=\(StatisticsFormat.bytes(totalBytes)), path=\(url.path)"
        )

        return totalBytes
    }

    private static func allocatedFileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [
            .isRegularFileKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ])

        guard values?.isRegularFile == true else {
            return 0
        }

        if let totalFileAllocatedSize = values?.totalFileAllocatedSize {
            return Int64(totalFileAllocatedSize)
        }

        if let fileAllocatedSize = values?.fileAllocatedSize {
            return Int64(fileAllocatedSize)
        }

        if let fileSize = values?.fileSize {
            return Int64(fileSize)
        }

        return 0
    }
}

private struct LocalStatisticsSection: View {
    let statistics: LocalDatabaseStatistics
    let isCompacting: Bool
    let onCompact: () -> Void

    var body: some View {
        StatisticsSection(title: "Lokale Daten", systemImage: "externaldrive") {
            StatisticsMetricGrid(metrics: [
                StatisticsMetric(title: "Sichtungen", value: StatisticsFormat.count(statistics.sightingCount)),
                StatisticsMetric(title: "Kameras", value: StatisticsFormat.count(statistics.cameraCount)),
                StatisticsMetric(title: "Gespeicherte Bilddaten", value: StatisticsFormat.count(statistics.savedImageDataCount)),
                StatisticsMetric(title: "Immich IDs", value: StatisticsFormat.count(statistics.immichLinkedImageCount)),
                StatisticsMetric(title: "Gepinnt", value: StatisticsFormat.count(statistics.pinnedSightingCount)),
                StatisticsMetric(title: "Bilddaten in SQLite", value: StatisticsFormat.bytes(statistics.savedImageDataBytes))
            ])

            Divider()

            VStack(spacing: 8) {
                StatisticsValueRow(title: "SQLite Datenbank", value: StatisticsFormat.bytes(statistics.databaseSizeBytes))
                StatisticsValueRow(title: "SQLite aktiv belegt", value: StatisticsFormat.bytes(statistics.activeDatabaseBytes))
                StatisticsValueRow(title: "SQLite intern frei", value: StatisticsFormat.bytes(statistics.freeDatabaseBytes))
                StatisticsValueRow(title: "WAL/SHM Zusatzdateien", value: StatisticsFormat.bytes(statistics.auxiliarySizeBytes))
                StatisticsValueRow(title: "Komprimierbar", value: StatisticsFormat.bytes(statistics.reclaimableStorageBytes))
                StatisticsValueRow(title: "SQLite Speicher gesamt", value: StatisticsFormat.bytes(statistics.totalStorageBytes), emphasized: true)
            }

            Divider()

            if isCompacting {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Datenbank wird komprimiert")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    onCompact()
                } label: {
                    Label("Datenbank komprimieren", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(statistics.reclaimableStorageBytes <= 0)
            }

            Text("Komprimieren gibt intern freie SQLite-Seiten und WAL-Speicher an iOS zurück.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AppStorageSection: View {
    let storage: AppStorageStatistics

    var body: some View {
        StatisticsSection(title: "App Speicher", systemImage: "folder") {
            VStack(spacing: 8) {
                StatisticsValueRow(title: "App-Daten gesamt", value: StatisticsFormat.bytes(storage.totalBytes), emphasized: true)
                StatisticsValueRow(title: "App-Gruppe", value: StatisticsFormat.bytes(storage.appGroupBytes))
                StatisticsValueRow(title: "Dokumente", value: StatisticsFormat.bytes(storage.documentsBytes))
                StatisticsValueRow(title: "Library ohne Caches", value: StatisticsFormat.bytes(storage.libraryBytes))
                StatisticsValueRow(title: "Caches", value: StatisticsFormat.bytes(storage.cachesBytes))
                StatisticsValueRow(title: "Temp", value: StatisticsFormat.bytes(storage.temporaryBytes))
            }
        }
    }
}

private struct AppStorageLoadingSection: View {
    var body: some View {
        StatisticsSection(title: "App Speicher", systemImage: "folder") {
            HStack(spacing: 10) {
                ProgressView()
                Text("App-Speicher wird analysiert")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DeviceStorageSection: View {
    let storage: DeviceStorageStatistics

    var body: some View {
        StatisticsSection(title: "iPhone Speicher", systemImage: "iphone") {
            StatisticsStorageBar(
                title: "Gerätespeicher",
                usedBytes: storage.usedBytes,
                freeBytes: storage.freeBytes,
                totalBytes: storage.totalBytes,
                tint: .green
            )
        }
    }
}

private struct ImmichStatisticsSection: View {
    let snapshot: ImmichStatisticsSnapshot

    var body: some View {
        StatisticsSection(title: "Immich Server", systemImage: "server.rack") {
            if let storage = snapshot.storage {
                StatisticsStorageBar(
                    title: "Server Speicher",
                    usedBytes: storage.diskUseRaw,
                    freeBytes: storage.diskAvailableRaw,
                    totalBytes: storage.diskSizeRaw,
                    tint: .blue
                )

                Divider()
            }

            if let assetStats = snapshot.assetStats {
                StatisticsMetricGrid(metrics: [
                    StatisticsMetric(title: "Immich Bilder", value: StatisticsFormat.count(assetStats.images)),
                    StatisticsMetric(title: "Immich Videos", value: StatisticsFormat.count(assetStats.videos)),
                    StatisticsMetric(title: "Immich Assets", value: StatisticsFormat.count(assetStats.total))
                ])
            }

            if let serverStats = snapshot.serverStats {
                if snapshot.assetStats != nil {
                    Divider()
                }

                StatisticsMetricGrid(metrics: [
                    StatisticsMetric(title: "Server Fotos", value: StatisticsFormat.count(serverStats.photos)),
                    StatisticsMetric(title: "Server Videos", value: StatisticsFormat.count(serverStats.videos)),
                    StatisticsMetric(title: "Medien Speicher", value: StatisticsFormat.bytes(serverStats.usage)),
                    StatisticsMetric(title: "Foto Speicher", value: StatisticsFormat.bytes(serverStats.usagePhotos)),
                    StatisticsMetric(title: "Video Speicher", value: StatisticsFormat.bytes(serverStats.usageVideos))
                ])

                if !serverStats.usageByUser.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speicher nach Benutzer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        ForEach(serverStats.usageByUser.prefix(5), id: \.userId) { usage in
                            StatisticsValueRow(
                                title: usage.userName.isEmpty ? usage.userId : usage.userName,
                                value: StatisticsFormat.bytes(usage.usage)
                            )
                        }
                    }
                }
            }

            if !snapshot.messages.isEmpty {
                if snapshot.hasServerData {
                    Divider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(snapshot.messages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct StatisticsStorageBar: View {
    let title: String
    let usedBytes: Int64
    let freeBytes: Int64
    let totalBytes: Int64
    let tint: Color

    private var safeTotalBytes: Int64 {
        max(totalBytes, usedBytes + freeBytes)
    }

    private var usedFraction: Double {
        guard safeTotalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(safeTotalBytes), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 12)
                Text(StatisticsFormat.percent(usedFraction))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.secondary.opacity(0.16))

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: proxy.size.width * usedFraction)
                }
            }
            .frame(height: 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("\(StatisticsFormat.percent(usedFraction)) belegt")

            VStack(spacing: 8) {
                StatisticsValueRow(title: "Belegt", value: StatisticsFormat.bytes(usedBytes))
                StatisticsValueRow(title: "Frei", value: StatisticsFormat.bytes(freeBytes))
                StatisticsValueRow(title: "Gesamt", value: StatisticsFormat.bytes(safeTotalBytes), emphasized: true)
            }
        }
    }
}

private struct StatisticsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct StatisticsMetricGrid: View {
    let metrics: [StatisticsMetric]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.value)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(metric.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            }
        }
    }
}

private struct StatisticsMetric: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String {
        title
    }
}

private struct StatisticsValueRow: View {
    let title: String
    let value: String
    var emphasized = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(emphasized ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline.monospacedDigit().weight(emphasized ? .semibold : .regular))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct StatisticsLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Statistik wird geladen")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 28)
    }
}

private enum StatisticsFormat {
    static func count(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func bytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: bytes)
    }

    static func percent(_ fraction: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: fraction)) ?? "0 %"
    }

}

private enum StatisticsDebugLog {
    @discardableResult
    static func start(_ name: String) -> Date {
        let startedAt = Date()
        print("[Statistik] START \(name)")
        return startedAt
    }

    static func finish(_ name: String, since startedAt: Date, detail: String? = nil) {
        let message = "[Statistik] ENDE \(name) nach \(elapsedString(since: startedAt))"
        if let detail, !detail.isEmpty {
            print("\(message) | \(detail)")
        } else {
            print(message)
        }
    }

    static func fail(_ name: String, since startedAt: Date? = nil, error: Error) {
        if let startedAt {
            print("[Statistik] FEHLER \(name) nach \(elapsedString(since: startedAt)) | \(debugMessage(for: error))")
        } else {
            print("[Statistik] FEHLER \(name) | \(debugMessage(for: error))")
        }
    }

    static func skip(_ name: String, detail: String) {
        print("[Statistik] SKIP \(name) | \(detail)")
    }

    private static func elapsedString(since startedAt: Date) -> String {
        let elapsed = Date().timeIntervalSince(startedAt)
        return String(format: "%.3f s", elapsed)
    }

    private static func debugMessage(for error: Error) -> String {
        if let errorResponse = error as? ErrorResponse {
            return errorResponse.debugMessage
        }

        return error.localizedDescription
    }
}

private extension ErrorResponse {
    var debugMessage: String {
        switch self {
        case .error(let code, let data, let response, let underlyingError):
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let body = data
                .flatMap { String(data: $0, encoding: .utf8) }?
                .replacingOccurrences(of: "\n", with: " ")
            var parts = ["code=\(code)"]

            if let statusCode {
                parts.append("status=\(statusCode)")
            }

            if let body, !body.isEmpty {
                parts.append("body=\(body)")
            }

            parts.append("underlying=\(underlyingError.localizedDescription)")
            return parts.joined(separator: " | ")
        }
    }
}

#Preview {
    StatisticsSheetView()
}
