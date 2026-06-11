using GyroPlay.Desktop.Services;
using Microsoft.UI.Xaml;

namespace GyroPlay.Desktop;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(Microsoft.UI.Xaml.LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        AppServices.Windows.Add(_window);
        _window.Activate();
    }
}
