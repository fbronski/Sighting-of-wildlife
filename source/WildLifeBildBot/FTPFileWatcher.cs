using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WildLifeBildBot
{
    public interface IFTPFileWatcher
    {
        public void Start(string directoryname, string dbtype);
    }

    public class FTPFileWatcher : IFTPFileWatcher
    {
        private string _directoryName = "";
                                           
        private string _dbtype = "";
        FileSystemWatcher _fileSystemWatcher;
        ILogger<FTPFileWatcher> _logger;
        IServiceProvider _serviceProvider;

        public FTPFileWatcher(ILogger<FTPFileWatcher> logger, IServiceProvider serviceProvider)
        {
            _logger = logger;
           
            _serviceProvider = serviceProvider;
        }

        public void Start(string directoryName, string dbtype)
        {
            _directoryName = directoryName;
            _dbtype = dbtype;
            if (!Directory.Exists(_directoryName))
                Directory.CreateDirectory(_directoryName);


            _fileSystemWatcher = new FileSystemWatcher(_directoryName);
            _fileSystemWatcher.Filters.Add("*.JPG");
            _fileSystemWatcher.Filters.Add("*.jpg");
            _fileSystemWatcher.Filters.Add("*.TXT");
            _fileSystemWatcher.Filters.Add("*.txt");

            _fileSystemWatcher.NotifyFilter = NotifyFilters.Attributes
                                 | NotifyFilters.CreationTime
                                 | NotifyFilters.DirectoryName
                                 | NotifyFilters.FileName
                                 | NotifyFilters.LastAccess
                                 | NotifyFilters.LastWrite
                                 | NotifyFilters.Security
                                 | NotifyFilters.Size;

            _fileSystemWatcher.Changed += _fileSystemWatcher_Changed;
            _fileSystemWatcher.Created += _fileSystemWatcher_Created;
            _fileSystemWatcher.Deleted += _fileSystemWatcher_Deleted;
            _fileSystemWatcher.Renamed += _fileSystemWatcher_Renamed;
            _fileSystemWatcher.Error += _fileSystemWatcher_Error;


            _fileSystemWatcher.EnableRaisingEvents = true;
            _fileSystemWatcher.IncludeSubdirectories = true;

            _logger.LogInformation($"File Watching has started for directory {_directoryName}");
        }

        private void _fileSystemWatcher_Error(object sender, ErrorEventArgs e)
        {
            _logger.LogInformation($"File error event {e.GetException().Message}");
        }

        private void _fileSystemWatcher_Renamed(object sender, RenamedEventArgs e)
        {
            _logger.LogInformation($"File rename event for file {e.FullPath}");
        }

        private void _fileSystemWatcher_Deleted(object sender, FileSystemEventArgs e)
        {
            _logger.LogInformation($"File deleted event for file {e.FullPath}");
        }

        private void _fileSystemWatcher_Changed(object sender, FileSystemEventArgs e)
        {

        }

        private void _fileSystemWatcher_Created(object sender, FileSystemEventArgs e)
        {
           
            using (var scope = _serviceProvider.CreateScope())
            {
                var consumerService = scope.ServiceProvider.GetRequiredService<IFTPFileConsumerService>();
                if (_dbtype.Equals("MongoDB"))
                {
                    if (e.Name.EndsWith(".JPG") || e.Name.EndsWith(".jpg"))
                        Task.Run(() => consumerService.ConsumeFTPImageFileOnMongoDB(e.Name, e.FullPath, 10));
                    else if (e.Name.EndsWith(".TXT") || e.Name.EndsWith(".txt"))
                        Task.Run(() => consumerService.ConsumeFTPTextFileOnMongoDB(e.Name, e.FullPath, 2));
                }else if (_dbtype.Equals("SqliteDB"))
                {
                    if (e.Name.EndsWith(".JPG") || e.Name.EndsWith(".jpg"))
                        Task.Run(() => consumerService.ConsumeFTPImageFileOnSqliteDB(e.Name, e.FullPath, 10));
                    else if (e.Name.EndsWith(".TXT") || e.Name.EndsWith(".txt"))
                        Task.Run(() => consumerService.ConsumeFTPTextFileOnSqliteDB(e.Name, e.FullPath, 2));
                }
            }
        }
    }
}