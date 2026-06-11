using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using System.Collections.Generic;

namespace GyroPlay.Desktop.Services;

public static class AppServices
{
    public static List<Window> Windows { get; } = new();
    public static AppPaths Paths { get; } = new();
    public static SettingsService Settings { get; } = new();
    public static PairingService Pairing { get; } = new();
    public static HealthCheckService Health { get; } = new();
    public static EngineService Engine { get; } = new();
    public static LoggingService Logging { get; } = new();
    public static StartupService Startup { get; } = new();
    public static NotificationService Notifications { get; } = new();
    public static RepairService Repair { get; } = new();
    public static TrayService Tray { get; } = new();

    public static void Initialize(DispatcherQueue dispatcherQueue)
    {
        Logging.Initialize(Paths);
        Settings.Initialize(Paths);
        Pairing.Initialize(Paths);
        Health.Initialize(Paths);
        Startup.Initialize(Paths);
        Notifications.Initialize(Settings);
        Repair.Initialize(Paths, Logging);
        Engine.Initialize(dispatcherQueue, Paths, Logging, Notifications);
        Tray.Initialize(Paths, Engine, Notifications);
    }
}
