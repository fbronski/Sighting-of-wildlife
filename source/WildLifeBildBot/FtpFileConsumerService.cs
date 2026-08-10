using Apigen.Immich.Client;
using Apigen.Immich.Models;
using Compunet.YoloSharp;
using Compunet.YoloSharp.Data;
using Compunet.YoloSharp.Plotting;
using WildLifeBildBot.Core;
using WildLifeBildBot.Model;
using Microsoft.Extensions.Options;
using MongoDB.Bson;
using Newtonsoft.Json;
using SharpCompress.IO;
using SixLabors.ImageSharp;
using SkiaSharp;
using System.Net.NetworkInformation;
using System.Text.Json;
using System.Threading.Channels;
using static System.Net.Mime.MediaTypeNames;


namespace WildLifeBildBot
{
    
    public interface IFTPFileConsumerService
    {
        public Task ConsumeFTPImageFileOnMongoDB(string name, string pathToFile, int waitforfinished = 0);
        public Task ConsumeFTPTextFileOnMongoDB(string name, string pathToFile, int waitforfinished = 0);

        public Task ConsumeFTPImageFileOnSqliteDB(string name, string pathToFile, int waitforfinished = 0);
        public Task ConsumeFTPTextFileOnSqliteDB(string name, string pathToFile, int waitforfinished = 0);
    }
  

    public class FTPFileConsumerService : IFTPFileConsumerService
    {
        ILogger<FTPFileConsumerService> _logger;
       
        YoloPredictor? _predictorDefault;
        //YoloPredictor? _predictorWildLife;
        YoloPredictor? _predictorWildLifeSeg;

        List<TagResponseDto> _tagResponses;
        ImmichApiClient _client;


        private byte[] _filebytes { get; set; } = null;
        private string _b64 { get; set; } = null;
        public string mServer = "10.50.5.100:27017,10.50.5.101:27017";
        public string mImmichUserId = "";
        public string mBotHomePath = "";

        public FTPFileConsumerService(ILogger<FTPFileConsumerService> logger)
        {
            var config = new ConfigurationBuilder().AddJsonFile("appsettings.json").Build();
            mBotHomePath = config.GetValue<string>("ApplicationSettings:BotHomePath");
            var apikey = config.GetValue<string>("ApplicationSettings:ImmichApiClientKey");
            var endpoint = config.GetValue<string>("ApplicationSettings:ImmichEndPoint");
            mServer = config.GetValue<string>("ApplicationSettings:MongoServer");
            mImmichUserId = config.GetValue<string>("ApplicationSettings:ImmichUserId");

            string modelDefaultPath = $"{mBotHomePath}/yolo26n.onnx";//"/home/mumpitz/WildLifeBildBot/yolo26n.onnx";  // Update with actual model path
            //string modelWildLifePath = "/home/mumpitz/WildLifeBildBot/Wildlife_Rheinbrohl.onnx";
            string modelWildLifeSegPath = $"{mBotHomePath}/Wildlife_Rheinbrohl_Seg.onnx";//"/home/mumpitz/WildLifeBildBot/Wildlife_Rheinbrohl_Seg.onnx";
            // Load the YOLO predictor

            _predictorWildLifeSeg = new YoloPredictor(modelWildLifeSegPath);
           
            _predictorDefault = new YoloPredictor(modelDefaultPath);

            _client = ImmichApiClient.WithApiKey(apikey, endpoint);
            _tagResponses =  DoGetTagsFromImmich(_client).Result;


            _logger = logger;
           
          
           
        }

        public async Task ConsumeFTPTextFileOnMongoDB(string name, string fullpath, int waitforfinishedsec = 0)
        {
           
             try
                {
                    if (!File.Exists(fullpath))
                        return;

                    _logger.LogInformation($"Starting FTP Image read of {name}");
                    string camid = name.Substring(0, 4); //Die CAM ID hat nur 4 Zeichen und nur groß Buchstaben und zahlen


                    MongoDataLayer<BildPost> cols = new MongoDataLayer<BildPost>(mServer, "UCSpyBildBot");
                   
                    var cam = cols.GetCameraByName(camid);
                   
                   
                        
                    if (cam == null)
                    {
                        _logger.LogWarning($"Keine Camera mit dem namen {camid} in file ");
                        if (!camid.Equals("XXXX"))
                            return;
                    }

                    FileInfo incomingftpfile = new FileInfo(fullpath);
                    _logger.LogWarning($"WildLifeBildBot Command darf nicht leer sein");
                    string trashpath = Path.GetDirectoryName(fullpath) + $"/trash/{incomingftpfile.Name}";


                    var version = await _client.Server.GetServerVersionAsync();
                    _logger.LogInformation($"Immich is available in Version {version} Send {name} to Immich");

                    var b64 = File.ReadAllText(fullpath);
                    var json = Convert.FromBase64String(b64);
                    var cmd = System.Text.Json.JsonSerializer.Deserialize<WIldSichtungCMD>(json);

                    if (cmd == null)
                    {
                        _logger.LogError($"Error in ConsumeFTPTextFile no JSON inside FTP Text found");


                        incomingftpfile.MoveTo(trashpath);
                        return;
                    }

                    if (String.IsNullOrEmpty(cmd.cmd))
                    {

                        incomingftpfile.MoveTo(trashpath);
                        return;
                    }


                    incomingftpfile.MoveTo(trashpath);

                    if (cmd.cmd.Equals("GetPLOT"))
                    {
                        _logger.LogInformation($"GetPLOT Command gefunden in ImmichID:{cmd.immichid} Text:{cmd.text}");
                        var tags = cmd.text.Split(' ');
                        var bp = cols.GetBildPost(tags[0]);

                        if (bp == null)
                        {
                            _logger.LogError($"No BildPost found for Text:{cmd.text}");
                            return;
                        }

                        var bytes = Convert.FromBase64String(bp.Base64Image);

                        if (_predictorWildLifeSeg == null)
                        {
                            _logger.LogError("No YOLO Predictor");
                            return;
                        }

                        var tmpimgpath = $"{mBotHomePath}/tmpimage.jpg";
                        var plotimgpath = $"{mBotHomePath}/{tags[0]}_P.jpg";
                        File.WriteAllBytes(tmpimgpath, bytes);
                        FileInfo tempimagefile = new FileInfo(tmpimgpath);
                        FileInfo plottimagefile = new FileInfo(plotimgpath);
                        var bildid = cam.CameraName + "-" + DateTime.Now.ToString("yyyyddMMHHmmss");


                        var result = await _predictorWildLifeSeg.PredictAndSaveAsync(tmpimgpath, plotimgpath);

                        var album = await CheckCameraAndDate(cols, _client, bp);
                        var asset = await DoPostBildPostToImmich(_client, plotimgpath, cam.CameraName, bildid, plottimagefile.Name);

                        await DoTagBildInImmich(_client, asset, _tagResponses.FirstOrDefault(c => c.Name == "Plotted"));
                        await DoTagBildInImmich(_client, asset, _tagResponses.FirstOrDefault(c => c.Name == cam.CameraRealName));

                        await DoAssetToAlbum(_client, album, asset);

                        if (asset != null)
                        {

                            _logger.LogInformation("Try to send Notify To Apple");
                            await SendAPNShNotifiction(cam.CameraRealName, $"Plotted Image {bp.BildId} {bp.UploadTime}", result.ToString(), asset);

                            if (tempimagefile.Exists)
                                tempimagefile.Delete();

                            if (plottimagefile.Exists)
                                plottimagefile.Delete();


                        }

                        if (incomingftpfile.Exists)
                            incomingftpfile.Delete();
                    }
                    else if (cmd.cmd.Equals("SyncCameras"))
                    {
                        _logger.LogInformation($"SyncCameras Command gefunden Text:{cmd.text}");
                        if (incomingftpfile.Exists)
                            incomingftpfile.Delete();
                    }
                    else
                    {
                        _logger.LogWarning($"No WildLifeBildBot Command in ConsumeFTPTextFile gefunden");

                        return;
                    }

                }
                catch (Exception ex)
                {
                    _logger.LogCritical($"Error in ConsumeFTPTextFileOnMongoDB {ex.Message} Trace: {ex.StackTrace}");

                }
          
            _logger.LogInformation($"Completed FTP Image read of {fullpath}");
        }

        public async Task ConsumeFTPImageFileOnMongoDB(string name, string fullpath, int waitforfinishedsec=0)
        {
            try { 
                if (!File.Exists(fullpath))
                    return;

                _logger.LogInformation($"Starting FTP Image read of {name}");
                string camid = name.Substring(0, 4);
                TagResponseDto tag = null;
                MongoDataLayer<BildPost> cols = new MongoDataLayer<BildPost>(mServer, "UCSpyBildBot");
               
                var cam = cols.GetCameraByName( camid);
           
                if(cam == null)
                {
                    _logger.LogWarning($"Keine Camera mit dem namen {camid} in file ");
                    return;
                }

                // 201931030855
                string readabletimestamp = DateTime.Now.ToString("dd.MM.yyyy-HH:mm:ss"); // 201931030855
                FileInfo incomingftpfile = new FileInfo(fullpath);

           

                if(waitforfinishedsec > 0)
                    await Task.Delay(TimeSpan.FromSeconds(waitforfinishedsec));

                var status = await DetectSegYolo(fullpath);
                if (status.Equals("leer"))
                {
                    _logger.LogWarning($"YOLO could not Classify inside the Image:{incomingftpfile.Name} try now with detection on yolo26n");

                    status = await DetectYolo(fullpath);

                    if (status.Equals("leer"))
                    {
                        string trashpath = Path.GetDirectoryName(fullpath) + $"/trash/{incomingftpfile.Name}";
                        incomingftpfile.MoveTo(trashpath);
                        return;
                    }
                  
                }
              
                if(status.Contains("1 bench") || status.Contains("1 boat"))
                {
                    _logger.LogWarning($"YOLO Status of 1 Bench seems to be a Kirrkiste in:{incomingftpfile.Name} we move to trash");
                    string trashpath = Path.GetDirectoryName(fullpath) + $"/trash/{incomingftpfile.Name}";
                    incomingftpfile.MoveTo(trashpath);
                    return;
                }

                if (status.Contains("person"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Person");
                    if (_tagResponses != null)
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Person");


                }
                else if (status.Contains("Rehwild"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Rehwild");
                    if (_tagResponses != null)
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Rehwild");
                }
                else if (status.Contains("Rotwild"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Rotwild");
                    if (_tagResponses != null)
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Rotwild");
                }
                else if (status.Contains("Rothirsch"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Rothirsch");
                    if (_tagResponses != null)
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Rothirsch");
                }
                else if (status.Contains("Schwarzwild"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Schwarzwild");
                    if (_tagResponses != null)
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Schwarzwild");
                }
                else if (status.Contains("Fuchs"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Fuchs");
                    if (_tagResponses != null)
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Fuchs");
                }
                else if (status.Contains("Kalb"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Wildkalb");
                    if (_tagResponses != null)
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Wildkalb");
                }
                else if (status.Contains("bird"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Vogel");
                    if (_tagResponses != null)
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Vogel");
                }

                using (MemoryStream fs = await AddTextToImage(cam.CameraRealName,readabletimestamp,fullpath))
                {
                    try
                    {
                        _filebytes = fs.ToArray();
                   
                   
                        _b64 = Convert.ToBase64String(_filebytes);
                    

                        //fs.Close();

                        _logger.LogInformation($"Save {name} to MongoDB"); //Fbronski
                        string bildstamp = DateTime.Now.ToString("yyyyddMMHHmmss");
                        BildPost bp = new BildPost();
                        bp._id = ObjectId.GenerateNewId().ToString();
                        bp.ChatId = 0; //Convert.ToInt64(auth.ChatId); es gibt keine chatid mehr
                        bp.CameraName = cam.CameraName;
                        bp.BildId = cam.CameraName + "-" + bildstamp;//Guid.NewGuid().ToString("N"); z.B AGFI-201930031905
                        bp.BildName = name;
                        bp.UploadTime = DateTime.Now;
                        bp.Content = "Upload per FTP durch Camera:" + cam.CameraName + " für Benutzer:FBronski";
                        bp.Base64ImageLength = incomingftpfile.Length;
                        bp.Base64Image = _b64;

                  
                        await cols.Save(bp);
                        
                   
                        var album = await CheckCameraAndDate(cols, _client, bp);
                        var asset = await DoPostBildPostToImmich(_client, bp);
                        if (tag != null)
                        {
                            await DoTagBildInImmich(_client, asset, tag);
                            await DoTagBildInImmich(_client, asset, _tagResponses.FirstOrDefault(c => c.Name == cam.CameraRealName));
                        }

                        await DoAssetToAlbum(_client, album, asset);

                        if (asset != null)
                        {
                        
                            _logger.LogInformation("Try to send Notify To Apple");
                            await SendAPNShNotifiction(cam.CameraRealName, $"Neue Sichtung {bp.BildId} {bp.UploadTime}",status,asset);

                            if (incomingftpfile.Exists)
                                incomingftpfile.Delete();


                        }
                    }
                    catch (Exception ex)
                    {
                       
                        _logger.LogCritical("Add Text to Image Exception: on File->" + fullpath + ":" + ex.Message.ToString());
                  
                    }
             
                }
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"ConsumeFTPImageFileOnMongoDB: Error in ConsumeFTPImageFileOnSqliteDB {ex.Message} Trace: {ex.StackTrace}");

            }

            _logger.LogInformation($"Completed FTP Image read of {fullpath}");
        }

        public async Task ConsumeFTPTextFileOnSqliteDB(string name, string fullpath, int waitforfinishedsec = 0)
        {

            try
            {
                if (!File.Exists(fullpath))
                    return;

                _logger.LogInformation($"Starting FTP Image read of {name}");
                string camid = name.Substring(0, 4);

                SqlLiteDataLayer<BildPostSL> cols = new SqlLiteDataLayer<BildPostSL>("UCSpyBildBot");

                var cam = cols.GetCameraByName(camid);
                

                if (cam == null)
                {
                    _logger.LogWarning($"Keine Camera mit dem namen {camid} in file ");
                    if (!camid.Equals("XXXX"))
                        return;
                }

                FileInfo incomingftpfile = new FileInfo(fullpath);
                _logger.LogWarning($"WildLifeBildBot Command darf nicht leer sein");
                string trashpath = Path.GetDirectoryName(fullpath) + $"/trash/{incomingftpfile.Name}";


                var version = await _client.Server.GetServerVersionAsync();
                _logger.LogInformation($"Immich is available in Version {version} Send {name} to Immich");

                var b64 = File.ReadAllText(fullpath);
                var json = Convert.FromBase64String(b64);
                var cmd = System.Text.Json.JsonSerializer.Deserialize<WIldSichtungCMD>(json);

                if (cmd == null)
                {
                    _logger.LogError($"Error in ConsumeFTPTextFile no JSON inside FTP Text found");


                    incomingftpfile.MoveTo(trashpath);
                    return;
                }

                if (String.IsNullOrEmpty(cmd.cmd))
                {

                    incomingftpfile.MoveTo(trashpath);
                    return;
                }


                incomingftpfile.MoveTo(trashpath);

                if (cmd.cmd.Equals("GetPLOT"))
                {
                    _logger.LogInformation($"GetPLOT Command gefunden in ImmichID:{cmd.immichid} Text:{cmd.text}");
                    var tags = cmd.text.Split(' ');

                    //Inder sqliteDB gibt es keine Bilder
                    var bp = cols.GetBildPost(tags[0]);
                    var bytes = await DoGetBildBytesFromImmich(_client, cmd.immichid);
                   

                    if (bytes == null)
                    {
                        _logger.LogError($"No Immich found for IID:{cmd.immichid}");
                        return;
                    }

                 

                    if (_predictorWildLifeSeg == null)
                    {
                        _logger.LogError("No YOLO Predictor");
                        return;
                    }

                    var tmpimgpath = $"{mBotHomePath}/tmpimage.jpg";
                    var plotimgpath = $"{mBotHomePath}/{tags[0]}_P.jpg";
                    File.WriteAllBytes(tmpimgpath, bytes);
                    FileInfo tempimagefile = new FileInfo(tmpimgpath);
                    FileInfo plottimagefile = new FileInfo(plotimgpath);
                    var bildid = cam.CameraName + "-" + DateTime.Now.ToString("yyyyddMMHHmmss");


                    var result = await _predictorWildLifeSeg.PredictAndSaveAsync(tmpimgpath, plotimgpath);

                    var album = await CheckCameraAndDate(cols, _client, bp);
                    var asset = await DoPostBildPostToImmich(_client, plotimgpath, cam.CameraName, bildid, plottimagefile.Name);

                    await DoTagBildInImmich(_client, asset, _tagResponses.FirstOrDefault(c => c.Name == "Plotted"));
                    await DoTagBildInImmich(_client, asset, _tagResponses.FirstOrDefault(c => c.Name == cam.CameraRealName));

                    await DoAssetToAlbum(_client, album, asset);

                    if (asset != null)
                    {

                        _logger.LogInformation("Try to send Notify To Apple");
                        await SendAPNShNotifiction(cam.CameraRealName, $"Plotted Image {bp.BildId} {bp.UploadTime}", result.ToString(), asset);

                        if (tempimagefile.Exists)
                            tempimagefile.Delete();

                        if (plottimagefile.Exists)
                            plottimagefile.Delete();


                    }

                    if (incomingftpfile.Exists)
                        incomingftpfile.Delete();

                } else if(cmd.cmd.Equals("SyncCameras")){
                    _logger.LogInformation($"SyncCameras Command gefunden Text:{cmd.text}");

                    await cols.DeleteTableCameraAndCreateNew();

                    dynamic dynJson = JsonConvert.DeserializeObject(cmd.text);
                    foreach (var item in dynJson)
                    {
                        _logger.LogInformation($"{item.cameraRealName}, {item.cameraName}");
                        var newcam = new CameraSL();
                        newcam.CameraName = item.cameraName;
                        newcam.CameraVersion = item.cameraType;
                        newcam.CameraRealName = item.cameraRealName;
                        newcam.Lastdate = item.creationDate;
                        newcam.IMEI = "";
                        newcam.Latitude = "";
                        newcam.Longtitude = "";
                        newcam.ChatId = "";
                        newcam.GueltigBis = 0;
                        newcam.User = "";

                        await cols.Save(newcam);
                    }

                    await SendAPNShNotifiction(camid, $"Sync Kameras finished", "success", null);

                    if (incomingftpfile.Exists)
                        incomingftpfile.Delete();
                }
                else
                {
                    _logger.LogWarning($"No WildLifeBildBot Command in ConsumeFTPTextFile gefunden");

                    return;
                }
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in ConsumeFTPTextFileOnSqliteDB {ex.Message} Trace: {ex.StackTrace}");

            }

            _logger.LogInformation($"Completed FTP Image read of {fullpath}");
        }

        public async Task ConsumeFTPImageFileOnSqliteDB(string name, string fullpath, int waitforfinishedsec = 0)
        {
            try { 
                if (!File.Exists(fullpath))
                    return;

                _logger.LogInformation($"Starting FTP Image read of {name}");
                string camid = name.Substring(0, 4);
                TagResponseDto tag = null;
                SqlLiteDataLayer<BildPostSL> cols = new SqlLiteDataLayer<BildPostSL>("UCSpyBildBot");
                var cam = cols.GetCameraByName(camid);

                if (cam == null)
                {
                    _logger.LogWarning($"Keine Camera mit dem namen {camid} in file ");
                    return;
                }

                // 201931030855
                string readabletimestamp = DateTime.Now.ToString("dd.MM.yyyy-HH:mm:ss"); // 201931030855
                FileInfo incomingftpfile = new FileInfo(fullpath);


                if (waitforfinishedsec > 0)
                    await Task.Delay(TimeSpan.FromSeconds(waitforfinishedsec));

                var status = await DetectSegYolo(fullpath);
                if (status.Equals("leer"))
                {
                    _logger.LogWarning($"YOLO could not Classify inside the Image:{incomingftpfile.Name} try now with detection on yolo26n");

                    status = await DetectYolo(fullpath);

                    if (status.Equals("leer"))
                    {
                        string trashpath = Path.GetDirectoryName(fullpath) + $"/trash/{incomingftpfile.Name}";
                        incomingftpfile.MoveTo(trashpath);
                        return;
                    }

                }

                if (status.Contains("1 bench") || status.Contains("1 boat"))
                {
                    _logger.LogWarning($"YOLO Status of 1 Bench seems to be a Kirrkiste in:{incomingftpfile.Name} we move to trash");
                    string trashpath = Path.GetDirectoryName(fullpath) + $"/trash/{incomingftpfile.Name}";
                    incomingftpfile.MoveTo(trashpath);
                    return;
                }

                if (status.Contains("person"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Person");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Person");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Person");
                    }


                }
                else if (status.Contains("Rehwild"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Rehwild");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Rehwild");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Rehwild");
                    }
                }
                else if (status.Contains("Rotwild"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Rotwild");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Rotwild");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Rotwild");
                    }
                }
                else if (status.Contains("Rothirsch"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Rothirsch");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Rothirsch");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Rothirsch");
                    }
                }
                else if (status.Contains("Schwarzwild"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Schwarzwild");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Schwarzwild");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Schwarzwild");
                    }
                }
                else if (status.Contains("Fuchs"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Fuchs");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Fuchs");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Fuchs");
                    }
                }
                else if (status.Contains("Kalb"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Wildkalb");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Wildkalb");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Wildkalb");
                    }
                }
                else if (status.Contains("bird"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Vogel");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Vogel");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Vogel");
                    }
                }
                else if (status.Contains("Damwild"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Damwild");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Damwild");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Damwild");
                    }
                }
                else if (status.Contains("Dachs"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Dachs");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Dachs");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Dachs");
                    }
                }
                else if (status.Contains("Waschbär"))
                {
                    _logger.LogWarning($"Tagging Image in:{incomingftpfile.Name} with Waschbär");
                    if (_tagResponses != null)
                    {
                        tag = _tagResponses.FirstOrDefault(c => c.Name == "Waschbär");
                        if (tag == null)
                            tag = await DoCreateImmichTag(_client, "Damwild");
                    }
                }

                using (MemoryStream fs = await AddTextToImage(cam.CameraRealName, readabletimestamp, fullpath))
                {
                    try
                    {
                        _filebytes = fs.ToArray();


                        _b64 = Convert.ToBase64String(_filebytes);


                        //fs.Close();

                        _logger.LogInformation($"Save {name} to MongoDB"); //Frank Hausmann");
                        string bildstamp = DateTime.Now.ToString("yyyyddMMHHmmss");
                        BildPostSL bp = new BildPostSL();
                        //bp._id = ObjectId.GenerateNewId().ToString();
                        bp.ChatId = 0; //Convert.ToInt64(auth.ChatId); es gibt keine chatid mehr
                        bp.CameraName = cam.CameraName;
                        bp.BildId = cam.CameraName + "-" + bildstamp;//Guid.NewGuid().ToString("N"); z.B AGFI-201930031905
                        bp.BildName = name;
                        bp.UploadTime = DateTime.Now;
                        bp.Content = "Upload per FTP durch Camera:" + cam.CameraName + " für Benutzer:FBronski";
                        bp.Base64ImageLength = incomingftpfile.Length;
                        bp.Base64Image = "";
                        bp.User = "";
                       


                        await cols.Save(bp);

                        bp.Base64Image = _b64; //Do not store Fotos in SqliteDB

                        var album = await CheckCameraAndDate(cols, _client, bp);
                        var asset = await DoPostBildPostToImmich(_client, bp);
                        if (tag != null)
                        {
                            await DoTagBildInImmich(_client, asset, tag);
                            var camtag = _tagResponses.FirstOrDefault(c => c.Name == cam.CameraRealName);
                            if (camtag == null) {
                                camtag = await DoCreateImmichTag(_client, cam.CameraRealName, "0xdea01b");
                            }
                            await DoTagBildInImmich(_client, asset,camtag );
                        }

                        await DoAssetToAlbum(_client, album, asset);

                        if (asset != null)
                        {

                            _logger.LogInformation("Try to send Notify To Apple");
                            await SendAPNShNotifiction(cam.CameraRealName, $"Neue Sichtung {bp.BildId} {bp.UploadTime}", status, asset);

                            if (incomingftpfile.Exists)
                                incomingftpfile.Delete();


                        }
                    }
                    catch (Exception ex)
                    {
                       
                        _logger.LogCritical("Add Text to Image Exception: on File->" + fullpath + ":" + ex.Message.ToString());

                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in ConsumeFTPImageFileOnSqliteDB {ex.Message} Trace: {ex.StackTrace}");

            }

            _logger.LogInformation($"Completed FTP Image read of {fullpath}");
        }
        public byte[]? GetFileBytes() { return _filebytes; }
        public string? GetFileBase64() { return _b64; }
        public byte[] ReadToEnd(System.IO.Stream stream)
        {
            long originalPosition = 0;

            if (stream.CanSeek)
            {
                originalPosition = stream.Position;
                stream.Position = 0;
            }

            try
            {
                byte[] readBuffer = new byte[4096];

                int totalBytesRead = 0;
                int bytesRead;

                while ((bytesRead = stream.Read(readBuffer, totalBytesRead, readBuffer.Length - totalBytesRead)) > 0)
                {
                    totalBytesRead += bytesRead;

                    if (totalBytesRead == readBuffer.Length)
                    {
                        int nextByte = stream.ReadByte();
                        if (nextByte != -1)
                        {
                            byte[] temp = new byte[readBuffer.Length * 2];
                            Buffer.BlockCopy(readBuffer, 0, temp, 0, readBuffer.Length);
                            Buffer.SetByte(temp, totalBytesRead, (byte)nextByte);
                            readBuffer = temp;
                            totalBytesRead++;
                        }
                    }
                }

                byte[] buffer = readBuffer;
                if (readBuffer.Length != totalBytesRead)
                {
                    buffer = new byte[totalBytesRead];
                    Buffer.BlockCopy(readBuffer, 0, buffer, 0, totalBytesRead);
                }
                return buffer;
            }
            finally
            {
                if (stream.CanSeek)
                {
                    stream.Position = originalPosition;
                }
            }
        }

        public async Task<MemoryStream> AddTextToImage(string titel,string body, string fullpath)
        {
            try
            {


                byte[] filebytes = null;
                using (MemoryStream ms = new MemoryStream())
                {

                    var oriImage = SKImage.FromEncodedData(fullpath);



                    using SKBitmap newbmp = new(oriImage.Width, oriImage.Height+80);//The original has 640x480
                    using SKCanvas canvas = new(newbmp);

                 
                    canvas.DrawImage(oriImage, new SKPoint(0, 0));
                    using SKPaint p1 = new() { Color = new SKColor(0x1e, 0x1e, 0x1e) };
                    canvas.DrawRect(0, oriImage.Height, oriImage.Width, 80, p1);
                    // draw left-aligned text, solid
                    using (var f4 = new SKFont { Size = 40.0f })
                    using (var f3 = new SKFont { Size = 30.0f })
                    using (var paint = new SKPaint())
                    {
                        paint.IsAntialias = true;
                        paint.Color = new SKColor(0xf1, 0xe5, 0xf5);
                        paint.IsStroke = false;

                        canvas.DrawText(titel, 20, oriImage.Height+35, SKTextAlign.Left, f4, paint);
                        canvas.DrawText(body, 20, oriImage.Height+70, SKTextAlign.Left, f3, paint);
                    }

                    newbmp.Encode(ms, SKEncodedImageFormat.Jpeg,100);
                    ms.Position = 0;
                    return ms;
                }
              
                
             

            } 
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in AddTextToImage {ex.Message} Trace: {ex.StackTrace}");

            }

            return null;
        }

       /* public async Task<string> ClassifyYolo(string imagepath)
        {
            try
            {
                if (_predictorWildLife == null)
                    return "unbekanntWildLife";

              

                var result = await _predictorWildLife.ClassifyAsync(imagepath);
                if (result.Count == 0)
                { //Ist wahrscheinlich leer
                   

                    _logger.LogWarning($"YoloSharp Classify has no result on Image:{imagepath} result:{result} try Detect step default");
                    return "leer";

                }
                else
                {
                    var classifiedstr = result.ToString();
                    string output = classifiedstr.Split('(', ')')[1];  //Rehwild(37 %)
                    output = output.Replace(" ", "");
                    output = output.Replace("%", "");
                    var percent = Convert.ToInt16(output);

                    if (percent < 75)
                    {
                        _logger.LogInformation($"YoloSharp  Classification has {percent} % to get a real classification we need a minimum of 75%  for Image:{imagepath} result:{classifiedstr}");
                        return "leer";
                    }

                    _logger.LogInformation($"YoloSharp 1st Step Classification success for Image:{imagepath} result:{classifiedstr}");
                    return result.ToString();
                }




                // Write result summary to terminal

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in public static async Task ClassifyYolo()\r\n {ex.Message}");
                return "leer";
            }

        }*/

        public async Task<string> DetectYolo(string imagepath)
        {
            try
            {
             

                if (_predictorDefault == null)
                    return "unbekanntDefault";

              
                    var result = await _predictorDefault.DetectAsync(imagepath);
                    if (result.Count == 0)
                    {
                        _logger.LogWarning($"YoloSharp 2st detection has no result on Image:{imagepath} result:{result}");
                        return "leer";
                    }
                    else
                    {
                        _logger.LogInformation($"YoloSharp 2st Step success for Image:{imagepath} result:{result.ToString()}");

                        
                        return result.ToString();
                    }

               



                // Write result summary to terminal

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in public static async Task DetectYolo()\r\n {ex.Message}");
                return "unbekannt";
            }

        }

        public async Task<string> DetectSegYolo(string imagepath)
        {
            try
            {


                if (_predictorWildLifeSeg == null)
                    return "unbekanntDefault";


                var result = await _predictorWildLifeSeg.SegmentAsync(imagepath); // _predictorW t.DetectAsync(imagepath);
                if (result.Count == 0)
                {
                    _logger.LogWarning($"YoloSharp 1st SEGMENTATION has no result on Image:{imagepath} result:{result}");
                    return "leer";
                }
                else
                {
                    _logger.LogInformation($"YoloSharp 1st Step SEGMENTATION success for Image:{imagepath} result:{result.ToString()}");


                    return result.ToString();
                }





                // Write result summary to terminal

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in public static async Task DetectSegYolo()\r\n {ex.Message}");
                return "unbekannt";
            }

        }

        public async Task<List<TagResponseDto>> DoGetTagsFromImmich(ImmichApiClient cl)
        {
            try
            {

                var result = await cl.Tags.GetAllTagsAsync();
                

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in DoPostBildPostToImmich {ex.Message}");

            }

            return null;
        }

        public async Task<TagResponseDto> DoCreateImmichTag(ImmichApiClient cl, string tagname, string color= "0x1b91de")
        {
            try
            {

                var bd = new TagCreateDto();
                bd.Color = color;
                bd.Name = tagname;
               

                var result = await cl.Tags.CreateAsync(bd);
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in DoTagBildInImmich {ex.Message}->{ex.StackTrace}");

            }

            return null;
        }
        public async Task<List<BulkIdResponseDto>> DoTagBildInImmich(ImmichApiClient cl, AssetMediaResponseDto asset, TagResponseDto tag )
        {
            try
            {

                var bd = new BulkIdsDto();
                bd.Ids = new List<Guid>();
                Guid gs = new Guid(asset.Id);
                bd.Ids.Add(gs);

                var result = await cl.Tags.TagAssetsAsync(tag.Id, bd);
              return result;
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in DoTagBildInImmich {ex.Message}->{ex.StackTrace}");

            }

            return null;
        }

        public async Task<AssetMediaResponseDto> DoPostBildPostToImmich(ImmichApiClient cl, string plottedimgpath, string camname, string bildid, string bildname)
        {
            try
            {
                var _filebytes = File.ReadAllBytes(plottedimgpath);
                var dt = DateTime.Now;

                var _b64 = Convert.ToBase64String(_filebytes);
                var asset = new AssetMediaCreateDto();
                var b64 = Convert.FromBase64String(_b64);
                asset.AssetData = b64;
                asset.DeviceId = camname;
                asset.DeviceAssetId = bildid;
                asset.FileCreatedAt = dt;
                asset.FileModifiedAt =dt;
                asset.Filename = bildname;
                var result = await cl.Assets.UploadAssetAsync(asset);

                return result;

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in DoPostBildPostToImmich {ex.Message}");

            }

            return null;
        }

        public async Task<byte[]> DoGetBildBytesFromImmich(ImmichApiClient cl, string iid)
        {
            try
            {

               
                var result = await cl.Assets.DownloadAssetAsync(iid);

                using (var memoryStream = new MemoryStream())
                {
                    await result.CopyToAsync(memoryStream);
                    return memoryStream.ToArray();
                }

                return null;

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in DoGetBildFromImmich {ex.Message}");

            }

            return null;
        }

        public async Task<AssetMediaResponseDto> DoPostBildPostToImmich(ImmichApiClient cl, BildPost bp)
        {
            try
            {

                var asset = new AssetMediaCreateDto();
                var b64 = Convert.FromBase64String(bp.Base64Image);
                asset.AssetData = b64;
                asset.DeviceId = bp.CameraName;
                asset.DeviceAssetId = bp.BildId;
                asset.FileCreatedAt = bp.UploadTime;
                asset.FileModifiedAt = bp.UploadTime;
                asset.Filename = bp.BildName;
                var result = await cl.Assets.UploadAssetAsync(asset);

                return result;

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in DoPostBildPostToImmich {ex.Message}");

            }

            return null;
        }

        public async Task<AssetMediaResponseDto> DoPostBildPostToImmich(ImmichApiClient cl, BildPostSL bp)
        {
            try
            {

                var asset = new AssetMediaCreateDto();
                var b64 = Convert.FromBase64String(bp.Base64Image);
                asset.AssetData = b64;
                asset.DeviceId = bp.CameraName;
                asset.DeviceAssetId = bp.BildId;
                asset.FileCreatedAt = bp.UploadTime;
                asset.FileModifiedAt = bp.UploadTime;
                asset.Filename = bp.BildName;
                var result = await cl.Assets.UploadAssetAsync(asset);

                return result;

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in DoPostBildPostToImmich {ex.Message}");

            }

            return null;
        }

        public async Task DoAssetToAlbum(ImmichApiClient cl, AlbumResponseDto album, AssetMediaResponseDto asset)
        {
            try
            {
                if (album == null)
                    return;

                var bd = new BulkIdsDto();
                bd.Ids = new List<Guid>();
                Guid result = new Guid(asset.Id);
                bd.Ids.Add(result);
                await cl.Albums.AddAssetsToAlbumAsync(album.Id, bd);
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in DoAssetToAlbum {ex.Message}");

            }


        }

        public async Task<AlbumResponseDto> CheckCameraAndDate(MongoDataLayer<BildPost> ic, ImmichApiClient cl, BildPost bp)
        {
            try
            {
                var camresult = ic.GetCameraByName(bp.CameraName);
                var listalbums = await cl.Albums.GetAllAlbumsAsync();
                var albumname = $"{camresult.CameraRealName} {bp.UploadTime.Year} {bp.UploadTime.ToString("MMMM")}";
                //First we check is ftp file a known camersource
                if (camresult != null)
                {
                    var la = listalbums.Where(c => c.AlbumName == albumname).ToList();
                    if (la.Count == 0)
                    {
                        var ca = new CreateAlbumDto();
                        ca.AlbumName = albumname;

                        var album = await cl.Albums.CreateAsync(ca);
                        return album;
                    }
                    else
                    {
                        return la[0];
                    }
                }

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in CheckCamera {ex.Message}");

            }

            return null;
        }

        public async Task<AlbumResponseDto> CheckCameraAndDate(SqlLiteDataLayer<BildPostSL> ic, ImmichApiClient cl, BildPostSL bp)
        {
            try
            {
                var camresult = ic.GetCameraByName(bp.CameraName);
                var listalbums = await cl.Albums.GetAllAlbumsAsync();
                var albumname = $"{camresult.CameraRealName} {bp.UploadTime.Year} {bp.UploadTime.ToString("MMMM")}";
                //First we check is ftp file a known camersource
                if (camresult != null)
                {
                    var la = listalbums.Where(c => c.AlbumName == albumname).ToList();
                    if (la.Count == 0)
                    {
                        var ca = new CreateAlbumDto();
                        ca.AlbumName = albumname;

                        var album = await cl.Albums.CreateAsync(ca);
                        return album;
                    }
                    else
                    {
                        return la[0];
                    }
                }

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in CheckCamera {ex.Message}");

            }

            return null;
        }

        public async Task<AlbumResponseDto> CheckCameraAndDate(SqlLiteDataLayer<BildPost> ic, ImmichApiClient cl, BildPost bp)
        {
            try
            {
                var camresult = ic.GetCameraByName(bp.CameraName);
                var listalbums = await cl.Albums.GetAllAlbumsAsync();
                var albumname = $"{camresult.CameraRealName} {bp.UploadTime.Year} {bp.UploadTime.ToString("MMMM")}";
                //First we check is ftp file a known camersource
                if (camresult != null)
                {
                    var la = listalbums.Where(c => c.AlbumName == albumname).ToList();
                    if (la.Count == 0)
                    {
                        var ca = new CreateAlbumDto();
                        ca.AlbumName = albumname;

                        var album = await cl.Albums.CreateAsync(ca);
                        return album;
                    }
                    else
                    {
                        return la[0];
                    }
                }

            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in CheckCamera {ex.Message}");

            }

            return null;
        }

        public async Task<NotificationDto> SendImmichNotifiction(ImmichApiClient cl, string title,string message, NotificationLevel level, string userId, NotificationType type)
        {
            try {

              

                var notifyuser = new NotificationCreateDto();
                notifyuser.Title = title;
                notifyuser.Description = message;
                //notifyuser.Level = level;
                notifyuser.UserId = new Guid(userId);
                notifyuser.Type = type;


                var result = await cl.NotificationsAdmin.CreateNotificationAsync(notifyuser);
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in SendImmichNotifiction {ex.Message}");

            }

            return null;
        }

        public async Task SendAPNShNotifiction( string title, string message,string status,AssetMediaResponseDto asset)
        {
            try
            {
                var apns = new ApnsPushService();
                await apns.SendPushNotificationAsync(title, message,status,asset, _logger);
            }
            catch (Exception ex)
            {
                _logger.LogCritical($"Error in SendAPNSNotifiction {ex.Message}");

            }

        }
    }
}
