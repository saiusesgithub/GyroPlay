using GyroPlay.Desktop.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using System;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage.Streams;
using System.Runtime.InteropServices.WindowsRuntime;

namespace GyroPlay.Desktop.Pages;

public sealed partial class HomePage : Page
{
    private readonly DispatcherTimer _pairingTimer = new() { Interval = TimeSpan.FromSeconds(1) };
    private DateTimeOffset _tokenExpiresAt;

    public HomePage()
    {
        InitializeComponent();
        Loaded += HomePage_Loaded;
        Unloaded += HomePage_Unloaded;
        _pairingTimer.Tick += (_, _) => UpdatePairingExpiryText();
    }

    private void HomePage_Loaded(object sender, RoutedEventArgs e)
    {
        AppServices.Engine.StateChanged += UpdateState;
        LocalIpText.Text = HealthCheckService.GetLocalIpv4Address();
        RefreshPairingCode();
        UpdateState();
    }

    private void HomePage_Unloaded(object sender, RoutedEventArgs e)
    {
        AppServices.Engine.StateChanged -= UpdateState;
        _pairingTimer.Stop();
    }

    private void StartEngineButton_Click(object sender, RoutedEventArgs e) => AppServices.Engine.Start();

    private void StopEngineButton_Click(object sender, RoutedEventArgs e) => AppServices.Engine.Stop();

    private void RefreshPairingButton_Click(object sender, RoutedEventArgs e) => RefreshPairingCode();

    private void CopyIpButton_Click(object sender, RoutedEventArgs e)
    {
        var package = new DataPackage();
        package.SetText(LocalIpText.Text);
        Clipboard.SetContent(package);
        CopyFeedbackText.Text = "Copied";
    }

    private async void RefreshPairingCode()
    {
        try
        {
            var pairing = AppServices.Pairing.Refresh(LocalIpText.Text);
            _tokenExpiresAt = pairing.ExpiresAt;
            PairingTokenText.Text = pairing.Token;
            await SetQrImageAsync(pairing.QrPngBytes);
            UpdatePairingExpiryText();
            _pairingTimer.Start();
        }
        catch (Exception error)
        {
            TokenExpiryText.Text = "Pairing storage needs attention.";
            PairingTokenText.Text = "-";
            CopyFeedbackText.Text = error.Message;
        }
    }

    private async System.Threading.Tasks.Task SetQrImageAsync(byte[] pngBytes)
    {
        var image = new BitmapImage();
        using var stream = new InMemoryRandomAccessStream();
        await stream.WriteAsync(pngBytes.AsBuffer());
        stream.Seek(0);
        await image.SetSourceAsync(stream);
        PairingQrImage.Source = image;
    }

    private void UpdatePairingExpiryText()
    {
        var remaining = _tokenExpiresAt - DateTimeOffset.UtcNow;
        TokenExpiryText.Text = remaining <= TimeSpan.Zero
            ? "Expired. Refresh pairing code."
            : $"Expires: {_tokenExpiresAt.LocalDateTime:HH:mm:ss} ({Math.Ceiling(remaining.TotalSeconds)}s)";
    }

    private void UpdateState()
    {
        var engine = AppServices.Engine;
        PhoneStatusText.Text = engine.PhoneStatus;
        LastPacketText.Text = engine.LastPacketText;
        StartEngineButton.IsEnabled = engine.State != EngineState.Running;
        StopEngineButton.IsEnabled = engine.State == EngineState.Running;
        EngineBadge.Value = engine.State == EngineState.Running ? 1 : 0;
        PhoneBadge.Value = engine.PhoneStatus == "Connected" ? 1 : 0;
        PacketBadge.Value = engine.LastPacketText == "Never" ? 0 : 1;

        OverallStateText.Text = engine.State switch
        {
            EngineState.Error => "Error",
            EngineState.Running when engine.PhoneStatus == "Connected" => "Ready",
            EngineState.Running => "Connecting",
            _ => "Needs attention",
        };
    }
}
