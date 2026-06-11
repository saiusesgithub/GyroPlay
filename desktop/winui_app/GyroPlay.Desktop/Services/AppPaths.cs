using System;
using System.IO;

namespace GyroPlay.Desktop.Services;

public sealed class AppPaths
{
    public string AppDataDirectory =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GyroPlay");

    public string SettingsFilePath => Path.Combine(AppDataDirectory, "settings.json");

    public string PairingFilePath => Path.Combine(AppDataDirectory, "pairing.json");

    public string LogDirectory => Path.Combine(AppDataDirectory, "Logs");

    public string InstalledEnginePath => Path.Combine(AppContext.BaseDirectory, "engine", "GyroPlay.Engine.exe");

    public string InstalledDriverInstallerPath =>
        Path.Combine(AppContext.BaseDirectory, "dependencies", "ViGEmBus_1.22.0_x64_x86_arm64.exe");

    public string? RepositoryRoot => TryGetRepositoryRoot();

    public string? DevelopmentEnginePath =>
        RepositoryRoot is string root ? Path.Combine(root, "engine", "python", "dist", "GyroPlay.Engine.exe") : null;

    public string? DevelopmentPythonPath =>
        RepositoryRoot is string root ? Path.Combine(root, "engine", "python", ".venv", "Scripts", "python.exe") : null;

    public string? DevelopmentScriptPath =>
        RepositoryRoot is string root ? Path.Combine(root, "engine", "python", "main.py") : null;

    public string? TroubleshootingPath
    {
        get
        {
            var installed = Path.Combine(AppContext.BaseDirectory, "docs", "troubleshooting.md");
            if (File.Exists(installed))
            {
                return installed;
            }

            return RepositoryRoot is string root ? Path.Combine(root, "docs", "troubleshooting.md") : null;
        }
    }

    public string? DevelopmentDriverInstallerPath =>
        RepositoryRoot is string root ? Path.Combine(root, "installer", "dependencies", "ViGEmBus_1.22.0_x64_x86_arm64.exe") : null;

    public string? DriverInstallerPath
    {
        get
        {
            if (File.Exists(InstalledDriverInstallerPath))
            {
                return InstalledDriverInstallerPath;
            }

            if (DevelopmentDriverInstallerPath is string path && File.Exists(path))
            {
                return path;
            }

            return null;
        }
    }

    public void EnsureAppDataDirectory()
    {
        Directory.CreateDirectory(AppDataDirectory);
    }

    private static string? TryGetRepositoryRoot()
    {
        for (var current = new DirectoryInfo(AppContext.BaseDirectory);
             current is not null;
             current = current.Parent)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "engine", "python")) &&
                Directory.Exists(Path.Combine(current.FullName, "desktop", "winui_app")))
            {
                return current.FullName;
            }
        }

        return null;
    }
}
