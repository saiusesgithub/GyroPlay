$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

if (-not (Test-Path ".venv\Scripts\python.exe")) {
    throw "Python virtual environment not found."
}

$python = ".venv\Scripts\python.exe"
$pyInstallerDllDestination = "vgamepad/win/vigem/client/x64"

Write-Host "Upgrading pip, setuptools, wheel, and installing PyInstaller..."
& $python -m pip install --upgrade pip setuptools wheel pyinstaller

Write-Host "Cloning vgamepad source..."
$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "vgamepad-source"
if (Test-Path $tempPath) {
    Remove-Item -Recurse -Force $tempPath
}
git clone --depth 1 https://github.com/yannbouteiller/vgamepad.git $tempPath

Write-Host "Patching vgamepad setup.py to skip ViGEmBus MSI launch..."
$setupPath = Join-Path $tempPath "setup.py"
$setupContent = Get-Content $setupPath -Raw
$setupContent = $setupContent -replace `
    "subprocess\.call\(\['msiexec', '/i', '%s' % str\(pathMsi\)\], shell=True\)", `
    "print('Skipping ViGEmBus installation during GyroPlay engine build')"
Set-Content -Path $setupPath -Value $setupContent -Encoding utf8

if ((Get-Content $setupPath -Raw) -match "subprocess\.call\(\['msiexec'") {
    throw "Failed to patch the ViGEmBus installer call in vgamepad setup.py."
}

Write-Host "Installing patched vgamepad source without build isolation..."
& $python -m pip install --no-build-isolation $tempPath

Write-Host "Verifying vgamepad package installation without importing it..."
& $python -m pip show vgamepad
if ($LASTEXITCODE -ne 0) {
    throw "vgamepad package was not installed successfully."
}

Write-Host "Installing remaining runtime requirements without reinstalling vgamepad..."
$filteredRequirements = "requirements-build.txt"
$runtimeRequirements = @(Get-Content requirements.txt |
    Where-Object {
        $line = $_.Trim()
        $line -and
            -not $line.StartsWith("#") -and
            $line -notmatch "(?i)^vgamepad([<>=!~ ].*)?$"
    })

if ($runtimeRequirements.Count -gt 0) {
    $runtimeRequirements | Set-Content -Path $filteredRequirements -Encoding utf8
    & $python -m pip install -r $filteredRequirements
}
else {
    Write-Host "No additional runtime requirements found."
}

Write-Host "Locating vgamepad native ViGEm client DLL..."
$dllPath = & $python -c "from importlib import metadata; dist = metadata.distribution('vgamepad'); print(dist.locate_file('vgamepad/win/vigem/client/x64/ViGEmClient.dll'))"
$dllPath = $dllPath.Trim()

if (-not (Test-Path $dllPath)) {
    throw "Required vgamepad native DLL was not found: $dllPath"
}

Write-Host "Discovered ViGEmClient.dll: $dllPath"
Write-Host "PyInstaller destination: $pyInstallerDllDestination"

if (-not (Test-Path "hooks\hook-vgamepad.py")) {
    throw "Missing PyInstaller vgamepad hook: $PSScriptRoot\hooks\hook-vgamepad.py"
}

Remove-Item -Recurse -Force build, dist -ErrorAction SilentlyContinue

Write-Host "Building GyroPlay.Engine.exe with PyInstaller..."
Write-Host "Command: $python -m PyInstaller --onefile --console --name GyroPlay.Engine --specpath build --additional-hooks-dir hooks --add-binary `"$dllPath;$pyInstallerDllDestination`" main.py"
& $python -m PyInstaller `
    --onefile `
    --console `
    --name "GyroPlay.Engine" `
    --specpath build `
    --additional-hooks-dir hooks `
    --add-binary "$dllPath;$pyInstallerDllDestination" `
    main.py

if (-not (Test-Path "dist\GyroPlay.Engine.exe")) {
    throw "GyroPlay.Engine.exe was not generated."
}

Write-Host "Built: $PSScriptRoot\dist\GyroPlay.Engine.exe"
