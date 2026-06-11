using GyroPlay.Desktop.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;

namespace GyroPlay.Desktop.Pages;

public sealed partial class SettingsPage : Page
{
    private bool _loading;

    public SettingsPage()
    {
        InitializeComponent();
        Loaded += SettingsPage_Loaded;
    }

    private void SettingsPage_Loaded(object sender, RoutedEventArgs e)
    {
        _loading = true;
        var settings = AppServices.Settings.Current;
        StartEngineToggle.IsOn = settings.StartEngineOnOpen;
        MinimizeToTrayToggle.IsOn = settings.MinimizeToTrayOnClose;
        LaunchWithWindowsToggle.IsOn = settings.LaunchWithWindows;
        NotificationsToggle.IsOn = settings.ShowConnectionNotifications;
        ThemeComboBox.SelectedIndex = settings.Theme switch
        {
            "Light" => 2,
            "Dark" => 1,
            _ => 0,
        };
        SettingsStatusText.Text = $"Saved in {AppServices.Paths.SettingsFilePath}";
        _loading = false;
    }

    private async void SettingChanged(object sender, RoutedEventArgs e)
    {
        if (_loading)
        {
            return;
        }

        await SaveSettingsAsync();
    }

    private async void ThemeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_loading)
        {
            return;
        }

        await SaveSettingsAsync();
        MainWindow.ApplyTheme(AppServices.Settings.Current.Theme);
    }

    private async System.Threading.Tasks.Task SaveSettingsAsync()
    {
        var settings = AppServices.Settings.Current;
        settings.StartEngineOnOpen = StartEngineToggle.IsOn;
        settings.MinimizeToTrayOnClose = MinimizeToTrayToggle.IsOn;
        settings.LaunchWithWindows = LaunchWithWindowsToggle.IsOn;
        settings.ShowConnectionNotifications = NotificationsToggle.IsOn;
        settings.Theme = (ThemeComboBox.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "Dark";
        await AppServices.Settings.SaveAsync();
        SettingsStatusText.Text = "Settings saved. Startup and tray options take effect on restart.";
    }
}
