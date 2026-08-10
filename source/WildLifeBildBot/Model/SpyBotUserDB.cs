using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

using System.Text;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;
using MongoDB.Driver.Core;
using SQLite.Framework.Attributes;

namespace WildLifeBildBot.Model
{
        

    public class Camera
    {
      
        [ScaffoldColumn(false)]
        [BsonId]
        public string _id { get; set; }

        [ScaffoldColumn(false)]
        public string IMEI { get; set; } //Imei Nummer of Camera

        [ScaffoldColumn(false)]
        public string CameraVersion { get; set; } //Camera Type
        [ScaffoldColumn(false)]

        public string CameraName { get; set; } // this Name ist very imported, the files that are send via FTP chown als follows 1Gh0-SYCR0027.jpg 
        [ScaffoldColumn(false)]
        public string CameraRealName { get; set; } //Der ware Camername User can set it by Telegram Bot command
        [ScaffoldColumn(false)]
        public int GueltigBis { get; set; } //Should in this form 20181231
        [ScaffoldColumn(false)]
        public string ChatId { get; set; } //Channel ID from Telegram wenn vorhanden
        [ScaffoldColumn(false)]
        public string Lastdate { get; set; } //Channel ID from Telegram wenn vorhanden
        [ScaffoldColumn(false)]
        public string Longtitude { get; set; } 
        [ScaffoldColumn(false)]
        public string Latitude { get; set; }
    }
    
    public class User
    {
       
        [ScaffoldColumn(false)]
        [BsonId]
        public string _id { get; set; }
        [ScaffoldColumn(false)]
        public string ChatId { get; set; } 
        [ScaffoldColumn(false)]
        public int Silent { get; set; } //1=Keine Benachrichtigung 0=Benachrichtigung und in Mongospeicheren, 2=Benachrichtigen nicht in MongoS pechern
        [ScaffoldColumn(false)]
        public string RealName { get; set; }
        [ScaffoldColumn(false)]
        public string EmailAdress { get; set; }
        [ScaffoldColumn(false)]
        public DateTime RegisterDateTime { get; set; }
       
        public List<Camera> Cameras { get; set; }

        public List<Friend> Friends { get; set; }
    }

    public class Friend
    {
       
        [ScaffoldColumn(false)]
        [BsonId]
        public string _id { get; set; }
        [ScaffoldColumn(false)]
        public string ChatId { get; set; } 
        [ScaffoldColumn(false)]
        public string RealName { get; set; }
        [ScaffoldColumn(false)]
        public string Email { get; set; }
        [ScaffoldColumn(false)]
        public string Sponsor { get; set; }
        [ScaffoldColumn(false)]
        public int Active { get; set; }
       
    }

    public class BildPost
    {
       
        [ScaffoldColumn(false)] 
        [BsonId]
        public string _id { get; set; }
        [ScaffoldColumn(false)]
        public string BildId { get; set; }
        [ScaffoldColumn(false)]
        public string BildName { get; set; } 
        [ScaffoldColumn(false)]
        public string CameraName { get; set; }
        [ScaffoldColumn(false)]
        public string Content { get; set; }
        [ScaffoldColumn(false)]
        public DateTime UploadTime { get; set; }
        [ScaffoldColumn(false)]
        public long ChatId { get; set; }
        [ScaffoldColumn(false)]
        public string Base64Image { get; set; } //Achtung max 16MB
        [ScaffoldColumn(false)]
        public long Base64ImageLength { get; set; } //Achtung max 16MB


    }

    public class CameraSL
    {

        [Key]
        [AutoIncrement]
        public int _id { get; set; }

        [ScaffoldColumn(false)]
        public string IMEI { get; set; } //Imei Nummer of Camera

        [ScaffoldColumn(false)]
        public string CameraVersion { get; set; } //Firmwareversion
        [ScaffoldColumn(false)]

        public string CameraName { get; set; } // this Name ist very imported, the files that are send via FTP chown als follows 1Gh0-SYCR0027.jpg 
        [ScaffoldColumn(false)]
        public string CameraRealName { get; set; } //Der ware Camername User can set it by Telegram Bot command
        [ScaffoldColumn(false)]
        public int GueltigBis { get; set; } //Should in this form 20181231
        [ScaffoldColumn(false)]
        public string ChatId { get; set; } //Channel ID from Telegram wenn vorhanden
        [ScaffoldColumn(false)]
        public string Lastdate { get; set; } //Channel ID from Telegram wenn vorhanden
        [ScaffoldColumn(false)]
        public string Longtitude { get; set; }
        [ScaffoldColumn(false)]
        public string Latitude { get; set; }
        [ScaffoldColumn(false)]
        public string User { get; set; } //id from user
    }

    public class UserSL
    {
        [Key]
        [AutoIncrement]
        [ScaffoldColumn(false)]
        public int _id { get; set; }
        [ScaffoldColumn(false)]
        public string ChatId { get; set; } //Channel ID from Telegram Unique
        [ScaffoldColumn(false)]
        public int Silent { get; set; } //1=Keine Benachrichtigung 0=Benachrichtigung und in Mongospeicheren, 2=Benachrichtigen nicht in MongoS pechern
        [ScaffoldColumn(false)]
        public string RealName { get; set; }
        [ScaffoldColumn(false)]
        public string EmailAdress { get; set; }
        [ScaffoldColumn(false)]
        public DateTime RegisterDateTime { get; set; }
        //public List<BildPost> BildPosts { get; set; } //Nicht benutzen Dokument kann zu groß werden
    }

    public class FriendSL
    {

        [Key]
        [AutoIncrement]
        [ScaffoldColumn(false)]
        public int _id { get; set; }
        [ScaffoldColumn(false)]
        public string ChatId { get; set; } //Channel ID from Telegram Unique
        [ScaffoldColumn(false)]
        public string RealName { get; set; }
        [ScaffoldColumn(false)]
        public string Email { get; set; }
        [ScaffoldColumn(false)]
        public string Sponsor { get; set; }
        [ScaffoldColumn(false)]
        public int Active { get; set; }
        [ScaffoldColumn(false)]
        public string User { get; set; } //id from user

    }

    public class BildPostSL
    {
        [Key]
        [AutoIncrement]
        [ScaffoldColumn(false)]
        public int _id { get; set; }
        [ScaffoldColumn(false)]
        public string BildId { get; set; }
        [ScaffoldColumn(false)]
        public string BildName { get; set; }
        [ScaffoldColumn(false)]
        public string CameraName { get; set; }
        [ScaffoldColumn(false)]
        public string Content { get; set; }
        [ScaffoldColumn(false)]
        public DateTime UploadTime { get; set; }
        [ScaffoldColumn(false)]
        public long ChatId { get; set; }
        [ScaffoldColumn(false)]
        public string Base64Image { get; set; } //Achtung max 16MB
        [ScaffoldColumn(false)]
        public long Base64ImageLength { get; set; } //Achtung max 16MB
        [ScaffoldColumn(false)]
        public string User { get; set; } //id from user


    }

    public class WIldSichtungCMD
    {
        public string id { get; set; }
        public string cmd { get; set; }
        public string immichid { get; set; }
        public string text { get; set; }
        public string creationDate { get; set; }

    }
}
