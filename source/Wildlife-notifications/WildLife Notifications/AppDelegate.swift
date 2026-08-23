//  Copyright © 

import UIKit
//import FirebaseCore
//import FirebaseMessaging


class AppDelegate: NSObject, UIApplicationDelegate {

    public let rootViewModel: RootViewModel = RootViewModel()
    let nc = UNUserNotificationCenter.current()
    var badgeCount = 0
    var isSichtungViewVisible = false

    private let appGroupId = "group.de.unicomedv.WildSichtung"
    private let badgeCountKey = "unreadSichtungNotificationCount"
    private lazy var sharedDefaults = UserDefaults(suiteName: appGroupId) ?? .standard

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("\(#function)\n\(launchOptions ?? [:])")

        UNUserNotificationCenter.current().delegate = self
        setBadgeNumber(storedBadgeCount())
        // Note: intialize firebase before registering to notification
        //FirebaseApp.configure()

        //Messaging.messaging().delegate = self

        application.registerForRemoteNotifications()

        return true
    }


    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("\(#function)\n[\(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())]")
        //Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("\(#function)\n\(error)")
    }


    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any]
    ) async -> UIBackgroundFetchResult {
        print("\(#function)\n\(userInfo)")

        let didStoreNewSichtung = await rootViewModel.notificationReceived(with: userInfo)
        updateBadgeAfterNotification(
            userInfo: userInfo,
            didStoreNewSichtung: didStoreNewSichtung
        )

        return didStoreNewSichtung ? .newData : .noData
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        setBadgeNumber(storedBadgeCount())
        print("App enters foreground")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        let userInfo = notification?.request.content.userInfo ?? [:]
        print("\(#function)\n\(userInfo)")
        rootViewModel.displayConfigSettings()
    }

    @MainActor
    func setSichtungViewVisible(_ isVisible: Bool) {
        isSichtungViewVisible = isVisible
    }

    @MainActor
    func setBadgeNumber(_ number: Int) {
        let sanitizedNumber = max(0, number)
        badgeCount = sanitizedNumber
        sharedDefaults.set(sanitizedNumber, forKey: badgeCountKey)

        if #unavailable(iOS 17.0) {
            UIApplication.shared.applicationIconBadgeNumber = sanitizedNumber
        }

        Task {
            do {
                try await nc.setBadgeCount(sanitizedNumber)
            } catch {
                print("Error setting the badge count: \(error)")
            }
        }
    }

    @MainActor
    private func updateBadgeAfterNotification(
        userInfo: [AnyHashable: Any],
        didStoreNewSichtung: Bool
    ) {
        if let payloadBadgeCount = payloadBadgeCount(from: userInfo) {
            setBadgeNumber(payloadBadgeCount)
            return
        }

        if didStoreNewSichtung {
            setBadgeNumber(storedBadgeCount() + 1)
        } else {
            setBadgeNumber(storedBadgeCount())
        }
    }

    private func storedBadgeCount() -> Int {
        max(0, sharedDefaults.integer(forKey: badgeCountKey))
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
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: @MainActor UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        print("\(#function)\n\(userInfo)")
        let didStoreNewSichtung = await rootViewModel.notificationReceived(with: userInfo)
        updateBadgeAfterNotification(
            userInfo: userInfo,
            didStoreNewSichtung: didStoreNewSichtung
        )

        /// return an array with element to display
        return [.sound, .banner, .badge, .list]
        /// return empty list if no UI needed for notification
        // return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        print("\(#function)\n\(userInfo)")
        let didStoreNewSichtung = await rootViewModel.notificationReceived(with: userInfo)
        updateBadgeAfterNotification(
            userInfo: userInfo,
            didStoreNewSichtung: didStoreNewSichtung
        )

        // Perform the task associated with the action
        switch response.actionIdentifier {
            case "ACCEPT_PAYMENT":
                // proceed with payment accept
                break
            case "DECLINE_PAYMENT":
                // proceed with payment decline
                break
            default:
                break
        }
    }
}

// MARK: - MessagingDelegate
/*extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("\(#function)\nFirebase registration token: \(String(describing: fcmToken))")
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
}*/
