using Apigen.Immich.Models;
using dotAPNS;
using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Linq;

namespace WildLifeBildBot.Core
{

    public class ApnsPushService
    {
        //private readonly string _p8FilePath = "AuthKey_XXXXXX.p8"; // Path to your .p8 key  
        private readonly string _keyId = "XXXXXXXXXX"; // See Apple Developer
        private readonly string _teamId = "XXXXXXXXXX"; //See Apple Developer
        private readonly string _bundleId = "me.XXXXX.XXXXXXXXX";
        private readonly string _deviceToken = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"; // 64-char token from device von Franks Iphone
        //private readonly string _apnsHost = "https://api.push.apple.com";
        public ApnsClient apns = null;

        public ApnsPushService() {

            var options = new ApnsJwtOptions()
            {
                BundleId = _bundleId,
                CertContent = "-----BEGIN PRIVATE KEY-----\r\\xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx+\r\n-----END PRIVATE KEY-----",
                KeyId = _keyId,
                TeamId = _teamId

            };
            apns = ApnsClient.CreateUsingJwt(new HttpClient(), options);

            apns.UseSandbox();
        }

        public async Task SendPushNotificationAsync(string title, string body,string status,AssetMediaResponseDto asset, ILogger<FTPFileConsumerService> logger)
        {
            var iid = "0000";
            if (asset != null)
            {
                iid = asset.Id;
            }
            var push = new ApplePush(ApplePushType.Alert)
            .AddAlert(title, body)
            .AddMutableContent() //bedeutet der NotificationServiceExtension in IOS wird getriggert
            .AddContentAvailable()
            .AddCustomProperty("ImmichID",iid)
            .AddCustomProperty("YoloStatus",status)
            .AddToken(_deviceToken);

            var response = await apns.SendAsync(push);
            if(response.IsSuccessful)
                logger.LogInformation($"APNS Response: Success");
            else
                logger.LogError($"APNS Response: {response.ReasonString}");
        }
    }

}
