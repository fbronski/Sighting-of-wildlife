using WildLifeBildBot.Core;
using WildLifeBildBot.Model;
using Org.BouncyCastle.Asn1.Ocsp;
using static Org.BouncyCastle.Math.EC.ECCurve;

namespace WildLifeBildBot
{
    public class Worker(ILogger<Worker> logger, IFTPFileWatcher ftpwatcher, IServiceProvider serviceProvider, IConfiguration configuration) : BackgroundService
    {
        public string mFtphomepath = "C:\\Temp\\SpyBildBot"; //"/home/vftp/SpyBildBot";
        public string mBothomepath = "C:\\Temp\\SpyBildBot";
        public string mDBType = "MongoDB";
        //public string mModelFile = "/home/unicomsupport/JagdBildBot/yolo11n.onnx";
        //public YoloPredictor? mPredictor = null;
        //public string mServer = "10.50.5.100:27017,10.50.5.101:27017";
        public DateTime lastsenddate = DateTime.UtcNow;
        public long mRunningsec = 0;

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            mFtphomepath =
                    configuration["ApplicationSettings:FTPHomePath"] ?? "";

            mBothomepath =
                configuration["ApplicationSettings:BotHomePath"] ?? "";

            mDBType =
                configuration["ApplicationSettings:DBType"] ?? "SqliteDB";

            var ak =
                configuration["ApplicationSettings:ImmichApiClientKey"];

            var ep =
                configuration["ApplicationSettings:ImmichEndPoint"];


            logger.LogInformation($"Clean up FTP File Path {mFtphomepath}");
            var files = System.IO.Directory.GetFiles(mFtphomepath, "*.*");

            SqlLiteDataLayer<BildPost> cols = new SqlLiteDataLayer<BildPost>("UCSpyBildBot");
            //var cam = cols.GetCameraByName("Z6JP");

            if (String.IsNullOrEmpty(mFtphomepath) ||  String.IsNullOrEmpty(mBothomepath) || String.IsNullOrEmpty(mDBType) || String.IsNullOrEmpty(ak) || String.IsNullOrEmpty(ep))
            {
                logger.LogError($"Error in your AppSettings please use FTPHomePath, BotHomePath and mDBType rigth");
                return;
            }

            foreach (var file in files)
            {

                string filename = Path.GetFileName(file);
                string camid = filename.Substring(0, 4);
                logger.LogInformation($"Found {filename}:{camid}:{file}");
                FileInfo incomingftpfile = new FileInfo(file);

                using (var scope = serviceProvider.CreateScope())
                {
                    var consumerService = scope.ServiceProvider.GetRequiredService<IFTPFileConsumerService>();
                    if (mDBType.Equals("MongoDB"))
                    {
                        await consumerService.ConsumeFTPImageFileOnMongoDB(filename, file);
                    }
                    else if (mDBType.Equals("SqliteDB"))
                    {
                        await consumerService.ConsumeFTPImageFileOnSqliteDB(filename, file);
                    }
                   
                    string trashpath = $"{mFtphomepath}/trash/{incomingftpfile.Name}";
                    if (incomingftpfile.Exists)
                    {
                        logger.LogWarning($"Moveing existing {incomingftpfile.Name} to trash");
                        incomingftpfile.MoveTo(trashpath);
                    }
                   
                }

            }

            ftpwatcher.Start(mFtphomepath, mDBType);

            while (!stoppingToken.IsCancellationRequested)
            {
              
                await Task.Delay(1000, stoppingToken);
            }
        }

    
    }
}
