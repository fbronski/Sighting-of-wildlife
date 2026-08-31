// Edited by FBRonski
// 20.07.2026

import SQLite
import Foundation


class DatabaseManager {
    nonisolated(unsafe) static let shared = DatabaseManager()
    private var db: Connection?
    private let sichtung = Table("WildSichtung")
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
        
        do {
            db = try Connection(filepath.path)
            createTable()
        } catch {
            db = nil
            print("Unable to open database. Error: \(error)")
        }
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
            
            try db?.run(sichtung.createIndex(immichid, unique: true))
            try db?.run(sichtung.createIndex(cameraid, unique: false))
        } catch {
            print("Unable to create table. Error: \(error)")
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
        if fileManager.fileExists(atPath: filepath.path) {
            try fileManager.removeItem(at: filepath)
        }
        
        print("Removeing shared App SQlite DB: \(filepath.path)")
        
       
            db = try Connection(filepath.path)
            createTable()
        } catch {
            db = nil
            print("Unable to open database. Error: \(error)")
        }
    }
    
    func addSichtung(title: String,cameraid: String, subTitle: String, body: String, immichid: String, yolostatus: String, imagebase64: String, creationDate: Date) -> Int64? {
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
                let wildsichtung = Wildsichtung(id: ws[id], title: ws[title], subtitle: ws[subTitle], body: ws[body], immichid: ws[immichid], yolostatus: ws[yolostatus], imagebase64: ws[imagebase64], creationDate: ws[creationDate], pinned: ws[pinned])
                wildList.append(wildsichtung)
            }
        } catch {
            print("Select failed. Error: \(error)")
        }
        
        return wildList
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
}
