using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;

namespace GyroPlay.Desktop.Services;

public enum CheckState
{
    Ok,
    Missing,
    DisabledOrIncorrect,
    Error,
}

public sealed record CheckResult(string Title, CheckState State, string Message, string? Details = null)
{
    public bool IsOk => State == CheckState.Ok;
}

public sealed record PreflightReport(
    CheckResult Engine,
    CheckResult Driver,
    CheckResult Firewall,
    CheckResult LocalIp,
    CheckResult PairingStorage)
{
    public bool IsReady => Engine.IsOk && Driver.IsOk && Firewall.IsOk && LocalIp.IsOk && PairingStorage.IsOk;
}

public sealed class HealthCheckService
{
    private AppPaths _paths = new();

    public void Initialize(AppPaths paths)
    {
        _paths = paths;
    }

    public Task<PreflightReport> RunPreflightAsync()
    {
        return Task.Run(() => new PreflightReport(
            CheckEngine(),
            CheckDriver(),
            CheckFirewall(),
            CheckLocalIp(),
            CheckPairingStorage()));
    }

    public CheckResult CheckEngine()
    {
        if (File.Exists(_paths.InstalledEnginePath))
        {
            return new CheckResult("Engine executable", CheckState.Ok, "Packaged engine found.", _paths.InstalledEnginePath);
        }

        if (_paths.DevelopmentEnginePath is string devEngine && File.Exists(devEngine))
        {
            return new CheckResult("Engine executable", CheckState.Ok, "Development packaged engine found.", devEngine);
        }

        if (_paths.DevelopmentPythonPath is string python &&
            _paths.DevelopmentScriptPath is string script &&
            File.Exists(python) &&
            File.Exists(script))
        {
            return new CheckResult("Engine executable", CheckState.Ok, "Development Python engine is available.", python);
        }

        return new CheckResult("Engine executable", CheckState.Missing, "The controller engine was not found.", _paths.InstalledEnginePath);
    }

    public CheckResult CheckDriver()
    {
        try
        {
            var result = RunProcess("sc.exe", "query ViGEmBus");
            if (result.ExitCode == 0 && result.Output.Contains("RUNNING", StringComparison.OrdinalIgnoreCase))
            {
                return new CheckResult("ViGEmBus driver", CheckState.Ok, "ViGEmBus is installed and running.");
            }

            if (result.Output.Contains("STOPPED", StringComparison.OrdinalIgnoreCase))
            {
                return new CheckResult("ViGEmBus driver", CheckState.Error, "ViGEmBus is installed but not running.", result.Output.Trim());
            }

            return new CheckResult("ViGEmBus driver", CheckState.Missing, "ViGEmBus is missing or unavailable.", result.Output.Trim());
        }
        catch (Exception error)
        {
            return new CheckResult("ViGEmBus driver", CheckState.Error, "Driver status could not be checked.", error.Message);
        }
    }

    public CheckResult CheckFirewall()
    {
        try
        {
            var result = RunProcess("netsh.exe", "advfirewall firewall show rule name=\"GyroPlay UDP 5005\"");
            if (result.ExitCode == 0 && result.Output.Contains("GyroPlay UDP 5005", StringComparison.OrdinalIgnoreCase))
            {
                if (result.Output.Contains("Enabled:                              No", StringComparison.OrdinalIgnoreCase) ||
                    !result.Output.Contains("LocalPort:                            5005", StringComparison.OrdinalIgnoreCase) ||
                    !result.Output.Contains("Protocol:                             UDP", StringComparison.OrdinalIgnoreCase) ||
                    !result.Output.Contains("Direction:                            In", StringComparison.OrdinalIgnoreCase))
                {
                    return new CheckResult("Firewall rule", CheckState.DisabledOrIncorrect, "The UDP firewall rule exists but is disabled or incorrect.", result.Output.Trim());
                }

                return new CheckResult("Firewall rule", CheckState.Ok, "UDP port 5005 is configured.");
            }

            return new CheckResult("Firewall rule", CheckState.Missing, "The UDP firewall rule is missing.", result.Output.Trim());
        }
        catch (Exception error)
        {
            return new CheckResult("Firewall rule", CheckState.Error, "Firewall status could not be checked.", error.Message);
        }
    }

    public CheckResult CheckLocalIp()
    {
        var ip = GetLocalIpv4Address();
        return ip == "Unavailable"
            ? new CheckResult("Local IPv4", CheckState.Missing, "No local IPv4 address was detected.")
            : new CheckResult("Local IPv4", CheckState.Ok, $"Local IPv4 address: {ip}", ip);
    }

    public CheckResult CheckPairingStorage()
    {
        try
        {
            _paths.EnsureAppDataDirectory();
            var probe = Path.Combine(_paths.AppDataDirectory, ".write-test");
            File.WriteAllText(probe, "ok");
            File.Delete(probe);
            return new CheckResult("Pairing storage", CheckState.Ok, "Runtime pairing storage is writable.", _paths.PairingFilePath);
        }
        catch (Exception error)
        {
            return new CheckResult("Pairing storage", CheckState.Error, "Pairing storage is not writable.", error.Message);
        }
    }

    public static string GetLocalIpv4Address()
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
        }

        try
        {
            var host = Dns.GetHostEntry(Dns.GetHostName());
            var address = host.AddressList.FirstOrDefault(address =>
                address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(address));
            return address?.ToString() ?? "Unavailable";
        }
        catch
        {
            return "Unavailable";
        }
    }

    private static ProcessResult RunProcess(string fileName, string arguments)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException($"Could not start {fileName}.");
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit(3000);
        return new ProcessResult(process.ExitCode, output + error);
    }

    private sealed record ProcessResult(int ExitCode, string Output);
}
