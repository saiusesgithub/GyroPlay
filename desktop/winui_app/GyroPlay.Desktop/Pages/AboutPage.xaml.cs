using GyroPlay.Desktop.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Diagnostics;
using System.IO;
using System.Reflection;

namespace GyroPlay.Desktop.Pages;

public sealed partial class AboutPage : Page
{
    private const string RepositoryUrl = "https://github.com/saiusesgithub/GyroPlay";
    private const string TroubleshootingUrl = "https://github.com/saiusesgithub/GyroPlay/blob/main/docs/troubleshooting.md";
    private const string LicenseUrl = "https://github.com/saiusesgithub/GyroPlay/blob/main/LICENSE";

    public AboutPage()
    {
        InitializeComponent();
        Loaded += AboutPage_Loaded;
    }

    private void AboutPage_Loaded(object sender, RoutedEventArgs e)
    {
        VersionText.Text = $"Version {GetDisplayVersion()}";
    }

    private void GitHubButton_Click(object sender, RoutedEventArgs e)
    {
        TryOpen(RepositoryUrl);
    }

    private void TroubleshootingButton_Click(object sender, RoutedEventArgs e)
    {
        var path = AppServices.Paths.TroubleshootingPath;
        var target = path is not null && File.Exists(path)
            ? path
            : TroubleshootingUrl;
        TryOpen(target);
    }

    private void LicenseButton_Click(object sender, RoutedEventArgs e)
    {
        TryOpen(LicenseUrl);
    }

    private void TryOpen(string target)
    {
        try
        {
            Process.Start(new ProcessStartInfo(target) { UseShellExecute = true });
        }
        catch
        {
            VersionText.Text = "Could not open link.";
        }
    }

    private static string GetDisplayVersion()
    {
        var version = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? Assembly.GetExecutingAssembly().GetName().Version?.ToString()
            ?? "0.1.0";

        return version.Split('+')[0];
    }
}
