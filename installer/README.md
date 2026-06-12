# GyroPlay Installer

This folder contains the Inno Setup definition and local build script for the Windows installer.

## Required tools

- Windows x64
- Inno Setup 6
- .NET SDK 8 or newer
- Python virtual environment at `engine\python\.venv`
- Engine build dependencies installed in that virtual environment
- ViGEmBus dependency payload at:

```powershell
installer\dependencies\ViGEmBus_1.22.0_x64_x86_arm64.exe
```

End users do not need Python, Flutter, Visual Studio, or the .NET SDK.

## Build

From the repository root:

```powershell
.\installer\build-installer.ps1
```

The script fails immediately if required payloads are missing. It does not silently reuse stale installer output.

The build performs these steps:

1. Reads the version from `desktop\winui_app\GyroPlay.Desktop\GyroPlay.Desktop.csproj`.
2. Builds `engine\python\dist\GyroPlay.Engine.exe`.
3. Publishes the WinUI app as Release, Windows x64, unpackaged, self-contained.
4. Validates the desktop executable, engine executable, ViGEmBus payload, and troubleshooting docs.
5. Invokes the Inno Setup compiler.
6. Writes the final setup executable and prints its size.

Output:

```powershell
installer\output\GyroPlaySetup-<version>.exe
```

For release builds, create a SHA256 checksum beside the installer:

```powershell
$setup = Get-ChildItem installer\output\GyroPlaySetup-*.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$hash = Get-FileHash -Algorithm SHA256 $setup.FullName
"$($hash.Hash.ToLower())  $($setup.Name)" | Set-Content "$($setup.FullName).sha256"
```

## Installer behavior

The installer:

- Installs GyroPlay under the standard Windows Program Files location.
- Uses a stable AppId for upgrades, reinstalls, repairs, and uninstall.
- Preserves `%LOCALAPPDATA%\GyroPlay` during install, upgrade, repair, and normal uninstall.
- Offers optional removal of `%LOCALAPPDATA%\GyroPlay` during uninstall.
- Creates a Start Menu shortcut.
- Offers an optional Desktop shortcut.
- Installs or repairs ViGEmBus only when needed.
- Adds or repairs the GyroPlay-owned inbound UDP firewall rule for port `5005`.
- Removes the GyroPlay firewall rule during uninstall.
- Installs local troubleshooting documentation.
- Offers to launch GyroPlay after setup, unless a restart is required.

ViGEmBus is not removed during uninstall because other applications may depend on it.

## Dependency handling

Setup checks the ViGEmBus service instead of only checking uninstall registry entries.

Driver states:

- `Installed and running`: setup does not reinstall the driver.
- `Installed but unavailable`: setup offers a repair.
- `Missing`: setup installs the bundled driver.

Firewall states:

- `Configured`: setup leaves the existing GyroPlay rule alone.
- `Missing`: setup creates the rule.
- `Disabled or incorrect`: setup removes the GyroPlay-owned rule and recreates it.

Technical setup notes are written to:

```text
%LOCALAPPDATA%\GyroPlay\Logs\setup.log
```

## Clean-machine test checklist

Validate these scenarios before publishing a Windows release:

- Clean install on supported Windows x64.
- Upgrade over an older GyroPlay version.
- Reinstall the same GyroPlay version.
- Attempt downgrade over a newer GyroPlay version and confirm the warning.
- Repair after deleting the installed `engine\GyroPlay.Engine.exe`.
- Repair after deleting the `GyroPlay UDP 5005` firewall rule.
- Install with ViGEmBus already installed and running.
- Install with ViGEmBus missing.
- Driver installation cancelled or failed.
- Restart-required driver installation result.
- Uninstall while GyroPlay is running.
- Uninstall while preserving user data.
- Uninstall with explicit user-data removal.
