using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;

namespace GyroPlay.Desktop.Services;

public enum RepairKind
{
    Driver,
    Firewall,
    Setup,
}

public sealed record RepairResult(bool Success, string Message, int? ExitCode = null);

public sealed class RepairService
{
    private AppPaths _paths = new();
    private LoggingService _logging = new();
    private bool _isRunning;

    public bool IsRunning => _isRunning;

    public void Initialize(AppPaths paths, LoggingService logging)
    {
        _paths = paths;
        _logging = logging;
    }

    public async Task<RepairResult> RunAsync(RepairKind kind)
    {
        if (_isRunning)
        {
            return new RepairResult(false, "A repair operation is already running.");
        }

        _isRunning = true;
        try
        {
            return kind switch
            {
                RepairKind.Driver => await RepairDriverAsync(),
                RepairKind.Firewall => await RepairFirewallAsync(),
                _ => await RepairSetupAsync(),
            };
        }
        finally
        {
            _isRunning = false;
        }
    }

    private async Task<RepairResult> RepairSetupAsync()
    {
        var driver = await RepairDriverAsync();
        if (!driver.Success)
        {
            return driver;
        }

        return await RepairFirewallAsync();
    }

    private Task<RepairResult> RepairDriverAsync()
    {
        if (_paths.DriverInstallerPath is not string installer || !File.Exists(installer))
        {
            return Task.FromResult(new RepairResult(false, "The ViGEmBus installer was not found. Re-run the GyroPlay installer."));
        }

        return RunElevatedAsync($"Start-Process -FilePath '{Escape(installer)}' -ArgumentList '/quiet /norestart' -Wait");
    }

    private Task<RepairResult> RepairFirewallAsync()
    {
        const string command = "netsh advfirewall firewall add rule name=\"GyroPlay UDP 5005\" dir=in action=allow protocol=UDP localport=5005 profile=any";
        return RunElevatedAsync(command);
    }

    private Task<RepairResult> RunElevatedAsync(string command)
    {
        return Task.Run(() =>
        {
            try
            {
                _logging.Write("Requesting administrator approval for setup repair.");
                var startInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{command}\"",
                    UseShellExecute = true,
                    Verb = "runas",
                    WindowStyle = ProcessWindowStyle.Hidden,
                };

                using var process = Process.Start(startInfo);
                if (process is null)
                {
                    return new RepairResult(false, "The repair process could not be started.");
                }

                process.WaitForExit();
                var success = process.ExitCode == 0;
                var message = success ? "Setup repair completed." : "Setup repair did not complete successfully.";
                _logging.Write($"{message} Exit code: {process.ExitCode}");
                return new RepairResult(success, message, process.ExitCode);
            }
            catch (System.ComponentModel.Win32Exception)
            {
                return new RepairResult(false, "Repair was cancelled.");
            }
            catch (Exception error)
            {
                return new RepairResult(false, $"Repair failed. {error.Message}");
            }
        });
    }

    private static string Escape(string value) => value.Replace("'", "''");
}
