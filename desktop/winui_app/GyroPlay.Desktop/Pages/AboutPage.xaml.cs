using GyroPlay.Desktop.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Diagnostics;
using System.IO;
using System.Reflection;

namespace GyroPlay.Desktop.Pages;

public sealed partial class AboutPage : Page
{
    public AboutPage()
    {
        InitializeComponent();
        Loaded += AboutPage_Loaded;
    }

    private void AboutPage_Loaded(object sender, RoutedEventArgs e)
    {
        var version = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? Assembly.GetExecutingAssembly().GetName().Version?.ToString()
            ?? "0.1.0";
        VersionText.Text = $"Version {version}";
    }

    private void GitHubButton_Click(object sender, RoutedEventArgs e)
    {
        Process.Start(new ProcessStartInfo("https://github.com/") { UseShellExecute = true });
    }

    private void TroubleshootingButton_Click(object sender, RoutedEventArgs e)
    {
        var path = AppServices.Paths.TroubleshootingPath;
        var target = path is not null && File.Exists(path)
            ? path
            : "https://github.com/GyroPlay/GyroPlay/blob/main/docs/troubleshooting.md";
        Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
    }
}
