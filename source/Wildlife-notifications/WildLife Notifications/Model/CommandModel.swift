// Edited by FBronski
// 20.07.2026

import Foundation
import Foundation


public class CommandModel: Codable{
    var id: String
    var cmd: String
    var immichid: String
    var text: String
    var creationDate: String
    
    init(id: String,cmd: String,text: String, immichid: String, creationDate: String) {
        self.id = id
        self.cmd = cmd
        self.immichid = immichid
        self.text = text
        self.creationDate = creationDate
    }
    
    func getJsonStringAsBase64() -> String {
        var json = ""
        do{
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(self)
            json = String(data: jsonData, encoding: String.Encoding.utf8)!
        }
        catch {
                print("Error writing file \(error)")
        }
        
        return json.data(using: .utf8)!.base64EncodedString()
    }
}
