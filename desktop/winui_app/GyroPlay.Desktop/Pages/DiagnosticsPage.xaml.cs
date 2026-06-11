using GyroPlay.Desktop.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using Windows.ApplicationModel.DataTransfer;

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
        AppServices.Logging.LineAdded += Logging_LineAdded;
        VersionText.Text = $"Version {GetVersion()}";
        AdvancedLogTextBox.Text = string.Join(Environment.NewLine, AppServices.Logging.Lines);
        await RefreshChecksAsync();
    }

    private void DiagnosticsPage_Unloaded(object sender, RoutedEventArgs e)
    {
        AppServices.Engine.LogReceived -= Engine_LogReceived;
        AppServices.Logging.LineAdded -= Logging_LineAdded;
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
            CheckState.DisabledOrIncorrect => $"Disabled or incorrect - {result.Message}",
            _ => $"Error - {result.Message}",
        };
        details.Text = result.Details ?? string.Empty;
    }

    private async void RepairDriverButton_Click(object sender, RoutedEventArgs e)
    {
        await RunRepairAsync(RepairKind.Driver, "Repair Driver", "This will request administrator approval and run the ViGEmBus installer.");
    }

    private async void RepairFirewallButton_Click(object sender, RoutedEventArgs e)
    {
        await RunRepairAsync(RepairKind.Firewall, "Repair Firewall", "This will request administrator approval and recreate the inbound UDP 5005 firewall rule.");
    }

    private async void RepairSetupButton_Click(object sender, RoutedEventArgs e)
    {
        await RunRepairAsync(RepairKind.Setup, "Repair Setup", "This will request administrator approval and repair the driver and firewall setup.");
    }

    private async System.Threading.Tasks.Task RunRepairAsync(RepairKind kind, string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            PrimaryButtonText = "Continue",
            CloseButtonText = "Cancel",
            XamlRoot = XamlRoot,
        };

        if (await dialog.ShowAsync() != ContentDialogResult.Primary)
        {
            FeedbackText.Text = "Repair cancelled";
            return;
        }

        FeedbackText.Text = "Repair running...";
        var result = await AppServices.Repair.RunAsync(kind);
        FeedbackText.Text = result.Message;
        AppServices.Notifications.Show("Setup repair", result.Message);
        await RefreshChecksAsync();
    }

    private void OpenTroubleshootingButton_Click(object sender, RoutedEventArgs e)
    {
        var path = AppServices.Paths.TroubleshootingPath;
        var target = path is not null && File.Exists(path)
            ? path
            : "https://github.com/GyroPlay/GyroPlay/blob/main/docs/troubleshooting.md";
        TryOpen(target);
    }

    private void Engine_LogReceived(string line)
    {
    }

    private void Logging_LineAdded(string line)
    {
        if (string.IsNullOrEmpty(line))
        {
            AdvancedLogTextBox.Text = string.Empty;
            return;
        }

        AdvancedLogTextBox.Text += $"{line}{Environment.NewLine}";
        AdvancedLogTextBox.SelectionStart = AdvancedLogTextBox.Text.Length;
    }

    private void ClearLogsButton_Click(object sender, RoutedEventArgs e)
    {
        AppServices.Logging.Clear();
        FeedbackText.Text = "Logs cleared";
    }

    private void CopyLogsButton_Click(object sender, RoutedEventArgs e)
    {
        var package = new DataPackage();
        package.SetText(AdvancedLogTextBox.Text);
        Clipboard.SetContent(package);
        FeedbackText.Text = "Logs copied";
    }

    private void OpenLogFolderButton_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(AppServices.Paths.LogDirectory);
        TryOpen(AppServices.Paths.LogDirectory);
    }

    private void CopyIpButton_Click(object sender, RoutedEventArgs e)
    {
        var package = new DataPackage();
        package.SetText(HealthCheckService.GetLocalIpv4Address());
        Clipboard.SetContent(package);
        FeedbackText.Text = "IP copied";
    }

    private void TryOpen(string target)
    {
        try
        {
            Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
        }
        catch (Exception error)
        {
            FeedbackText.Text = $"Could not open: {error.Message}";
        }
    }

    private static string GetVersion()
    {
        return Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? Assembly.GetExecutingAssembly().GetName().Version?.ToString()
            ?? "Unknown";
    }
}
