using GyroPlay.Desktop.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;
using System.Diagnostics;
using System.IO;

namespace GyroPlay.Desktop.Pages;

public sealed partial class DiagnosticsPage : Page
{
    public DiagnosticsPage()
    {
        InitializeComponent();
        Loaded += DiagnosticsPage_Loaded;
        Unloaded += DiagnosticsPage_Unloaded;
    }

    private async void DiagnosticsPage_Loaded(object sender, RoutedEventArgs e)
    {
        AppServices.Engine.LogReceived += Engine_LogReceived;
        await RefreshChecksAsync();
    }

    private void DiagnosticsPage_Unloaded(object sender, RoutedEventArgs e)
    {
        AppServices.Engine.LogReceived -= Engine_LogReceived;
    }

    private async void RefreshChecksButton_Click(object sender, RoutedEventArgs e) => await RefreshChecksAsync();

    private async System.Threading.Tasks.Task RefreshChecksAsync()
    {
        var report = await AppServices.Health.RunPreflightAsync();
        SetCheck(EngineStatusText, EngineDetailsText, report.Engine);
        SetCheck(DriverStatusText, DriverDetailsText, report.Driver);
        SetCheck(FirewallStatusText, FirewallDetailsText, report.Firewall);
        SetCheck(StorageStatusText, StorageDetailsText, report.PairingStorage);
    }

    private static void SetCheck(TextBlock status, TextBlock details, CheckResult result)
    {
        status.Text = result.State switch
        {
            CheckState.Ok => $"Installed / Configured - {result.Message}",
            CheckState.Missing => $"Missing - {result.Message}",
            _ => $"Error - {result.Message}",
        };
        details.Text = result.Details ?? string.Empty;
    }

    private async void RepairDriverButton_Click(object sender, RoutedEventArgs e)
    {
        await ShowRepairNoticeAsync("Driver repair requires administrator privileges. Run the GyroPlay installer repair flow to reinstall ViGEmBus.");
    }

    private async void RepairFirewallButton_Click(object sender, RoutedEventArgs e)
    {
        await ShowRepairNoticeAsync("Firewall repair requires administrator privileges. Run the GyroPlay installer repair flow to recreate the UDP rule.");
    }

    private async System.Threading.Tasks.Task ShowRepairNoticeAsync(string message)
    {
        var dialog = new ContentDialog
        {
            Title = "Confirmation required",
            Content = message,
            CloseButtonText = "OK",
            XamlRoot = XamlRoot,
        };
        await dialog.ShowAsync();
    }

    private void OpenTroubleshootingButton_Click(object sender, RoutedEventArgs e)
    {
        var path = AppServices.Paths.TroubleshootingPath;
        var target = path is not null && File.Exists(path)
            ? path
            : "https://github.com/";
        Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
    }

    private void Engine_LogReceived(string line)
    {
        AdvancedLogTextBox.Text += $"{line}{Environment.NewLine}";
        AdvancedLogTextBox.SelectionStart = AdvancedLogTextBox.Text.Length;
    }
}
