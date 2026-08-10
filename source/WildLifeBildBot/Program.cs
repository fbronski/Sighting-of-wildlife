using WildLifeBildBot;
using Serilog;

var builder = Host.CreateApplicationBuilder(args);
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .CreateLogger();

var cfg = builder.Configuration.SetBasePath(Directory.GetCurrentDirectory()).AddJsonFile("appsettings.json", optional: false, reloadOnChange: true); ;
builder.Logging.ClearProviders();
builder.Logging.AddSerilog();
builder.Logging.AddConsole();

var dbtype = builder.Configuration["DBTYPE"];
//builder.Services.AddSystemd();
builder.Services.AddHostedService<Worker>();

builder.Services.AddSingleton<IFTPFileWatcher, FTPFileWatcher>();
builder.Services.AddScoped<IFTPFileConsumerService, FTPFileConsumerService>();




var host = builder.Build();

await host.RunAsync();
