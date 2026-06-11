using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace GyroPlay.Desktop.Services;

public sealed class DesktopSettings
{
    public bool StartEngineOnOpen { get; set; }
    public bool MinimizeToTrayOnClose { get; set; }
    public bool LaunchWithWindows { get; set; }
    public bool ShowConnectionNotifications { get; set; } = true;
    public string Theme { get; set; } = "Dark";
}

public sealed class SettingsService
{
    private AppPaths _paths = new();

    public DesktopSettings Current { get; private set; } = new();

    public void Initialize(AppPaths paths)
    {
        _paths = paths;
    }

    public async Task LoadAsync()
    {
        try
        {
            if (File.Exists(_paths.SettingsFilePath))
            {
                var json = await File.ReadAllTextAsync(_paths.SettingsFilePath);
                Current = JsonSerializer.Deserialize<DesktopSettings>(json) ?? new DesktopSettings();
            }
        }
        catch
        {
            Current = new DesktopSettings();
        }
    }

    public async Task SaveAsync()
    {
        _paths.EnsureAppDataDirectory();
        var json = JsonSerializer.Serialize(Current, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(_paths.SettingsFilePath, json);
    }
}
