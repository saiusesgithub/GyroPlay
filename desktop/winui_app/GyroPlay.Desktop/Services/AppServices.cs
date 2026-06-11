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

    public static void Initialize(DispatcherQueue dispatcherQueue)
    {
        Settings.Initialize(Paths);
        Pairing.Initialize(Paths);
        Health.Initialize(Paths);
        Engine.Initialize(dispatcherQueue, Paths);
    }
}
