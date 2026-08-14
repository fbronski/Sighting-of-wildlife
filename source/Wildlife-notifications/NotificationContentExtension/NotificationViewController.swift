// Edited by FBRonski
// 20.07.2026


import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var amount: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
    }
    
    func didReceive(_ notification: UNNotification) {
        self.label.text = notification.request.content.title
        self.amount.text = notification.request.content.userInfo["amount"] as? String
    }

    @IBAction func doCustomAction(_ sender: Any) {
        image.isHidden.toggle()
        amount?.isHidden.toggle()
    }
}
