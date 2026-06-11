using GyroPlay.Desktop.Services;
using Microsoft.UI.Xaml.Controls;
using System.Linq;

namespace GyroPlay.Desktop.Pages;

public sealed partial class StartupPage : Page
{
    public StartupPage()
    {
        InitializeComponent();
    }

    public void SetStatus(string text)
    {
        StatusText.Text = text;
    }

    public void ShowReport(PreflightReport report)
    {
        LoadingRing.IsActive = false;
        StatusText.Text = report.IsReady
            ? "Ready."
            : "A few items need attention. You can review them in Setup & Diagnostics.";
        ChecksList.ItemsSource = new[]
        {
            report.Engine,
            report.Driver,
            report.Firewall,
            report.LocalIp,
            report.PairingStorage,
        }.Select(check => $"{check.Title}: {check.Message}");
    }
}
