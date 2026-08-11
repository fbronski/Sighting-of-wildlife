using WildLifeBildBot;
using Serilog;

var builder = Host.CreateApplicationBuilder(args);

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .CreateLogger();

builder.Logging.ClearProviders();
builder.Logging.AddSerilog();
builder.Logging.AddConsole();

builder.Services.AddHostedService<Worker>();
builder.Services.AddSingleton<IFTPFileWatcher, FTPFileWatcher>();
builder.Services.AddScoped<
    IFTPFileConsumerService,
    FTPFileConsumerService>();

var host = builder.Build();
await host.RunAsync();
