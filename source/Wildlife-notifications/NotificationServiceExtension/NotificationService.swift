//  Copyright © 

import UserNotifications
import UIKit


class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private let appGroupId = "group.de.unicomedv.WildSichtung"
    private let badgeCountKey = "unreadSichtungNotificationCount"
    private lazy var sharedDefaults = UserDefaults(suiteName: appGroupId) ?? .standard

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo
        guard let immichID = userInfo["ImmichID"] as? String,
              !immichID.isEmpty else {
            contentHandler(bestAttemptContent)
            return
        }

        let status = userInfo["YoloStatus"] as? String ?? ""
        let title = bestAttemptContent.title
        let body = bestAttemptContent.body
        let cameraID = cameraID(from: userInfo, body: body)

        if !status.isEmpty {
            bestAttemptContent.title = "\(title) [\(status)]"
        }

        print(userInfo)

        let didStoreNewSichtung = DatabaseManager.shared.addSichtung(
            title: title,
            cameraid: cameraID,
            subTitle: bestAttemptContent.subtitle,
            body: body,
            immichid: immichID,
            yolostatus: status,
            imagebase64: "",
            creationDate: Date()
        ) != nil

        let badgeCount = payloadBadgeCount(from: userInfo)
            ?? bestAttemptContent.badge.map { max(0, $0.intValue) }
            ?? (didStoreNewSichtung ? incrementStoredBadgeCount() : storedBadgeCount())
        setStoredBadgeCount(badgeCount)
        bestAttemptContent.badge = NSNumber(value: badgeCount)

        contentHandler(bestAttemptContent)
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

    private func cameraID(from userInfo: [AnyHashable: Any], body: String) -> String {
        if let cameraID = (userInfo["cameraid"] as? String) ?? (userInfo["CameraID"] as? String) {
            return cameraID
        }

        let normalizedBody = body.replacingOccurrences(of: "Neue Sichtung ", with: "")
        return normalizedBody
            .split(separator: "-", maxSplits: 1)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
    }

    private func payloadBadgeCount(from userInfo: [AnyHashable: Any]) -> Int? {
        let aps = userInfo["aps"] as? [AnyHashable: Any]
        let badgeValue = aps?["badge"]
            ?? userInfo["badge"]
            ?? userInfo["Badge"]
            ?? userInfo["badgeCount"]
            ?? userInfo["BadgeCount"]

        return badgeCount(from: badgeValue)
    }

    private func badgeCount(from value: Any?) -> Int? {
        if let number = value as? Int {
            return max(0, number)
        }

        if let number = value as? NSNumber {
            return max(0, number.intValue)
        }

        if let string = value as? String,
           let number = Int(string) {
            return max(0, number)
        }

        return nil
    }

    private func incrementStoredBadgeCount() -> Int {
        let nextCount = storedBadgeCount() + 1
        setStoredBadgeCount(nextCount)
        return nextCount
    }

    private func storedBadgeCount() -> Int {
        max(0, sharedDefaults.integer(forKey: badgeCountKey))
    }

    private func setStoredBadgeCount(_ count: Int) {
        sharedDefaults.set(max(0, count), forKey: badgeCountKey)
    }
}
