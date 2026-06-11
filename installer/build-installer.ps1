[CmdletBinding()]
param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$engineDir = Join-Path $repoRoot "engine\python"
$desktopProject = Join-Path $repoRoot "desktop\winui_app\GyroPlay.Desktop\GyroPlay.Desktop.csproj"
$installerBuild = Join-Path $PSScriptRoot "build"
$desktopPublish = Join-Path $installerBuild "desktop"
$engineStage = Join-Path $installerBuild "engine"
$engineExe = Join-Path $engineDir "dist\GyroPlay.Engine.exe"
$enginePython = Join-Path $engineDir ".venv\Scripts\python.exe"
$engineBuildScript = Join-Path $engineDir "build-engine.ps1"
$issFile = Join-Path $PSScriptRoot "gyroplay.iss"
$outputExe = Join-Path $PSScriptRoot "output\GyroPlaySetup.exe"

function Find-InnoCompiler {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Inno Setup Compiler (ISCC.exe) was not found. Install Inno Setup 6 and retry."
}

Write-Host "Cleaning installer build directory..."
if (Test-Path $installerBuild) {
    Remove-Item -LiteralPath $installerBuild -Recurse -Force
}
New-Item -ItemType Directory -Path $desktopPublish, $engineStage | Out-Null

Write-Host "Building GyroPlay.Engine.exe..."
if (!(Test-Path $enginePython)) {
    throw "Missing engine Python virtual environment: $enginePython"
}

if (!(Test-Path $engineBuildScript)) {
    throw "Missing engine build script: $engineBuildScript"
}

& $engineBuildScript

if (!(Test-Path $engineExe)) {
    throw "Expected packaged engine was not created: $engineExe"
}

Copy-Item -LiteralPath $engineExe -Destination (Join-Path $engineStage "GyroPlay.Engine.exe") -Force

Write-Host "Publishing WinUI desktop app..."
dotnet publish $desktopProject `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:Platform=x64 `
    -p:WindowsPackageType=None `
    -p:WindowsAppSDKSelfContained=true `
    -p:PublishSingleFile=false `
    -p:PublishTrimmed=false `
    -p:PublishReadyToRun=true `
    -o $desktopPublish

$desktopExe = Join-Path $desktopPublish "GyroPlay.Desktop.exe"
if (!(Test-Path $desktopExe)) {
    throw "Expected desktop executable was not published: $desktopExe"
}

if (!(Test-Path (Join-Path $PSScriptRoot "dependencies\ViGEmBus_1.22.0_x64_x86_arm64.exe"))) {
    throw "Missing ViGEmBus installer in installer\dependencies."
}

$iscc = Find-InnoCompiler
Write-Host "Compiling installer with $iscc..."
& $iscc $issFile

if (!(Test-Path $outputExe)) {
    throw "Installer build did not produce: $outputExe"
}

Write-Host "Installer created: $outputExe"
