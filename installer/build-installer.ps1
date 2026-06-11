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
$appLogoPng = Join-Path $repoRoot "desktop\winui_app\GyroPlay.Desktop\Assets\Square44x44Logo.scale-200.png"
$setupIcon = Join-Path $installerBuild "gyroplay.ico"
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

function Convert-PngToSingleImageIcon {
    param(
        [string]$PngPath,
        [string]$IconPath
    )

    $pngBytes = [System.IO.File]::ReadAllBytes($PngPath)
    if ($pngBytes.Length -lt 33) {
        throw "Logo PNG is too small to convert into an installer icon: $PngPath"
    }

    $width = ($pngBytes[16] -shl 24) -bor ($pngBytes[17] -shl 16) -bor ($pngBytes[18] -shl 8) -bor $pngBytes[19]
    $height = ($pngBytes[20] -shl 24) -bor ($pngBytes[21] -shl 16) -bor ($pngBytes[22] -shl 8) -bor $pngBytes[23]

    $widthByte = if ($width -ge 256) { 0 } else { [byte]$width }
    $heightByte = if ($height -ge 256) { 0 } else { [byte]$height }

    $stream = [System.IO.File]::Create($IconPath)
    try {
        $writer = New-Object System.IO.BinaryWriter($stream)
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]1)
        $writer.Write([byte]$widthByte)
        $writer.Write([byte]$heightByte)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$pngBytes.Length)
        $writer.Write([UInt32]22)
        $writer.Write($pngBytes)
    }
    finally {
        if ($writer) {
            $writer.Dispose()
        }
        else {
            $stream.Dispose()
        }
    }
}

$appVersion = Get-DesktopVersion
$outputExe = Join-Path $outputDir "GyroPlaySetup-$appVersion.exe"

Write-Step "Preparing installer build for GyroPlay $appVersion"
Assert-File -Path $desktopProject -Message "The WinUI desktop project could not be found."
Assert-File -Path $issFile -Message "The Inno Setup script could not be found."
Assert-File -Path $driverInstaller -Message "The ViGEmBus dependency payload is required for setup and repair."
Assert-File -Path $troubleshootingDoc -Message "The local troubleshooting document is required for installed diagnostics."
Assert-File -Path $engineBuildScript -Message "The engine build script could not be found."
Assert-File -Path $appLogoPng -Message "The desktop app logo is required to generate the installer icon."

Write-Step "Cleaning stale installer output"
if (Test-Path -LiteralPath $installerBuild) {
    Remove-Item -LiteralPath $installerBuild -Recurse -Force
}
if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $desktopPublish, $engineStage, $outputDir | Out-Null

Write-Step "Generating installer branding icon"
Convert-PngToSingleImageIcon -PngPath $appLogoPng -IconPath $setupIcon
Assert-File -Path $setupIcon -Message "Installer icon generation failed."

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
