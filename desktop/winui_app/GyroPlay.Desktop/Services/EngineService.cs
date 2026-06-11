using Microsoft.UI.Dispatching;
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;

namespace GyroPlay.Desktop.Services;

public enum EngineState
{
    Stopped,
    Running,
    Error,
}

public sealed class EngineService : IDisposable
{
    private DispatcherQueue? _dispatcherQueue;
    private AppPaths _paths = new();
    private LoggingService _logging = new();
    private NotificationService _notifications = new();
    private Process? _process;
    private bool _stopRequested;

    public EngineState State { get; private set; } = EngineState.Stopped;
    public string PhoneStatus { get; private set; } = "Disconnected";
    public string LastPacketText { get; private set; } = "Never";

    public event Action? StateChanged;
    public event Action<string>? LogReceived;

    public void Initialize(DispatcherQueue dispatcherQueue, AppPaths paths, LoggingService logging, NotificationService notifications)
    {
        _dispatcherQueue = dispatcherQueue;
        _paths = paths;
        _logging = logging;
        _notifications = notifications;
    }

    public void Start()
    {
        if (_process is { HasExited: false })
        {
            Log("Engine is already running.");
            return;
        }

        var launchInfo = ResolveLaunchInfo();
        if (launchInfo is null)
        {
            State = EngineState.Error;
            Log("The controller engine could not be found. Reinstall GyroPlay or check Setup & Diagnostics.");
            _notifications.Show("GyroPlay engine", "The engine could not be found.");
            NotifyStateChanged();
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

        var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        process.OutputDataReceived += Engine_OutputDataReceived;
        process.ErrorDataReceived += Engine_ErrorDataReceived;
        process.Exited += Engine_Exited;

        try
        {
            if (!process.Start())
            {
                State = EngineState.Error;
                Log("The engine process did not start.");
                _notifications.Show("GyroPlay engine", "The engine failed to start.");
                NotifyStateChanged();
                return;
            }

            _process = process;
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            State = EngineState.Running;
            PhoneStatus = "Disconnected";
            LastPacketText = "Never";
            Log($"Launching engine: {launchInfo.ExecutablePath}");
            if (launchInfo.IsDevelopmentFallback)
            {
                Log("Development fallback mode is active.");
            }
            NotifyStateChanged();
        }
        catch (Win32Exception error)
        {
            process.Dispose();
            State = EngineState.Error;
            Log($"The engine could not be started. {error.Message}");
            _notifications.Show("GyroPlay engine", "The engine failed to start.");
            NotifyStateChanged();
        }
        catch (Exception error)
        {
            process.Dispose();
            State = EngineState.Error;
            Log($"The engine could not be started. {error.Message}");
            _notifications.Show("GyroPlay engine", "The engine failed to start.");
            NotifyStateChanged();
        }
    }

    public void Stop()
    {
        var process = _process;
        _stopRequested = true;
        if (process is null)
        {
            SetStopped();
            return;
        }

        try
        {
            if (!process.HasExited)
            {
                Log("Stopping engine...");
                process.Kill(entireProcessTree: true);
                process.WaitForExit(3000);
            }
        }
        catch (Exception error)
        {
            Log($"Engine stop failed. {error.Message}");
        }
        finally
        {
            process.Dispose();
            _process = null;
            SetStopped();
            Log("Engine stopped.");
        }
    }

    private void Engine_OutputDataReceived(object sender, DataReceivedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(e.Data))
        {
            return;
        }

        Dispatch(() =>
        {
            if (!HandleEvent(e.Data))
            {
                Log(e.Data);
            }
        });
    }

    private void Engine_ErrorDataReceived(object sender, DataReceivedEventArgs e)
    {
        if (!string.IsNullOrWhiteSpace(e.Data))
        {
            Dispatch(() => Log($"stderr: {e.Data}"));
        }
    }

    private void Engine_Exited(object? sender, EventArgs e)
    {
        Dispatch(() =>
        {
            if (!_stopRequested)
            {
                State = EngineState.Error;
                Log("The engine exited unexpectedly.");
                _notifications.Show("GyroPlay engine", "The engine exited unexpectedly.");
            }
            else
            {
                State = EngineState.Stopped;
            }

            _process?.Dispose();
            _process = null;
            PhoneStatus = "Disconnected";
            LastPacketText = "Never";
            NotifyStateChanged();
        });
    }

    private bool HandleEvent(string line)
    {
        if (line == "EVENT:PHONE_CONNECTED")
        {
            if (PhoneStatus != "Connected")
            {
                _notifications.Show("Phone connected", "Your phone is paired and sending controller data.");
            }

            PhoneStatus = "Connected";
            NotifyStateChanged();
            return true;
        }

        const string prefix = "EVENT:PACKET_RECEIVED:";
        if (line.StartsWith(prefix, StringComparison.Ordinal))
        {
            var timestampText = line[prefix.Length..];
            LastPacketText = DateTimeOffset.TryParse(timestampText, out var timestamp)
                ? timestamp.ToLocalTime().ToString("HH:mm:ss")
                : DateTime.Now.ToString("HH:mm:ss");
            NotifyStateChanged();
            return true;
        }

        if (line == "EVENT:PHONE_DISCONNECTED")
        {
            if (PhoneStatus == "Connected")
            {
                _notifications.Show("Phone disconnected", "No heartbeat or input was received from the phone.");
            }

            PhoneStatus = "Disconnected";
            LastPacketText = "Never";
            NotifyStateChanged();
            return true;
        }

        return false;
    }

    private EngineLaunchInfo? ResolveLaunchInfo()
    {
        if (File.Exists(_paths.InstalledEnginePath))
        {
            return new EngineLaunchInfo(
                _paths.InstalledEnginePath,
                $"--pairing-file {QuoteArgument(_paths.PairingFilePath)}",
                Path.GetDirectoryName(_paths.InstalledEnginePath) ?? AppContext.BaseDirectory,
                IsDevelopmentFallback: false);
        }

        if (_paths.DevelopmentEnginePath is string devEngine && File.Exists(devEngine))
        {
            return new EngineLaunchInfo(
                devEngine,
                $"--pairing-file {QuoteArgument(_paths.PairingFilePath)}",
                Path.GetDirectoryName(devEngine) ?? AppContext.BaseDirectory,
                IsDevelopmentFallback: true);
        }

        if (_paths.DevelopmentPythonPath is string python &&
            _paths.DevelopmentScriptPath is string script &&
            File.Exists(python) &&
            File.Exists(script))
        {
            return new EngineLaunchInfo(
                python,
                $"-u {QuoteArgument(script)} --pairing-file {QuoteArgument(_paths.PairingFilePath)}",
                Path.GetDirectoryName(script) ?? AppContext.BaseDirectory,
                IsDevelopmentFallback: true);
        }

        return null;
    }

    private void SetStopped()
    {
        State = EngineState.Stopped;
        PhoneStatus = "Disconnected";
        LastPacketText = "Never";
        NotifyStateChanged();
    }

    private void Log(string message)
    {
        _logging.Write(message);
        LogReceived?.Invoke($"[{DateTime.Now:HH:mm:ss}] {message}");
    }

    private void NotifyStateChanged()
    {
        StateChanged?.Invoke();
    }

    private void Dispatch(Action action)
    {
        if (_dispatcherQueue is null || !_dispatcherQueue.TryEnqueue(() => action()))
        {
            action();
        }
    }

    private static string QuoteArgument(string value)
    {
        return $"\"{value.Replace("\"", "\\\"")}\"";
    }

    public void Dispose()
    {
        Stop();
    }

    private sealed record EngineLaunchInfo(string ExecutablePath, string Arguments, string WorkingDirectory, bool IsDevelopmentFallback);
}
