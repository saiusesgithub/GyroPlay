using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;

namespace GyroPlay.Desktop;

public sealed partial class MainWindow : Window
{
    private const int UdpPort = 5005;

    private readonly DispatcherQueue _dispatcherQueue;
    private readonly DispatcherTimer _statusTimer;
    private Process? _engineProcess;
    private bool _stopRequested;

    public MainWindow()
    {
        InitializeComponent();

        _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
        _statusTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500),
        };
        _statusTimer.Tick += StatusTimer_Tick;

        Closed += MainWindow_Closed;

        LocalIpText.Text = GetLocalIpv4Address();
        AppendLog("GyroPlay desktop control panel ready.");
        AppendLog($"Engine path: {GetEngineScriptPath()}");
        AppendLog($"Preferred Python path: {GetPythonExecutablePath()}");
    }

    private void StartEngineButton_Click(object sender, RoutedEventArgs e)
    {
        StartEngine();
    }

    private void StopEngineButton_Click(object sender, RoutedEventArgs e)
    {
        StopEngine();
    }

    private void MainWindow_Closed(object sender, WindowEventArgs args)
    {
        _statusTimer.Stop();
        StopEngine();
    }

    private void StatusTimer_Tick(object? sender, object e)
    {
        if (EngineStatusText.Text == "Running" && PhoneStatusText.Text == "Connected")
        {
            LastPacketText.Text = DateTime.Now.ToString("HH:mm:ss");
        }
    }

    private void StartEngine()
    {
        if (_engineProcess is { HasExited: false })
        {
            AppendLog("Engine is already running.");
            return;
        }

        var engineScriptPath = GetEngineScriptPath();
        if (!File.Exists(engineScriptPath))
        {
            SetEngineStopped();
            AppendLog($"Error: engine script not found at {engineScriptPath}");
            return;
        }

        var pythonExecutablePath = GetPythonExecutablePath();
        if (!File.Exists(pythonExecutablePath))
        {
            SetEngineStopped();
            AppendLog($"Error: Python virtual environment not found at {pythonExecutablePath}");
            AppendLog("Create the engine virtual environment and install dependencies first:");
            AppendLog(@"  cd engine\python");
            AppendLog(@"  python -m venv .venv");
            AppendLog(@"  .\.venv\Scripts\Activate.ps1");
            AppendLog(@"  python -m pip install -r requirements.txt");
            return;
        }

        var engineDirectory = Path.GetDirectoryName(engineScriptPath);
        if (engineDirectory is null)
        {
            SetEngineStopped();
            AppendLog("Error: could not resolve engine directory.");
            return;
        }

        _stopRequested = false;

        var startInfo = new ProcessStartInfo
        {
            FileName = pythonExecutablePath,
            Arguments = $"-u \"{engineScriptPath}\"",
            WorkingDirectory = engineDirectory,
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
            AppendLog($"Using Python executable: {pythonExecutablePath}");
            AppendLog($"Started engine process PID {process.Id}.");
        }
        catch (Win32Exception error)
        {
            process.Dispose();
            SetEngineStopped();
            AppendLog("Error: engine virtual environment Python could not be started.");
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
        if (line.Contains("Valid controller session started", StringComparison.OrdinalIgnoreCase))
        {
            PhoneStatusText.Text = "Connected";
            LastPacketText.Text = DateTime.Now.ToString("HH:mm:ss");
        }
        else if (line.Contains("Safety timeout", StringComparison.OrdinalIgnoreCase))
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

    private static string GetPythonExecutablePath()
    {
        return Path.Combine(GetRepositoryRoot(), "engine", "python", ".venv", "Scripts", "python.exe");
    }

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
