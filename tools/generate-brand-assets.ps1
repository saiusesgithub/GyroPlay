[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$sourceIcon = Join-Path $repoRoot "gyroplay-icon.png"
$mobileRoot = Join-Path $repoRoot "mobile\flutter_app"
$androidRes = Join-Path $mobileRoot "android\app\src\main\res"
$mobileBranding = Join-Path $mobileRoot "assets\branding"
$desktopAssets = Join-Path $repoRoot "desktop\winui_app\GyroPlay.Desktop\Assets"
$installerAssets = Join-Path $repoRoot "installer\assets"

if (!(Test-Path -LiteralPath $sourceIcon -PathType Leaf)) {
    throw "Source brand icon is missing: $sourceIcon"
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function New-Directory {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Save-ContainedPng {
    param(
        [System.Drawing.Image]$Source,
        [string]$Path,
        [int]$Width,
        [int]$Height,
        [string]$Background = "Transparent",
        [double]$Scale = 0.82
    )

    New-Directory (Split-Path -Parent $Path)
    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        if ($Background -eq "Transparent") {
            $graphics.Clear([System.Drawing.Color]::Transparent)
        }
        else {
            $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml($Background))
        }

        $boxWidth = $Width * $Scale
        $boxHeight = $Height * $Scale
        $sourceRatio = $Source.Width / $Source.Height
        $boxRatio = $boxWidth / $boxHeight

        if ($sourceRatio -gt $boxRatio) {
            $drawWidth = $boxWidth
            $drawHeight = $drawWidth / $sourceRatio
        }
        else {
            $drawHeight = $boxHeight
            $drawWidth = $drawHeight * $sourceRatio
        }

        $x = ($Width - $drawWidth) / 2
        $y = ($Height - $drawHeight) / 2
        $graphics.DrawImage($Source, [System.Drawing.RectangleF]::new($x, $y, $drawWidth, $drawHeight))
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }

    Write-Host "Generated $Path"
}

function Save-MonochromePng {
    param(
        [System.Drawing.Image]$Source,
        [string]$Path,
        [int]$Size
    )

    New-Directory (Split-Path -Parent $Path)
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) "gyroplay-mono-$Size.png"
    Save-ContainedPng -Source $Source -Path $temp -Width $Size -Height $Size -Scale 0.64

    $src = [System.Drawing.Bitmap]::FromFile($temp)
    $dst = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        for ($y = 0; $y -lt $Size; $y++) {
            for ($x = 0; $x -lt $Size; $x++) {
                $pixel = $src.GetPixel($x, $y)
                if ($pixel.A -gt 0) {
                    $dst.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($pixel.A, 255, 255, 255))
                }
            }
        }
        $dst.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $src.Dispose()
        $dst.Dispose()
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Generated $Path"
}

function Save-Ico {
    param(
        [System.Drawing.Image]$Source,
        [string]$Path,
        [int[]]$Sizes
    )

    New-Directory (Split-Path -Parent $Path)
    $images = @()
    foreach ($size in $Sizes) {
        $stream = New-Object System.IO.MemoryStream
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "gyroplay-ico-$size.png"
        Save-ContainedPng -Source $Source -Path $tempPath -Width $size -Height $size -Scale 0.82
        $bytes = [System.IO.File]::ReadAllBytes($tempPath)
        Remove-Item -LiteralPath $tempPath -Force
        $images += ,@($size, $bytes)
    }

    $file = [System.IO.File]::Create($Path)
    $writer = New-Object System.IO.BinaryWriter($file)
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$images.Count)
        $offset = 6 + (16 * $images.Count)
        foreach ($entry in $images) {
            $size = [int]$entry[0]
            $bytes = [byte[]]$entry[1]
            $writer.Write([byte]($(if ($size -ge 256) { 0 } else { $size })))
            $writer.Write([byte]($(if ($size -ge 256) { 0 } else { $size })))
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$bytes.Length)
            $writer.Write([UInt32]$offset)
            $offset += $bytes.Length
        }
        foreach ($entry in $images) {
            $writer.Write([byte[]]$entry[1])
        }
    }
    finally {
        $writer.Dispose()
    }

    Write-Host "Generated $Path"
}

function Set-TextFile {
    param([string]$Path, [string]$Content)
    New-Directory (Split-Path -Parent $Path)
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
    Write-Host "Generated $Path"
}

$source = [System.Drawing.Image]::FromFile($sourceIcon)
try {
    Write-Host "Source: $sourceIcon ($($source.Width)x$($source.Height), $($source.PixelFormat))"

    New-Directory $mobileBranding
    Save-ContainedPng -Source $source -Path (Join-Path $mobileBranding "gyroplay-icon.png") -Width 512 -Height 512 -Scale 0.84

    $launcherSizes = @{
        "mipmap-mdpi" = 48
        "mipmap-hdpi" = 72
        "mipmap-xhdpi" = 96
        "mipmap-xxhdpi" = 144
        "mipmap-xxxhdpi" = 192
    }
    foreach ($density in $launcherSizes.Keys) {
        $size = $launcherSizes[$density]
        Save-ContainedPng -Source $source -Path (Join-Path $androidRes "$density\ic_launcher.png") -Width $size -Height $size -Scale 0.82
        Save-ContainedPng -Source $source -Path (Join-Path $androidRes "$density\ic_launcher_foreground.png") -Width ([int]($size * 2.25)) -Height ([int]($size * 2.25)) -Scale 0.54
        Save-MonochromePng -Source $source -Path (Join-Path $androidRes "$density\ic_launcher_monochrome.png") -Size ([int]($size * 2.25))
    }

    Save-ContainedPng -Source $source -Path (Join-Path $androidRes "drawable\splash_icon.png") -Width 144 -Height 144 -Scale 0.82
    Save-ContainedPng -Source $source -Path (Join-Path $androidRes "drawable-v31\splash_icon.png") -Width 288 -Height 288 -Scale 0.58

    Set-TextFile -Path (Join-Path $androidRes "values\colors.xml") -Content @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="gyroplay_splash_background">#0E1318</color>
</resources>
"@

    Set-TextFile -Path (Join-Path $androidRes "drawable\ic_launcher_background.xml") -Content @"
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="@color/gyroplay_splash_background" />
</shape>
"@

    Set-TextFile -Path (Join-Path $androidRes "drawable\launch_background.xml") -Content @"
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/gyroplay_splash_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/splash_icon" />
    </item>
</layer-list>
"@

    Set-TextFile -Path (Join-Path $androidRes "drawable-v21\launch_background.xml") -Content @"
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/gyroplay_splash_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/splash_icon" />
    </item>
</layer-list>
"@

    Set-TextFile -Path (Join-Path $androidRes "mipmap-anydpi-v26\ic_launcher.xml") -Content @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"@

    Set-TextFile -Path (Join-Path $androidRes "mipmap-anydpi-v26\ic_launcher_round.xml") -Content @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"@

    $winAssets = @(
        @("Square44x44Logo.png", 44, 44, 0.78),
        @("Square44x44Logo.scale-200.png", 88, 88, 0.78),
        @("Square44x44Logo.targetsize-16.png", 16, 16, 0.86),
        @("Square44x44Logo.targetsize-24.png", 24, 24, 0.86),
        @("Square44x44Logo.targetsize-24_altform-unplated.png", 24, 24, 0.86),
        @("Square44x44Logo.targetsize-32.png", 32, 32, 0.84),
        @("Square44x44Logo.targetsize-48.png", 48, 48, 0.82),
        @("Square44x44Logo.targetsize-256.png", 256, 256, 0.82),
        @("Square150x150Logo.png", 150, 150, 0.76),
        @("Square150x150Logo.scale-200.png", 300, 300, 0.76),
        @("StoreLogo.png", 50, 50, 0.82),
        @("LockScreenLogo.scale-200.png", 48, 48, 0.84),
        @("SplashScreen.png", 620, 300, 0.34),
        @("SplashScreen.scale-200.png", 1240, 600, 0.34),
        @("Wide310x150Logo.png", 310, 150, 0.36),
        @("Wide310x150Logo.scale-200.png", 620, 300, 0.36)
    )

    foreach ($asset in $winAssets) {
        Save-ContainedPng -Source $source -Path (Join-Path $desktopAssets $asset[0]) -Width $asset[1] -Height $asset[2] -Scale $asset[3]
    }

    Save-Ico -Source $source -Path (Join-Path $desktopAssets "GyroPlay.ico") -Sizes @(16, 24, 32, 48, 64, 128, 256)

    New-Directory $installerAssets
    Copy-Item -LiteralPath (Join-Path $desktopAssets "GyroPlay.ico") -Destination (Join-Path $installerAssets "GyroPlay.ico") -Force
    Save-ContainedPng -Source $source -Path (Join-Path $installerAssets "WizardSmallImage.png") -Width 55 -Height 55 -Scale 0.82
    Save-ContainedPng -Source $source -Path (Join-Path $installerAssets "WizardImage.png") -Width 164 -Height 314 -Background "#0E1318" -Scale 0.58
    Write-Host "Generated $(Join-Path $installerAssets "GyroPlay.ico")"
}
finally {
    $source.Dispose()
}
