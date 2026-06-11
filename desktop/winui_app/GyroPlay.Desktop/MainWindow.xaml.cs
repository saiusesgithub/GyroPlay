using GyroPlay.Desktop.Pages;
using GyroPlay.Desktop.Services;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;
using System.IO;
using System.Runtime.InteropServices;
using WinRT.Interop;

namespace GyroPlay.Desktop;

public sealed partial class MainWindow : Window
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly StartupPage _startupPage = new();
    private bool _isExiting;

    public MainWindow()
    {
        InitializeComponent();
        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
        AppServices.Initialize(_dispatcherQueue);
        SetWindowIcon();

        Closed += MainWindow_Closed;
        AppWindow.Closing += MainWindow_AppWindowClosing;
        AppServices.Tray.OpenRequested += RestoreFromTray;
        AppServices.Tray.ExitRequested += ExitFromTray;
        AppServices.Tray.EnsureCreated();
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
            if (report.Driver.IsOk)
            {
                AppServices.Engine.Start();
            }
            else
            {
                AppServices.Logging.Write("Auto-start blocked because ViGEmBus is not available.");
                AppServices.Notifications.Show("Auto-start blocked", "ViGEmBus is not available, so the engine was not started.");
            }
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
        AppServices.Tray.OpenRequested -= RestoreFromTray;
        AppServices.Tray.ExitRequested -= ExitFromTray;
        AppServices.Engine.Stop();
        AppServices.Engine.Dispose();
        AppServices.Tray.Dispose();
    }

    private void SetWindowIcon()
    {
        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "GyroPlay.ico");
        if (File.Exists(iconPath))
        {
            AppWindow.SetIcon(iconPath);
        }
    }

    private void MainWindow_AppWindowClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_isExiting)
        {
            return;
        }

        if (AppServices.Settings.Current.MinimizeToTrayOnClose)
        {
            args.Cancel = true;
            AppServices.Tray.EnsureCreated();
            HideWindow();
            AppServices.Notifications.Show("GyroPlay is still running", "Use the tray icon to reopen or exit.");
        }
    }

    private void RestoreFromTray()
    {
        ShowWindow();
        Activate();
    }

    private void ExitFromTray()
    {
        _isExiting = true;
        AppServices.Engine.Stop();
        Close();
    }

    private void HideWindow()
    {
        NativeMethods.ShowWindow(WindowNative.GetWindowHandle(this), 0);
    }

    private void ShowWindow()
    {
        NativeMethods.ShowWindow(WindowNative.GetWindowHandle(this), 5);
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

internal static partial class NativeMethods
{
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(nint hWnd, int nCmdShow);
}
