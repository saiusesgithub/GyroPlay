using GyroPlay.Desktop.Pages;
using GyroPlay.Desktop.Services;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;

namespace GyroPlay.Desktop;

public sealed partial class MainWindow : Window
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly StartupPage _startupPage = new();

    public MainWindow()
    {
        InitializeComponent();
        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
        AppServices.Initialize(_dispatcherQueue);

        Closed += MainWindow_Closed;
        PreflightHost.Children.Add(_startupPage);
        _ = RunStartupChecksAsync();
    }

    private async System.Threading.Tasks.Task RunStartupChecksAsync()
    {
        _startupPage.SetStatus("Checking GyroPlay setup...");
        await AppServices.Settings.LoadAsync();
        ApplyTheme(AppServices.Settings.Current.Theme);

        var report = await AppServices.Health.RunPreflightAsync();
        _startupPage.ShowReport(report);

        RootNavigation.Visibility = Visibility.Visible;
        PreflightHost.Visibility = Visibility.Collapsed;
        RootNavigation.SelectedItem = HomeItem;
        ContentFrame.Navigate(typeof(HomePage));

        if (AppServices.Settings.Current.StartEngineOnOpen && report.Engine.IsOk)
        {
            AppServices.Engine.Start();
        }
    }

    private void RootNavigation_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItemContainer?.Tag is not string tag)
        {
            return;
        }

        var pageType = tag switch
        {
            "home" => typeof(HomePage),
            "diagnostics" => typeof(DiagnosticsPage),
            "settings" => typeof(SettingsPage),
            "about" => typeof(AboutPage),
            _ => typeof(HomePage),
        };

        if (ContentFrame.CurrentSourcePageType != pageType)
        {
            ContentFrame.Navigate(pageType);
        }
    }

    private void MainWindow_Closed(object sender, WindowEventArgs args)
    {
        AppServices.Engine.Stop();
        AppServices.Engine.Dispose();
    }

    internal static void ApplyTheme(string theme)
    {
        if (App.Current is null)
        {
            return;
        }

        foreach (var window in AppServices.Windows)
        {
            if (window.Content is FrameworkElement root)
            {
                root.RequestedTheme = theme switch
                {
                    "Light" => ElementTheme.Light,
                    "Dark" => ElementTheme.Dark,
                    _ => ElementTheme.Default,
                };
            }
        }
    }
}
