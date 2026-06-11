# GyroPlay Installer

This folder contains the Inno Setup installer definition and build script.

## Prerequisites

- Windows x64
- Inno Setup 6 installed
- .NET SDK for building the installer artifacts
- Python virtual environment in `engine\python\.venv`
- PyInstaller installed in the engine virtual environment
- ViGEmBus installer at:

```powershell
installer\dependencies\ViGEmBus_1.22.0_x64_x86_arm64.exe
```

End users do not need Python, Flutter, Visual Studio, or the .NET SDK.

## Build

From the repository root:

```powershell
.\installer\build-installer.ps1
```

The script:

1. Builds `engine\python\dist\GyroPlay.Engine.exe`.
2. Publishes the WinUI desktop app as Windows x64, unpackaged, self-contained, Release.
3. Stages the desktop app and engine executable under `installer\build`.
4. Runs the Inno Setup compiler.
5. Outputs:

```powershell
installer\output\GyroPlaySetup.exe
```

For release builds, generate a SHA256 checksum beside the installer:

```powershell
$hash = Get-FileHash -Algorithm SHA256 installer\output\GyroPlaySetup.exe
"$($hash.Hash.ToLower())  GyroPlaySetup.exe" | Set-Content installer\output\GyroPlaySetup.exe.sha256
```

## Installer Behavior

The installer:

- Installs GyroPlay under `C:\Program Files\GyroPlay`.
- Creates a Start Menu shortcut.
- Offers an optional Desktop shortcut.
- Installs ViGEmBus if it is missing.
- Adds an inbound Windows Firewall rule named `GyroPlay UDP 5005`.
- Removes that firewall rule during uninstall.
- Offers to launch GyroPlay after installation.
