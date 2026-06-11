$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

if (-not (Test-Path ".venv\Scripts\python.exe")) {
    throw "Python virtual environment not found."
}

& ".venv\Scripts\python.exe" -m pip install -r requirements.txt
& ".venv\Scripts\python.exe" -m pip install pyinstaller

Remove-Item -Recurse -Force build, dist -ErrorAction SilentlyContinue
Remove-Item -Force "GyroPlay.Engine.spec" -ErrorAction SilentlyContinue

& ".venv\Scripts\python.exe" -m PyInstaller `
    --onefile `
    --name "GyroPlay.Engine" `
    --console `
    main.py

Write-Host "Built: $PSScriptRoot\dist\GyroPlay.Engine.exe"