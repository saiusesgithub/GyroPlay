# Contributing to GyroPlay

Thanks for helping improve GyroPlay. Keep changes focused, testable, and aligned with the current local-network controller architecture.

## Repository Structure

- `mobile/flutter_app/` - Flutter Android app.
- `desktop/winui_app/GyroPlay.Desktop/` - WinUI 3 desktop control panel.
- `engine/python/` - Python UDP engine and virtual gamepad bridge.
- `protocol/` - UDP packet format documentation.
- `installer/` - Inno Setup installer and build script.
- `docs/` - setup, troubleshooting, architecture, and project docs.
- `.github/workflows/` - CI and release workflows.

## Prerequisites

- Flutter SDK and Android Studio for Android work.
- .NET SDK 8 or newer for desktop work.
- Windows App SDK / WinUI tooling for desktop development.
- Python virtual environment for engine development.
- Inno Setup 6 for installer builds.
- ViGEmBus on Windows for local controller testing.

## Branching

Use short descriptive branch names:

- `fix/android-sdk-36`
- `feat/tilt-calibration`
- `docs/setup-guide`
- `ci/release-installer`

## Commit Messages

Use concise conventional-style commits where practical:

- `feat(mobile): add controller profile editor`
- `fix(engine): reset triggers on timeout`
- `docs: update setup guide`
- `ci: install Android SDK 36`

## Running the Mobile App

```powershell
cd mobile\flutter_app
flutter pub get
flutter analyze
flutter run
```

Build the release APK:

```powershell
cd mobile\flutter_app
flutter build apk --release --target-platform android-arm64
```

## Running the Desktop App

```powershell
dotnet build desktop\winui_app\GyroPlay.Desktop\GyroPlay.Desktop.csproj -c Release -p:Platform=x64
```

Run the project from Visual Studio or from the published output.

## Running the Python Engine

```powershell
cd engine\python
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe main.py
```

Package the engine:

```powershell
cd engine\python
.\build-engine.ps1
```

## Building the Windows Installer

```powershell
.\installer\build-installer.ps1
```

The installer build requires the ViGEmBus dependency payload under `installer/dependencies/`.

## Testing Expectations

Run checks for the area you changed.

Mobile:

```powershell
cd mobile\flutter_app
flutter analyze
flutter build apk --release --target-platform android-arm64
```

Desktop:

```powershell
dotnet build desktop\winui_app\GyroPlay.Desktop\GyroPlay.Desktop.csproj -c Release -p:Platform=x64
```

Engine:

```powershell
cd engine\python
.\.venv\Scripts\python.exe -m py_compile main.py test_sender.py
```

Installer:

```powershell
.\installer\build-installer.ps1
```

Manual checks that matter:

- Phone pairs by QR.
- Engine starts and stops from the desktop app.
- Virtual controller appears in `joy.cpl`.
- Steering, throttle, brake, gears, and handbrake reset correctly.
- Installer repair does not delete LocalAppData settings.

## Issues

When opening an issue, include:

- GyroPlay version.
- Android version.
- Windows version.
- Whether `joy.cpl` detects the controller.
- Steps to reproduce.
- Logs with pairing tokens removed.

Use the issue tracker:

https://github.com/saiusesgithub/GyroPlay/issues

## Pull Requests

Before opening a pull request:

- Keep the scope focused.
- Explain the user-visible behavior change.
- List the commands you ran.
- Add screenshots for UI changes.
- Update docs when setup, protocol, installer, or release behavior changes.
- Do not commit build output, virtual environments, tokens, or local machine paths.

## Protocol Changes

Protocol changes must update:

- `protocol/protocol.md`
- `protocol/sample-packets.json`
- mobile sender logic
- engine validation logic

Avoid breaking existing packet formats without a clear migration reason.
