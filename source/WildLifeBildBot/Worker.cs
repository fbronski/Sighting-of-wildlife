using WildLifeBildBot.Core;
using WildLifeBildBot.Model;
using Org.BouncyCastle.Asn1.Ocsp;
using static Org.BouncyCastle.Math.EC.ECCurve;

namespace WildLifeBildBot
{
    public class Worker(ILogger<Worker> logger, IFTPFileWatcher ftpwatcher, IServiceProvider serviceProvider) : BackgroundService
    {
        public string mFtphomepath = "path to";
        public string mBothomepath = "C:\\Temp\\WildLifeBildBot";
        public string mDBType = "MongoDB";
        public DateTime lastsenddate = DateTime.UtcNow;
        public long mRunningsec = 0;
       
        
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var config = new ConfigurationBuilder().AddJsonFile("appsettings.json").Build();

            mFtphomepath = config.GetValue<string>("ApplicationSettings:FTPHomePath");
            mBothomepath = config.GetValue<string>("ApplicationSettings:BotHomePath");
            mDBType = config.GetValue<string>("ApplicationSettings:DBType");

            logger.LogInformation($"Clean up FTP File Path {mFtphomepath}");
            var files = System.IO.Directory.GetFiles(mFtphomepath, "*.*");

            SqlLiteDataLayer<BildPost> cols = new SqlLiteDataLayer<BildPost>("UCSpyBildBot");
            //var cam = cols.GetCameraByName("Z6JP");


            var ak = config.GetValue<string>("ApplicationSettings:ImmichApiClientKey");
            var ep = config.GetValue<string>("ApplicationSettings:ImmichEndPoint");

            if (String.IsNullOrEmpty(mFtphomepath) ||  String.IsNullOrEmpty(mBothomepath) || String.IsNullOrEmpty(mDBType) || String.IsNullOrEmpty(ak) || String.IsNullOrEmpty(ep))
            {
                logger.LogError($"Error in your AppSettins please use FTPHomePath, BotHomePath and mDBType rigth");
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
