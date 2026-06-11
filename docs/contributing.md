# Contributing to GyroPlay

GyroPlay is early-stage software. Keep changes small, testable, and aligned with the current architecture.

## Project Areas

- `mobile/flutter_app/` - Flutter Android controller UI and UDP client.
- `engine/python/` - Python UDP server and virtual Xbox controller mapping.
- `desktop/winui_app/GyroPlay.Desktop/` - WinUI 3 control panel.
- `protocol/` - packet formats and compatibility notes.
- `installer/` - Windows installer and release packaging.

## Development Rules

- Keep protocol changes documented in `protocol/protocol.md` and `protocol/sample-packets.json`.
- Avoid adding new services, accounts, cloud features, or broad architecture without discussion.
- Keep mobile, engine, desktop, and installer changes scoped to the feature being worked on.
- Prefer readable proof-of-concept code over premature abstractions.
- Do not commit generated build output, local virtual environments, or secrets.

## Local Checks

Run the checks relevant to the area you changed.

### Flutter

```powershell
cd mobile\flutter_app
flutter pub get
flutter analyze
flutter test
```

### Python Engine

```powershell
cd engine\python
.\.venv\Scripts\python.exe -m py_compile main.py test_sender.py
```

### WinUI Desktop

```powershell
dotnet build desktop\winui_app\GyroPlay.Desktop\GyroPlay.Desktop.csproj -c Release -p:Platform=x64
```

### Installer

```powershell
.\installer\build-installer.ps1
```

## Pull Requests

- Explain the user-visible behavior change.
- List the commands you ran.
- Include screenshots for UI changes.
- Update documentation when setup, protocol, or release behavior changes.

