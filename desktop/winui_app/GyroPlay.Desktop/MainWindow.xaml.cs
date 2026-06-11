using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media.Imaging;
using QRCoder;
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Security.Cryptography;
using System.Text.Json;
using Windows.Storage.Streams;

namespace GyroPlay.Desktop;

public sealed partial class MainWindow : Window
{
    private const int UdpPort = 5005;
    private static readonly TimeSpan PairingTokenLifetime = TimeSpan.FromMinutes(5);

    private readonly DispatcherQueue _dispatcherQueue;
    private readonly DispatcherTimer _statusTimer;
    private readonly DispatcherTimer _pairingTimer;
    private Process? _engineProcess;
    private bool _stopRequested;
    private DateTimeOffset _pairingTokenExpiresAt;

    public MainWindow()
    {
        InitializeComponent();

        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
        _statusTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500),
        };
        _statusTimer.Tick += StatusTimer_Tick;
        _pairingTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(1),
        };
        _pairingTimer.Tick += PairingTimer_Tick;

        Closed += MainWindow_Closed;

        LocalIpText.Text = GetLocalIpv4Address();
        AppendLog("GyroPlay desktop control panel ready.");
        AppendLog($"Packaged engine path: {GetPackagedEnginePath()}");
        AppendLog($"Engine path: {GetEngineScriptPath()}");
        AppendLog($"Development Python path: {GetPythonExecutablePath()}");
        _ = RefreshPairingCodeAsync();
    }

    private void StartEngineButton_Click(object sender, RoutedEventArgs e)
    {
        StartEngine();
    }

    private void StopEngineButton_Click(object sender, RoutedEventArgs e)
    {
        StopEngine();
    }

    private async void RefreshPairingButton_Click(object sender, RoutedEventArgs e)
    {
        await RefreshPairingCodeAsync();
    }

    private void MainWindow_Closed(object sender, WindowEventArgs args)
    {
        _statusTimer.Stop();
        _pairingTimer.Stop();
        StopEngine();
    }

    private void StatusTimer_Tick(object? sender, object e)
    {
        if (EngineStatusText.Text == "Running" && PhoneStatusText.Text == "Connected")
        {
            LastPacketText.Text = DateTime.Now.ToString("HH:mm:ss");
        }
    }

    private void PairingTimer_Tick(object? sender, object e)
    {
        UpdatePairingExpiryText();
    }

    private void StartEngine()
    {
        if (_engineProcess is { HasExited: false })
        {
            AppendLog("Engine is already running.");
            return;
        }

        var launchInfo = ResolveEngineLaunchInfo();
        if (launchInfo is null)
        {
            SetEngineStopped();
            AppendLog($"Error: packaged engine not found at {GetPackagedEnginePath()}");
            AppendLog($"Error: development Python not found at {GetPythonExecutablePath()}");
            AppendLog("Build the packaged engine or create the development virtual environment:");
            AppendLog(@"  cd engine\python");
            AppendLog(@"  python -m venv .venv");
            AppendLog(@"  .\.venv\Scripts\Activate.ps1");
            AppendLog(@"  python -m pip install -r requirements.txt");
            return;
        }

        _stopRequested = false;

        var startInfo = new ProcessStartInfo
        {
            FileName = launchInfo.ExecutablePath,
            Arguments = launchInfo.Arguments,
            WorkingDirectory = launchInfo.WorkingDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };

        var process = new Process
        {
            StartInfo = startInfo,
            EnableRaisingEvents = true,
        };

        process.OutputDataReceived += Engine_OutputDataReceived;
        process.ErrorDataReceived += Engine_ErrorDataReceived;
        process.Exited += Engine_Exited;

        try
        {
            if (!process.Start())
            {
                AppendLog("Error: failed to start Python engine process.");
                SetEngineStopped();
                return;
            }

            _engineProcess = process;
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            EngineStatusText.Text = "Running";
            StartEngineButton.IsEnabled = false;
            StopEngineButton.IsEnabled = true;
            _statusTimer.Start();
            if (launchInfo.IsDevelopmentFallback)
            {
                AppendLog("Development fallback mode: packaged engine not found; using Python virtual environment.");
            }
            AppendLog($"Launching engine executable: {launchInfo.ExecutablePath}");
            AppendLog($"Started engine process PID {process.Id}.");
        }
        catch (Win32Exception error)
        {
            process.Dispose();
            SetEngineStopped();
            AppendLog("Error: engine executable could not be started.");
            AppendLog(error.Message);
        }
        catch (Exception error)
        {
            process.Dispose();
            SetEngineStopped();
            AppendLog($"Error: failed to start engine. {error.Message}");
        }
    }

    private void StopEngine()
    {
        var process = _engineProcess;
        _stopRequested = true;

        if (process is null)
        {
            SetEngineStopped();
            return;
        }

        if (process.HasExited)
        {
            process.Dispose();
            _engineProcess = null;
            SetEngineStopped();
            return;
        }

        AppendLog("Stopping engine...");

        try
        {
            process.Kill(entireProcessTree: true);
            process.WaitForExit(3000);
        }
        catch (Exception error)
        {
            AppendLog($"Error while stopping engine: {error.Message}");
        }
        finally
        {
            process.Dispose();
            _engineProcess = null;
            SetEngineStopped();
            AppendLog("Engine stopped.");
        }
    }

    private void Engine_OutputDataReceived(object sender, DataReceivedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(e.Data))
        {
            return;
        }

        RunOnUiThread(() =>
        {
            AppendLog(e.Data);
            UpdatePhoneStatusFromLog(e.Data);
        });
    }

    private void Engine_ErrorDataReceived(object sender, DataReceivedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(e.Data))
        {
            return;
        }

        RunOnUiThread(() => AppendLog($"stderr: {e.Data}"));
    }

    private void Engine_Exited(object? sender, EventArgs e)
    {
        var process = sender as Process;
        var exitCode = 0;

        try
        {
            exitCode = process?.ExitCode ?? 0;
        }
        catch
        {
            // ExitCode can throw if the process object is already gone.
        }

        RunOnUiThread(() =>
        {
            if (!_stopRequested)
            {
                AppendLog($"Error: engine exited unexpectedly with code {exitCode}.");
            }

            _engineProcess?.Dispose();
            _engineProcess = null;
            SetEngineStopped();
        });
    }

    private void UpdatePhoneStatusFromLog(string line)
    {
        if (line.Contains("Phone connected", StringComparison.OrdinalIgnoreCase))
        {
            PhoneStatusText.Text = "Connected";
            LastPacketText.Text = DateTime.Now.ToString("HH:mm:ss");
        }
        else if (line.Contains("Phone disconnected", StringComparison.OrdinalIgnoreCase))
        {
            PhoneStatusText.Text = "Disconnected";
        }
    }

    private void SetEngineStopped()
    {
        EngineStatusText.Text = "Stopped";
        PhoneStatusText.Text = "Disconnected";
        StartEngineButton.IsEnabled = true;
        StopEngineButton.IsEnabled = false;
        _statusTimer.Stop();
    }

    private async System.Threading.Tasks.Task RefreshPairingCodeAsync()
    {
        var token = GeneratePairingToken();
        _pairingTokenExpiresAt = DateTimeOffset.UtcNow.Add(PairingTokenLifetime);
        var localIp = GetLocalIpv4Address();
        LocalIpText.Text = localIp;

        var payload = new
        {
            version = 1,
            type = "gyroplay_pairing",
            host = localIp,
            port = UdpPort,
            pairing_token = token,
            expires_at = _pairingTokenExpiresAt.ToString("O"),
        };

        var payloadJson = JsonSerializer.Serialize(payload);
        await SetQrImageAsync(payloadJson);
        WritePairingFile(token, _pairingTokenExpiresAt);
        PairingTokenText.Text = token;
        UpdatePairingExpiryText();
        _pairingTimer.Start();
        AppendLog($"Pairing code refreshed. Token expires at {_pairingTokenExpiresAt.LocalDateTime:HH:mm:ss}.");
    }

    private static string GeneratePairingToken()
    {
        Span<byte> bytes = stackalloc byte[4];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToHexString(bytes);
    }

    private async System.Threading.Tasks.Task SetQrImageAsync(string payloadJson)
    {
        using var generator = new QRCodeGenerator();
        using var data = generator.CreateQrCode(payloadJson, QRCodeGenerator.ECCLevel.Q);
        var qrCode = new PngByteQRCode(data);
        var pngBytes = qrCode.GetGraphic(12);

        var image = new BitmapImage();
        using var stream = new InMemoryRandomAccessStream();
        await stream.WriteAsync(pngBytes.AsBuffer());
        stream.Seek(0);
        await image.SetSourceAsync(stream);
        PairingQrImage.Source = image;
    }

    private static void WritePairingFile(string token, DateTimeOffset expiresAt)
    {
        var pairingFilePath = GetPairingFilePath();
        var pairingDirectory = Path.GetDirectoryName(pairingFilePath);

        if (pairingDirectory is not null)
        {
            Directory.CreateDirectory(pairingDirectory);
        }

        var json = JsonSerializer.Serialize(
            new
            {
                version = 1,
                pairing_token = token,
                expires_at = expiresAt.ToString("O"),
            },
            new JsonSerializerOptions { WriteIndented = true });

        File.WriteAllText(pairingFilePath, json);
    }

    private void UpdatePairingExpiryText()
    {
        var remaining = _pairingTokenExpiresAt - DateTimeOffset.UtcNow;

        if (remaining <= TimeSpan.Zero)
        {
            TokenExpiryText.Text = "Expired. Refresh pairing code.";
            return;
        }

        TokenExpiryText.Text =
            $"Expires: {_pairingTokenExpiresAt.LocalDateTime:HH:mm:ss} ({Math.Ceiling(remaining.TotalSeconds)}s)";
    }

    private void AppendLog(string message)
    {
        var timestamp = DateTime.Now.ToString("HH:mm:ss");
        LogTextBox.Text += $"[{timestamp}] {message}{Environment.NewLine}";
        LogTextBox.SelectionStart = LogTextBox.Text.Length;
    }

    private void RunOnUiThread(Action action)
    {
        if (!_dispatcherQueue.TryEnqueue(() => action()))
        {
            Debug.WriteLine("Failed to dispatch UI update.");
        }
    }

    private static string GetEngineScriptPath()
    {
        return Path.Combine(GetRepositoryRoot(), "engine", "python", "main.py");
    }

    private static string GetPackagedEnginePath()
    {
        return Path.Combine(GetRepositoryRoot(), "engine", "python", "dist", "GyroPlay.Engine.exe");
    }

    private static string GetPairingFilePath()
    {
        return Path.Combine(GetRepositoryRoot(), "engine", "python", "pairing.json");
    }

    private static string GetPythonExecutablePath()
    {
        return Path.Combine(GetRepositoryRoot(), "engine", "python", ".venv", "Scripts", "python.exe");
    }

    private static EngineLaunchInfo? ResolveEngineLaunchInfo()
    {
        var packagedEnginePath = GetPackagedEnginePath();
        if (File.Exists(packagedEnginePath))
        {
            var packagedWorkingDirectory = Path.GetDirectoryName(packagedEnginePath);
            if (packagedWorkingDirectory is null)
            {
                return null;
            }

            return new EngineLaunchInfo(
                packagedEnginePath,
                string.Empty,
                packagedWorkingDirectory,
                IsDevelopmentFallback: false);
        }

        var pythonExecutablePath = GetPythonExecutablePath();
        var engineScriptPath = GetEngineScriptPath();
        if (File.Exists(pythonExecutablePath) && File.Exists(engineScriptPath))
        {
            var engineWorkingDirectory = Path.GetDirectoryName(engineScriptPath);
            if (engineWorkingDirectory is null)
            {
                return null;
            }

            return new EngineLaunchInfo(
                pythonExecutablePath,
                $"-u \"{engineScriptPath}\"",
                engineWorkingDirectory,
                IsDevelopmentFallback: true);
        }

        return null;
    }

    private sealed record EngineLaunchInfo(
        string ExecutablePath,
        string Arguments,
        string WorkingDirectory,
        bool IsDevelopmentFallback);

    private static string GetRepositoryRoot()
    {
        var projectDirectory = AppContext.BaseDirectory;

        for (var current = new DirectoryInfo(projectDirectory);
             current is not null;
             current = current.Parent)
        {
            var candidate = Path.Combine(current.FullName, "engine", "python");
            if (Directory.Exists(candidate))
            {
                return current.FullName;
            }
        }

        return Path.GetFullPath(Path.Combine(projectDirectory, "..", "..", "..", "..", "..", ".."));
    }

    private static string GetLocalIpv4Address()
    {
        try
        {
            using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
            socket.Connect("8.8.8.8", 65530);

            if (socket.LocalEndPoint is IPEndPoint endpoint)
            {
                return endpoint.Address.ToString();
            }
        }
        catch
        {
            // Fall back to DNS enumeration below.
        }

        try
        {
            var host = Dns.GetHostEntry(Dns.GetHostName());
            var address = host.AddressList.FirstOrDefault(address =>
                address.AddressFamily == AddressFamily.InterNetwork &&
                !IPAddress.IsLoopback(address));

            return address?.ToString() ?? "Unavailable";
        }
        catch
        {
            return "Unavailable";
        }
    }
}
