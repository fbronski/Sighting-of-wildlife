// Edited by FBronski
// 20.07.2026

import SQLite
import Foundation
import Security

enum WebDAVSettingsKeys {
    static let serverURL = "webDAVServerURL"
    static let username = "webDAVUsername"
    static let password = "webDAVPassword"
    static let passkey = "webDAVPasskey"
}

enum BackupError: LocalizedError {
    case appGroupUnavailable
    case databaseUnavailable
    case invalidBackupFile
    case invalidWebDAVURL
    case missingWebDAVCredentials
    case webDAVResponseInvalid
    case webDAVUnexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "Der App-Group-Container ist nicht verfügbar."
        case .databaseUnavailable:
            return "Die lokale Datenbank ist nicht verfügbar."
        case .invalidBackupFile:
            return "Die Backup-Datei ist keine gültige WildSichtung-Datenbank."
        case .invalidWebDAVURL:
            return "Die WebDAV Server-URL ist ungültig."
        case .missingWebDAVCredentials:
            return "WebDAV Server-URL, Benutzername und Passwort/App-Passwort müssen gesetzt sein."
        case .webDAVResponseInvalid:
            return "Die WebDAV Antwort konnte nicht gelesen werden."
        case .webDAVUnexpectedStatus(let statusCode):
            return "Der WebDAV Server hat mit Status \(statusCode) geantwortet."
        }
    }
}

enum SecureValueStore {
    private static var service: String {
        Bundle.main.bundleIdentifier ?? "WildLifeNotifications"
    }

    static func string(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, forKey key: String) {
        guard !value.isEmpty else {
            deleteValue(forKey: key)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8)
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = Data(value.utf8)
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private static func deleteValue(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

private final class WebDAVBackupResponseParser: NSObject, XMLParserDelegate {
    private let baseURL: URL
    private var backups: [WebDAVBackupFile] = []
    private var currentHref = ""
    private var currentDisplayName = ""
    private var currentModifiedDateText = ""
    private var currentContentLengthText = ""
    private var currentElement = ""
    private var isInsideResponse = false

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func parse(_ data: Data) throws -> [WebDAVBackupFile] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw BackupError.webDAVResponseInvalid
        }

        return backups
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = normalizedElementName(elementName)
        currentElement = name

        if name == "response" {
            isInsideResponse = true
            currentHref = ""
            currentDisplayName = ""
            currentModifiedDateText = ""
            currentContentLengthText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideResponse else { return }

        switch currentElement {
        case "href":
            currentHref += string
        case "displayname":
            currentDisplayName += string
        case "getlastmodified":
            currentModifiedDateText += string
        case "getcontentlength":
            currentContentLengthText += string
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = normalizedElementName(elementName)

        if name == "response" {
            appendCurrentBackup()
            isInsideResponse = false
        }

        if currentElement == name {
            currentElement = ""
        }
    }

    private func appendCurrentBackup() {
        let href = currentHref.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remoteURL = url(from: href) else { return }

        let name = currentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = name.isEmpty ? remoteURL.lastPathComponent : name
        guard fileName.hasSuffix(".wildsichtungbackup") else { return }

        let modifiedDateText = currentModifiedDateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentLengthText = currentContentLengthText.trimmingCharacters(in: .whitespacesAndNewlines)

        backups.append(
            WebDAVBackupFile(
                remoteURL: remoteURL,
                name: fileName,
                modifiedDate: Self.httpDateFormatter.date(from: modifiedDateText),
                size: Int64(contentLengthText)
            )
        )
    }

    private func normalizedElementName(_ name: String) -> String {
        if let localName = name.split(separator: ":").last {
            return String(localName).lowercased()
        }

        return name.lowercased()
    }

    private func url(from href: String) -> URL? {
        let decodedHref = href.removingPercentEncoding ?? href

        if let absoluteURL = URL(string: decodedHref),
           absoluteURL.scheme != nil {
            return absoluteURL
        }

        if decodedHref.hasPrefix("/") {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = decodedHref
            components?.query = nil
            components?.fragment = nil
            return components?.url
        }

        return baseURL.appendingPathComponent(decodedHref, isDirectory: false)
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}

struct WebDAVConfiguration: Sendable {
    let baseURL: URL
    let username: String
    let password: String

    static func current() throws -> WebDAVConfiguration {
        let serverURLText = (UserDefaults.standard.string(forKey: WebDAVSettingsKeys.serverURL) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let username = (UserDefaults.standard.string(forKey: WebDAVSettingsKeys.username) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let passkey = SecureValueStore.string(forKey: WebDAVSettingsKeys.passkey) ?? ""
        let password = passkey.isEmpty ? (SecureValueStore.string(forKey: WebDAVSettingsKeys.password) ?? "") : passkey

        guard let rawURL = URL(string: serverURLText),
              let scheme = rawURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              rawURL.host != nil else {
            throw BackupError.invalidWebDAVURL
        }

        guard !username.isEmpty, !password.isEmpty else {
            throw BackupError.missingWebDAVCredentials
        }

        let baseURL: URL
        if rawURL.absoluteString.hasSuffix("/") {
            baseURL = rawURL
        } else {
            baseURL = rawURL.appendingPathComponent("")
        }

        return WebDAVConfiguration(baseURL: baseURL, username: username, password: password)
    }
}

struct WebDAVBackupFile: Identifiable, Hashable, Sendable {
    var id: URL { remoteURL }
    let remoteURL: URL
    let name: String
    let modifiedDate: Date?
    let size: Int64?

    var displayName: String {
        if let modifiedDate {
            return "\(name) - \(modifiedDate.formatted(date: .abbreviated, time: .shortened))"
        }

        return name
    }
}

struct LocalDatabaseStatistics: Equatable, Sendable {
    let databaseSizeBytes: Int64
    let auxiliarySizeBytes: Int64
    let totalStorageBytes: Int64
    let pageSizeBytes: Int64
    let pageCount: Int
    let freePageCount: Int
    let sightingCount: Int
    let cameraCount: Int
    let savedImageDataCount: Int
    let savedImageDataBytes: Int64
    let immichLinkedImageCount: Int
    let pinnedSightingCount: Int

    var activeDatabaseBytes: Int64 {
        let activePageCount = max(pageCount - freePageCount, 0)
        return Int64(activePageCount) * pageSizeBytes
    }

    var freeDatabaseBytes: Int64 {
        Int64(max(freePageCount, 0)) * pageSizeBytes
    }

    var reclaimableStorageBytes: Int64 {
        freeDatabaseBytes + auxiliarySizeBytes
    }
}

typealias WebDAVProgressHandler = @Sendable (Double) -> Void

private final class WebDAVTransferProgressDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    private let progressHandler: WebDAVProgressHandler

    init(progressHandler: @escaping WebDAVProgressHandler) {
        self.progressHandler = progressHandler
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        report(bytesCompleted: totalBytesSent, bytesExpected: totalBytesExpectedToSend)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        report(bytesCompleted: totalBytesWritten, bytesExpected: totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
    }

    private func report(bytesCompleted: Int64, bytesExpected: Int64) {
        guard bytesExpected > 0 else { return }

        let progress = min(max(Double(bytesCompleted) / Double(bytesExpected), 0), 1)
        DispatchQueue.main.async {
            self.progressHandler(progress)
        }
    }
}

struct WebDAVBackupClient: Sendable {
    let configuration: WebDAVConfiguration

    func uploadBackup(from fileURL: URL, progressHandler: WebDAVProgressHandler? = nil) async throws -> URL {
        let remoteURL = configuration.baseURL.appendingPathComponent(fileURL.lastPathComponent, isDirectory: false)
        var request = authorizedRequest(url: remoteURL)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let data = try Data(contentsOf: fileURL)
        let delegate = progressHandler.map { WebDAVTransferProgressDelegate(progressHandler: $0) }
        let (_, response) = try await URLSession.shared.upload(for: request, from: data, delegate: delegate)
        try validate(response: response, allowedStatusCodes: [200, 201, 204])
        return remoteURL
    }

    func listBackups() async throws -> [WebDAVBackupFile] {
        var request = authorizedRequest(url: configuration.baseURL)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <propfind xmlns="DAV:">
            <prop>
                <displayname/>
                <getlastmodified/>
                <getcontentlength/>
            </prop>
        </propfind>
        """.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, allowedStatusCodes: [207])

        let parser = WebDAVBackupResponseParser(baseURL: configuration.baseURL)
        let backups = try parser.parse(data)
            .filter { $0.name.hasSuffix(".wildsichtungbackup") }
            .sorted {
                ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast)
            }

        return backups
    }

    func downloadBackup(_ backup: WebDAVBackupFile, progressHandler: WebDAVProgressHandler? = nil) async throws -> URL {
        var request = authorizedRequest(url: backup.remoteURL)
        request.httpMethod = "GET"

        let delegate = progressHandler.map { WebDAVTransferProgressDelegate(progressHandler: $0) }
        let (downloadedURL, response) = try await URLSession.shared.download(for: request, delegate: delegate)
        try validate(response: response, allowedStatusCodes: [200])

        let targetURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wildsichtungbackup")

        try FileManager.default.moveItem(at: downloadedURL, to: targetURL)
        return targetURL
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        let credential = "\(configuration.username):\(configuration.password)"
        let encodedCredential = Data(credential.utf8).base64EncodedString()
        request.setValue("Basic \(encodedCredential)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(response: URLResponse, allowedStatusCodes: Set<Int>) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackupError.webDAVResponseInvalid
        }

        guard allowedStatusCodes.contains(httpResponse.statusCode) else {
            throw BackupError.webDAVUnexpectedStatus(httpResponse.statusCode)
        }
    }
}

@MainActor
class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection?
    private let sichtung = Table("WildSichtung")
    private let camera = Table("WildsichtungCamera")
    
    //Wildsichtung
    private let id = Expression<Int64>("id")
    private let title = Expression<String>("title")
    private let cameraid = Expression<String>("cameraid")
    private let subTitle = Expression<String>("subtitle")
    private let body = Expression<String>("body")
    private let immichid = Expression<String>("immichid")
    private let yolostatus = Expression<String>("yolostatus")
    private let imagebase64 = Expression<String>("imagebase64")
    private let creationDate = Expression<Date>("creationDate")
    private let pinned = Expression<Bool>("pinned")
    
    //WildsuchtungCamera
    private let CameraRealName = Expression<String>("CameraRealName")
    private let CameraName = Expression<String>("CameraName")
    private let CameraType = Expression<String>("CameraType")
    private let PhoneNumber = Expression<String>("PhoneNumber")
    private let standOrt64 = Expression<String>("standOrt64")

    let appGroupId = "group.de.unicomedv.WildSichtung"
    let fileManager = FileManager.default

    private var databaseFileURL: URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent("WildSichtung.db")
    }
    
    private init() {
        //var filepath = AppDelegate.documentsDirectoryUrl()
        guard let filepath = databaseFileURL else {
            print("Unable to open database. App group is unavailable.")
            return
        }
        
        //try? fileManager.removeItem(at: filepath)
        print("Using shared App Path: \(filepath.path)")
        
        openDatabase(at: filepath)
    }
   
    private func createTable() {
        do {
            try db?.run(sichtung.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(title)
                table.column(cameraid)
                table.column(subTitle)
                table.column(body)
                table.column(immichid)
                table.column(yolostatus)
                table.column(imagebase64)
                table.column(creationDate)
                table.column(pinned)
            })
            try db?.run(camera.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(CameraRealName)
                table.column(CameraName)
                table.column(CameraType)
                table.column(PhoneNumber, defaultValue: "")
                table.column(standOrt64)
                table.column(creationDate)
            })
            migrateCameraTable()
            
            try db?.run(sichtung.createIndex(immichid, unique: true))
            try db?.run(sichtung.createIndex(cameraid, unique: false))
        } catch {
            print("Unable to create table. Error: \(error)")
        }
    }
    
    private func migrateCameraTable() {
        do {
            try db?.run("ALTER TABLE WildsichtungCamera ADD COLUMN PhoneNumber TEXT NOT NULL DEFAULT ''")
        } catch {
            if !error.localizedDescription.lowercased().contains("duplicate column") {
                print("Unable to migrate camera table. Error: \(error)")
            }
        }
    }
    
    func deleteAndCreateNew() {
        guard let filepath = databaseFileURL else {
            db = nil
            print("Unable to open database. App group is unavailable.")
            return
        }

        do {
            db = nil
            try removeDatabaseFiles(at: filepath)

            print("Removeing shared App SQlite DB: \(filepath.path)")
            try openDatabaseOrThrow(at: filepath)
        } catch {
            db = nil
            print("Unable to open database. Error: \(error)")
        }
    }

    func makeBackupFile() throws -> URL {
        try makeBackupFile(filePrefix: "WildSichtung")
    }

    func replaceDatabase(
        withBackupAt backupURL: URL,
        progressHandler: ((Double, String) -> Void)? = nil
    ) throws {
        progressHandler?(0.64, "Backup-Datei wird geprüft")
        try validateBackupFile(at: backupURL)
        guard let databaseURL = databaseFileURL else {
            throw BackupError.appGroupUnavailable
        }

        progressHandler?(0.72, "Sicherheitskopie der lokalen Datenbank wird erstellt")
        let safetyBackupURL = try makeBackupFile(filePrefix: "WildSichtung-before-import")

        do {
            progressHandler?(0.80, "Lokale Datenbank wird ersetzt")
            db = nil
            try removeDatabaseFiles(at: databaseURL)
            try fileManager.copyItem(at: backupURL, to: databaseURL)
            progressHandler?(0.90, "Datenbank wird neu geöffnet")
            try openDatabaseOrThrow(at: databaseURL)
            try? fileManager.removeItem(at: safetyBackupURL)
        } catch {
            progressHandler?(0.86, "Fehler erkannt, lokale Datenbank wird wiederhergestellt")
            db = nil
            try? removeDatabaseFiles(at: databaseURL)

            if fileManager.fileExists(atPath: safetyBackupURL.path) {
                try? fileManager.copyItem(at: safetyBackupURL, to: databaseURL)
                try? fileManager.removeItem(at: safetyBackupURL)
            }

            try? openDatabaseOrThrow(at: databaseURL)
            throw error
        }
    }

    private func makeBackupFile(filePrefix: String) throws -> URL {
        guard let db else {
            throw BackupError.databaseUnavailable
        }

        let backupDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("WildSichtungBackups", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let backupURL = backupDirectory.appendingPathComponent("\(filePrefix)-\(backupTimestamp()).wildsichtungbackup")
        try? fileManager.removeItem(at: backupURL)

        let targetConnection = try Connection(backupURL.path)
        let backup = try db.backup(usingConnection: targetConnection)
        try backup.step()
        try validateBackupFile(at: backupURL)
        return backupURL
    }

    private func backupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: Date())
    }

    private func validateBackupFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw BackupError.invalidBackupFile
        }

        let backupConnection = try Connection(url.path, readonly: true)
        let integrityResult = try backupConnection.scalar("PRAGMA integrity_check") as? String
        guard integrityResult == "ok",
              try databaseTableExists("WildSichtung", in: backupConnection),
              try databaseTableExists("WildsichtungCamera", in: backupConnection) else {
            throw BackupError.invalidBackupFile
        }
    }

    private func databaseTableExists(_ tableName: String, in connection: Connection) throws -> Bool {
        let count = try connection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?",
            tableName
        ) as? Int64
        return count == 1
    }

    private func removeDatabaseFiles(at databaseURL: URL) throws {
        let relatedURLs = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm")
        ]

        for url in relatedURLs where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func openDatabase(at url: URL) {
        do {
            try openDatabaseOrThrow(at: url)
        } catch {
            db = nil
            print("Unable to open database. Error: \(error)")
        }
    }

    private func openDatabaseOrThrow(at url: URL) throws {
        db = try Connection(url.path)
        createTable()
    }
    
    func addCamera(CameraName: String, CameraRealName: String, CameraType: String, PhoneNumber: String = "", standOrt64: String, creationDate: Date)  -> Int64? {
        do {
            let insert = camera.insert(self.CameraName <- CameraName, self.CameraRealName <- CameraRealName, self.CameraType <- CameraType, self.PhoneNumber <- PhoneNumber, self.standOrt64 <- standOrt64, self.creationDate <- creationDate)
            let id = try db?.run(insert)
            return id
        } catch {
            print("Insert failed. Error: \(error)")
            return nil
        }
    }
    
    func addSichtung(title: String,cameraid: String, subTitle: String, body: String, immichid: String, yolostatus: String, imagebase64: String, creationDate: Date)  -> Int64? {
        guard !hasSichtung(immichid: immichid) else {
            return nil
        }

        do {
            let insert = sichtung.insert(self.title <- title,self.cameraid <- cameraid, self.subTitle <- subTitle, self.body <- body, self.immichid <- immichid, self.yolostatus <- yolostatus, self.imagebase64 <- imagebase64, self.creationDate <- creationDate, pinned <- false)
            let id = try db?.run(insert)
            return id
        } catch {
            print("Insert failed. Error: \(error)")
            return nil
        }
    }

    func hasSichtung(immichid: String) -> Bool {
        do {
            return try db?.pluck(sichtung.filter(self.immichid == immichid)) != nil
        } catch {
            print("Select failed. Error: \(error)")
            return false
        }
    }
    
    func updateCamera(id: Int64, CameraName: String, CameraRealName: String, CameraType: String, PhoneNumber: String, standOrt64: String) -> Bool {
        do {
            let update = camera.filter(self.id == id).update(self.CameraName <- CameraName, self.CameraRealName <- CameraRealName, self.CameraType <- CameraType, self.PhoneNumber <- PhoneNumber, self.standOrt64 <- standOrt64)
            try db?.run(update)
            return true
        } catch {
            print("Update failed. Error: \(error)")
            return false
        }
    }
    
    func updateImage(iid: String, imagebase64: String) -> Bool {
        do {
            let update = sichtung.filter(self.immichid == iid).update(self.imagebase64 <- imagebase64)
            try db?.run(update)
            return true
        } catch {
            print("Update failed. Error: \(error)")
            return false
        }
    }
    
    func updatePinned(iid: String, pinned: Bool) -> Bool {
        do {
            let update = sichtung.filter(self.immichid == iid).update(self.pinned <- pinned)
            try db?.run(update)
            return true
        } catch {
            print("Update failed for Pinned. Error: \(error)")
            return false
        }
    }
    
    func getAllSichtungen() -> [Wildsichtung] {
        var wildList = [Wildsichtung]()
        
        do {
            guard let db else {
                return wildList
            }

            for ws in try db.prepare(sichtung.order(creationDate.desc)){
                let wildsichtung = Wildsichtung(id: ws[id], title: ws[title],cameraid: ws[cameraid], subtitle: ws[subTitle], body: ws[body], immichid: ws[immichid], yolostatus: ws[yolostatus], imagebase64: ws[imagebase64], creationDate: ws[creationDate], pinned: ws[pinned])
                wildList.append(wildsichtung)
            }
        } catch {
            print("Select failed. Error: \(error)")
        }
        
        return wildList
    }
    
    func getAllCameras() -> [WildsichtungCamera] {
        var camList = [WildsichtungCamera]()
        
        do {
            guard let db else {
                return camList
            }

            for cs in try db.prepare(camera.order(creationDate.asc)){
                let camera = WildsichtungCamera(id: cs[id], CameraRealName: cs[CameraRealName], CameraName: cs[CameraName], CameraType: cs[CameraType], PhoneNumber: cs[PhoneNumber], standOrt64: cs[standOrt64], creationDate: cs[creationDate])
                camList.append(camera)
            }
        } catch {
            print("Select failed. Error: \(error)")
        }
        
        return camList
    }

    func localStatistics() -> LocalDatabaseStatistics {
        let databaseURL = databaseFileURL
        let databaseSizeBytes = databaseURL.map { fileSize(at: $0) } ?? 0
        let auxiliarySizeBytes = databaseURL.map { databaseAuxiliarySize(for: $0) } ?? 0

        guard let db else {
            return emptyLocalStatistics(
                databaseSizeBytes: databaseSizeBytes,
                auxiliarySizeBytes: auxiliarySizeBytes
            )
        }

        do {
            let pageSizeBytes = try int64Scalar("PRAGMA page_size", in: db)
            let pageCount = try intScalar("PRAGMA page_count", in: db)
            let freePageCount = try intScalar("PRAGMA freelist_count", in: db)
            let sightingCount = try intScalar("SELECT COUNT(*) FROM WildSichtung", in: db)
            let cameraCount = try intScalar("SELECT COUNT(*) FROM WildsichtungCamera", in: db)
            let savedImageDataCount = try intScalar("SELECT COUNT(*) FROM WildSichtung WHERE imagebase64 <> ''", in: db)
            let savedImageDataBytes = try int64Scalar("SELECT COALESCE(SUM(LENGTH(imagebase64)), 0) FROM WildSichtung WHERE imagebase64 <> ''", in: db)
            let immichLinkedImageCount = try intScalar("SELECT COUNT(*) FROM WildSichtung WHERE immichid <> ''", in: db)
            let pinnedSightingCount = try intScalar("SELECT COUNT(*) FROM WildSichtung WHERE pinned = 1", in: db)

            return LocalDatabaseStatistics(
                databaseSizeBytes: databaseSizeBytes,
                auxiliarySizeBytes: auxiliarySizeBytes,
                totalStorageBytes: databaseSizeBytes + auxiliarySizeBytes,
                pageSizeBytes: pageSizeBytes,
                pageCount: pageCount,
                freePageCount: freePageCount,
                sightingCount: sightingCount,
                cameraCount: cameraCount,
                savedImageDataCount: savedImageDataCount,
                savedImageDataBytes: savedImageDataBytes,
                immichLinkedImageCount: immichLinkedImageCount,
                pinnedSightingCount: pinnedSightingCount
            )
        } catch {
            print("Unable to read local statistics. Error: \(error)")
            return emptyLocalStatistics(
                databaseSizeBytes: databaseSizeBytes,
                auxiliarySizeBytes: auxiliarySizeBytes
            )
        }
    }
    
    func IsAnyNotifyPinned() -> Bool {
        do {
            guard let db else {
                return false
            }

            return try db.pluck(sichtung.filter(pinned == true).order(creationDate.desc)) != nil
        } catch {
            print("Select failed. Error: \(error)")
        }
        
        return false
    }
    
    func deleteAllUnPinned(){
        do {
            guard let db else {
                return
            }

            for row in try db.prepare(sichtung.filter(pinned == false)) {
                print("id: \(row[id]), immichid: \(row[immichid]), pinned: \(row[pinned])")
                deleteSichtung(sichtungId: row[id])
               }
            
        } catch {
            print("Select failed. Error: \(error)")
        }
       
    }
    
    func SyncAllEmptyImageSichtungen(){
        do {
            guard let db else {
                return
            }

            for row in try db.prepare("SELECT id, immichid FROM WildSichtung WHERE imagebase64 = ''") {
                   print("id: \(String(describing: row[0])), immichid: \(String(describing: row[1]))")
                   // id: Optional(2), email: Optional("betty@icloud.com")
                   // id: Optional(3), email: Optional("cathy@icloud.com")
               }
            
        } catch {
            print("Select failed. Error: \(error)")
        }
       
    }
    
    
    func deleteSichtung(sichtungId: Int64) {
        do {
            let wildsichtung = sichtung.filter(id == sichtungId)
            try db?.run(wildsichtung.delete())
        } catch {
            print("Delete failed. Error: \(error)")
        }
    }
    
    func deleteCamera(cameraId: Int64) {
        do {
            let camera = self.camera.filter(id == cameraId)
            try db?.run(camera.delete())
        } catch {
            print("Delete failed. Error: \(error)")
        }
    }

    func compactDatabase() throws -> LocalDatabaseStatistics {
        guard let db else {
            throw BackupError.databaseUnavailable
        }

        try db.run("PRAGMA wal_checkpoint(TRUNCATE)")
        try db.run("VACUUM")
        try db.run("PRAGMA optimize")
        return localStatistics()
    }

    private func emptyLocalStatistics(
        databaseSizeBytes: Int64,
        auxiliarySizeBytes: Int64
    ) -> LocalDatabaseStatistics {
        LocalDatabaseStatistics(
            databaseSizeBytes: databaseSizeBytes,
            auxiliarySizeBytes: auxiliarySizeBytes,
            totalStorageBytes: databaseSizeBytes + auxiliarySizeBytes,
            pageSizeBytes: 0,
            pageCount: 0,
            freePageCount: 0,
            sightingCount: 0,
            cameraCount: 0,
            savedImageDataCount: 0,
            savedImageDataBytes: 0,
            immichLinkedImageCount: 0,
            pinnedSightingCount: 0
        )
    }

    private func databaseAuxiliarySize(for databaseURL: URL) -> Int64 {
        let walURL = URL(fileURLWithPath: databaseURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: databaseURL.path + "-shm")
        return fileSize(at: walURL) + fileSize(at: shmURL)
    }

    private func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return 0
        }

        return fileSize.int64Value
    }

    private func intScalar(_ query: String, in db: Connection) throws -> Int {
        Int(try int64Scalar(query, in: db))
    }

    private func int64Scalar(_ query: String, in db: Connection) throws -> Int64 {
        let value = try db.scalar(query)

        if let int64Value = value as? Int64 {
            return int64Value
        }

        if let intValue = value as? Int {
            return Int64(intValue)
        }

        if let numberValue = value as? NSNumber {
            return numberValue.int64Value
        }

        return 0
    }
}
