// Edited by FBronski
// 20.07.2026

import SQLite
import Foundation

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
    
    private init() {
        //var filepath = AppDelegate.documentsDirectoryUrl()
        var filepath = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        filepath = filepath?.appendingPathComponent("WildSichtung.db")
        
        //try? fileManager.removeItem(at: filepath!)
        print("Using shared App Path: \(filepath!.path)")
        
        do {
            db = try Connection(filepath!.path)
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
        do {
        var filepath = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        filepath = filepath?.appendingPathComponent("WildSichtung.db")
        try fileManager.removeItem(at: filepath!)
        
        print("Removeing shared App SQlite DB: \(filepath!.path)")
        
       
            db = try Connection(filepath!.path)
            createTable()
        } catch {
            db = nil
            print("Unable to open database. Error: \(error)")
        }
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
        do {
            let insert = sichtung.insert(self.title <- title,self.cameraid <- cameraid, self.subTitle <- subTitle, self.body <- body, self.immichid <- immichid, self.yolostatus <- yolostatus, self.imagebase64 <- imagebase64, self.creationDate <- creationDate, pinned <- false)
            let id = try db?.run(insert)
            return id
        } catch {
            print("Insert failed. Error: \(error)")
            return nil
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
            for ws in try db!.prepare(sichtung.order(creationDate.desc)){
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
            for cs in try db!.prepare(camera.order(creationDate.asc)){
                let camera = WildsichtungCamera(id: cs[id], CameraRealName: cs[CameraRealName], CameraName: cs[CameraName], CameraType: cs[CameraType], PhoneNumber: cs[PhoneNumber], standOrt64: cs[standOrt64], creationDate: cs[creationDate])
                camList.append(camera)
            }
        } catch {
            print("Select failed. Error: \(error)")
        }
        
        return camList
    }
    
    func IsAnyNotifyPinned() -> Bool {
        var isPinned: Bool = false
        do {
            for ws in try db!.prepare(sichtung.filter(pinned == true).order(creationDate.desc)){
                isPinned = true
            }
        } catch {
            print("Select failed. Error: \(error)")
        }
        
        return isPinned
    }
    
    func deleteAllUnPinned(){
        do {
            for row in try db!.prepare("SELECT id, immichid, pinned FROM WildSichtung WHERE pinned = false") {
                print("id: \(row[0]), immichid: \(row[1]), pinned: \(row[2])")
                deleteSichtung(sichtungId: row[0] as! Int64)
               }
            
        } catch {
            print("Select failed. Error: \(error)")
        }
       
    }
    
    func SyncAllEmptyImageSichtungen(){
        do {
            for row in try db!.prepare("SELECT id, immichid FROM WildSichtung WHERE imagebase64 = ''") {
                   print("id: \(row[0]), immichid: \(row[1])")
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
}

