namespace GyroPlay.Desktop.Services;

public sealed class NotificationService
{
    private SettingsService _settings = new();
    private TrayService? _tray;

    public void Initialize(SettingsService settings)
    {
        _settings = settings;
    }

    public void AttachTray(TrayService tray)
    {
        _tray = tray;
    }

    public void Show(string title, string message)
    {
        if (!_settings.Current.ShowConnectionNotifications)
        {
            return;
        }

        _tray?.ShowNotification(title, message);
    }
}
