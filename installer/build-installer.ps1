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
$driverInstaller = Join-Path $PSScriptRoot "dependencies\ViGEmBus_1.22.0_x64_x86_arm64.exe"
$troubleshootingDoc = Join-Path $repoRoot "docs\troubleshooting.md"
$brandSourceIcon = Join-Path $repoRoot "gyroplay-icon.png"
$brandGenerator = Join-Path $repoRoot "tools\generate-brand-assets.ps1"
$installerIcon = Join-Path $PSScriptRoot "assets\GyroPlay.ico"
$installerWizardImage = Join-Path $PSScriptRoot "assets\WizardImage.png"
$installerWizardSmallImage = Join-Path $PSScriptRoot "assets\WizardSmallImage.png"
$outputDir = Join-Path $PSScriptRoot "output"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Assert-File {
    param(
        [string]$Path,
        [string]$Message
    )

    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Message`nMissing file: $Path"
    }
}

function Find-InnoCompiler {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Inno Setup Compiler (ISCC.exe) was not found. Install Inno Setup 6 and retry."
}

function Get-DesktopVersion {
    [xml]$projectXml = Get-Content -LiteralPath $desktopProject
    $version = $projectXml.Project.PropertyGroup |
        ForEach-Object { $_.Version } |
        Where-Object { $_ } |
        Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "Could not read <Version> from $desktopProject"
    }

    return $version.Trim()
}

$appVersion = Get-DesktopVersion
$outputExe = Join-Path $outputDir "GyroPlaySetup-$appVersion.exe"

Write-Step "Preparing installer build for GyroPlay $appVersion"
Assert-File -Path $desktopProject -Message "The WinUI desktop project could not be found."
Assert-File -Path $issFile -Message "The Inno Setup script could not be found."
Assert-File -Path $driverInstaller -Message "The ViGEmBus dependency payload is required for setup and repair."
Assert-File -Path $troubleshootingDoc -Message "The local troubleshooting document is required for installed diagnostics."
Assert-File -Path $engineBuildScript -Message "The engine build script could not be found."
Assert-File -Path $brandSourceIcon -Message "The root GyroPlay brand icon is required to generate installer and app assets."
Assert-File -Path $brandGenerator -Message "The brand asset generator script could not be found."

Write-Step "Cleaning stale installer output"
if (Test-Path -LiteralPath $installerBuild) {
    Remove-Item -LiteralPath $installerBuild -Recurse -Force
}
if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $desktopPublish, $engineStage, $outputDir | Out-Null

Write-Step "Generating branding assets from root icon"
& $brandGenerator
Assert-File -Path $installerIcon -Message "Installer icon generation failed."
Assert-File -Path $installerWizardImage -Message "Installer wizard image generation failed."
Assert-File -Path $installerWizardSmallImage -Message "Installer small wizard image generation failed."

Write-Step "Building packaged controller engine"
Assert-File -Path $enginePython -Message "Missing engine Python virtual environment. Create engine\python\.venv and install engine build dependencies."
& $engineBuildScript
Assert-File -Path $engineExe -Message "Expected packaged engine was not created."
Copy-Item -LiteralPath $engineExe -Destination (Join-Path $engineStage "GyroPlay.Engine.exe") -Force

Write-Step "Publishing WinUI desktop app as Release x64 self-contained unpackaged"
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
Assert-File -Path $desktopExe -Message "Expected desktop executable was not published."

Write-Step "Validating installer payload"
$requiredPayloads = @(
    $desktopExe,
    (Join-Path $engineStage "GyroPlay.Engine.exe"),
    $driverInstaller,
    $troubleshootingDoc
)

foreach ($payload in $requiredPayloads) {
    Assert-File -Path $payload -Message "Installer payload validation failed."
    Write-Host "Found: $payload"
}

$iscc = Find-InnoCompiler
Write-Step "Compiling Inno Setup installer"
Write-Host "Compiler: $iscc"
& $iscc "/DAppVersion=$appVersion" $issFile

Assert-File -Path $outputExe -Message "Installer build did not produce the expected setup executable."

$installerFile = Get-Item -LiteralPath $outputExe
$sizeMb = [Math]::Round($installerFile.Length / 1MB, 2)

Write-Step "Installer build complete"
Write-Host "Output: $($installerFile.FullName)"
Write-Host "Size: $sizeMb MB"
