//  Copyright © 

import UserNotifications
import UIKit


class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    let client = OpenAPIClientAPIConfiguration.shared
    let fileManager = FileManager.default
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            
            let userInfo = request.content.userInfo;
            if userInfo["ImmichID"] == nil
            {
                contentHandler(bestAttemptContent);
                return;
            }
            
            let status = request.content.userInfo["YoloStatus"] as! String
            let titel = bestAttemptContent.title
            let body = request.content.body
            let iid = request.content.userInfo["ImmichID"] as! String
            let replaced = body.replacingOccurrences(of: "Neue Sichtung ", with: "")
           
            let cameraid = replaced.split(separator: "-").first!
            
            bestAttemptContent.title = "\(bestAttemptContent.title) [\(status)]"
            
            print(userInfo)
            
            DatabaseManager.shared.addSichtung(title: titel,cameraid: String(cameraid), subTitle: "FromNotificationService", body: body, immichid: iid, yolostatus: status, imagebase64: "", creationDate: Date())
            
            // Use a more compatible approach for calling async function
           
         
            

            /*do {
                try buildImageAttachment(request)
            } catch {
                // Assuming you sent a "good enough" notification by default, this should be
                // safe. We can log here to see what's wrong, though...
                print("Unexpected error building attachment! \(error).")
            }*/
            
            contentHandler(bestAttemptContent)
        }
    }
    
    func buildImageAttachment(_ request: UNNotificationRequest) throws {
       
        let iid = request.content.userInfo["ImmichID"] as! String
        let url = URL(string: UserDefaults.standard.string(forKey: "immichurltext")!+"/api/assets/\(iid)/original")
        let attachment = try UNNotificationAttachment(identifier: "", url: url!, options: nil)
        bestAttemptContent?.attachments = [attachment]
    }
    
    /*func storeImmichImage(_ image: UIImage?) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
        let url = directory.appendingPathComponent("tmp.png")
        try image?.pngData()?.write(to: url, options: .atomic)
        
        return url
    }*/
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, 
        // otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    
    
}
