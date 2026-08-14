// Edited by FBronski
// 20.07.2026

import Foundation
import UserNotifications
//import FirebaseMessaging
import CoreLocation
import SwiftUI


@Observable
@MainActor
public class RootViewModel: Identifiable  {
    
    var status: UNAuthorizationStatus = .notDetermined
    var requestType: Int = 0

    var notificationTitle: String = ""
    var notificationSubtitle: String = ""
    var notificationBody: String = ""
    var notificationImmichId: String = ""
    var notificationYoloStatus: String = ""
    var customAction: String = ""
    var url = URL(string:  UserDefaults.standard.string(forKey: "immichurltext")!)
    var duration: TimeInterval? = 0
    var draftDuration: DurationValue = .init(hours: 0, minutes: 0, seconds: 0)

    var isPresentingSettings = false
    var networkStatus = "🔘"

    var sichtungen: [Wildsichtung] = []
    
    
    init() {
        Task { await checkStatus() }
        Task { await fetchSichtungen() }
       
       
    }

    
    
    func fetchSichtungen() {
        //DatabaseManager.shared.SyncAllEmptyImageSichtungen()
        sichtungen = DatabaseManager.shared.getAllSichtungen()
        
    }
    
  

    func addSichtung(title: String, cameraid: String, subtitle: String, body: String,immichid: String,yoloStatus: String, imagebase64: String, jetzt: Date){
        let _ = DatabaseManager.shared.addSichtung(title: title,cameraid: cameraid, subTitle: subtitle, body: body, immichid: immichid, yolostatus: yoloStatus, imagebase64: imagebase64, creationDate: jetzt)
        fetchSichtungen()
    }
    
     func deleteSichtung(sichtungId: Int64){
            DatabaseManager.shared.deleteSichtung(sichtungId: sichtungId)
         fetchSichtungen()
        }
    
    nonisolated(nonsending)
    func requestPermission() async {
        let opt1: UNAuthorizationOptions = [.alert, .badge, .sound, .providesAppNotificationSettings]
        let opt2: UNAuthorizationOptions = [.provisional, .providesAppNotificationSettings]
        do {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: requestType == 0 ? opt1 : opt2)
            await checkStatus()
        } catch{
            print(error)
        }
    }

   
    
    func checkStatus() async {
        status = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus
        
        switch status {
        case .authorized:
            print("authorized")
            UserDefaults.standard.set(2,forKey: "notificationIndex")
            
        case .denied:
            print("denied")
            UserDefaults.standard.set(1,forKey: "notificationIndex")
        case .notDetermined:
            print("notDetermined")
            UserDefaults.standard.set(0,forKey: "notificationIndex")
        case .provisional:
            print("provisonal")
            UserDefaults.standard.set(3,forKey: "notificationIndex")
        case .ephemeral:
            UserDefaults.standard.set(4,forKey: "notificationIndex")
        @unknown default: break
        }
    }

    
    func notificationReceived(with payload: [AnyHashable : Any]) async {
        clearFields()
        guard let aps = payload["aps"] as? [AnyHashable : Any],
              let alert = aps["alert"] as? [AnyHashable : Any] else { return }
        notificationTitle = alert["title"] as? String ?? ""
        notificationSubtitle = alert["subtitle"] as? String ?? ""
        notificationBody = alert["body"] as? String ?? ""
        
        if let immichID = payload["ImmichID"] as? String {
            notificationImmichId = immichID
            url = URL(string: UserDefaults.standard.string(forKey: "immichurltext")!+"/photos/\(immichID)")
            debugPrint("Immich ID received \(immichID)")
            
            /*let response =  try? await AssetsAPI.downloadAsset(id: UUID(uuidString: immichID)!, key: nil)
            
           
            let ab = response?.dataRepresentation.base64EncodedString()
            addSichtung(title: notificationTitle, subtitle: notificationSubtitle, body: notificationBody, immichid: immichID, yoloStatus: notificationYoloStatus, imagebase64: ab ?? "")*/
        }
        
        
        
    }

   
    func backgroundTask(with userInfo: [AnyHashable : Any]) {
        clearFields()

        customAction = userInfo["ImmichID"] as? String ?? ""
    }

    /*func subscribeToTopic() async {
        do {
            try await Messaging.messaging().subscribe(toTopic: "payments")
        } catch {
            print("\(#function)\n\(error)")
        }
    }*/

    /*func unsubscribeFromTopic() async {
        do {
            try await Messaging.messaging().unsubscribe(fromTopic: "payments")
        } catch {
            print("\(#function)\n\(error)")
        }
    }*/

   
    /*func sendLocalPush() async {
        let notificationCenter = UNUserNotificationCenter.current()
        let requests = await notificationCenter.pendingNotificationRequests()
        print("\(#function)\nThere are [\(requests.count)] scheduled notifications")

        /*
        // delete scheduled notification
         notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["<notification_id>"]
         )
         */

        /*
        // date/time trigger
        var date = DateComponents()
        date.hour = 10
        date.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
         */


        // interval trigger; fire in 10 sec
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: (10),
            repeats: false
        )

        /*
        // location trigger
        let center = CLLocationCoordinate2D(
            latitude: 56.95342222403206,
            longitude: 24.100736051500316
        )
        let region = CLCircularRegion(
            center: center,
            radius: 100.0,
            identifier: "Headquarters"
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        let trigger = UNLocationNotificationTrigger(
            region: region,
            repeats: false
        )
        */

        let content = UNMutableNotificationContent()
        content.title = "Eingehende Jagd Fotos"
        content.body = "Lärchenkanzel: 02.07.2026 15:21:10"
        content.userInfo = ["category": "PAY_IN"]

        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("\(#function)\n\(error)")
        }
    }*/

    
    func displayConfigSettings() {
        isPresentingSettings = true
    }

    
    func performDummyNetworkRequest() {
        let url = URL(string: UserDefaults.standard.string(forKey: "immichurltext")!)!
        var request = URLRequest(url: url)
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                print("No network, error = \(error)")
                self.networkStatus = "🔴"
            } else {
                print("Network is accessible")
                print(data)
                self.networkStatus = "🟢"
            }
        }
        task.resume()
    }
    
    
}

private extension RootViewModel {

    func clearFields() {
        notificationTitle = ""
        notificationSubtitle = ""
        notificationBody = ""
        customAction = ""
        notificationImmichId = ""
        notificationYoloStatus = ""
       
    }
}
