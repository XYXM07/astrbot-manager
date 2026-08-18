# Build pipeline: create project -> copy sources -> patch -> pub get -> build APK
# Invoked inside PowerShell 5.1 session: & "tools\build-app.ps1" [-ToolchainDir PATH]
# NOTE: keep this file pure ASCII (PS 5.1 reads BOM-less scripts as ANSI)
param([string]$ToolchainDir = "")
$ErrorActionPreference = 'Stop'
if ($ToolchainDir -eq "") { $ToolchainDir = "$env:TEMP\dsh-tools" }
$t = $ToolchainDir
$ws = Split-Path -Parent $PSScriptRoot          # workspace dir (may contain CJK chars)
$dart = "$t\flutter\bin\cache\dart-sdk\bin\dart.exe"
$snap = "$t\flutter\bin\cache\flutter_tools.snapshot"
$pkgs = "$t\flutter\packages\flutter_tools\.dart_tool\package_config.json"
$proj = "$t\app"
$jdkDirs = Get-ChildItem $t -Directory | Where-Object { $_.Name -like 'jdk*' }
$jdk = ($jdkDirs | Where-Object { Test-Path (Join-Path $_.FullName 'bin\jlink.exe') } | Select-Object -First 1).FullName
if (-not $jdk) { $jdk = ($jdkDirs | Select-Object -First 1).FullName }
Write-Output "using JDK: $jdk"

$env:JAVA_HOME = $jdk
$env:ANDROID_HOME = "$t\android-sdk"
$env:ANDROID_SDK_ROOT = "$t\android-sdk"
$env:GRADLE_USER_HOME = "$t\.gradle"
$env:PUB_CACHE = "$t\.pub-cache"
$env:APPDATA = "$t\appdata"
$env:LOCALAPPDATA = "$t\appdata"
$env:PATH = "$t\flutter\bin\mingit\cmd;$t\flutter\bin\mingit\mingw64\bin;$t\flutter\bin\mingit\usr\bin;$env:PATH"
$env:TEMP = "$t\tmp"
$env:TMP = "$t\tmp"
New-Item -ItemType Directory -Force -Path "$t\tmp" | Out-Null
$gitOk = $false
foreach ($i in 1..3) {
  & "$t\flutter\bin\mingit\cmd\git.exe" --version 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { $gitOk = $true; break }
  Start-Sleep -Seconds 2
}
if (-not $gitOk) { throw 'git self-check failed' }
Write-Output 'git self-check ok'
New-Item -ItemType Directory -Force -Path "$t\appdata", "$t\.gradle", "$t\.pub-cache" | Out-Null

function Run-Flutter([string[]]$CmdArgs) {
  & $dart --packages="$pkgs" $snap @CmdArgs
  if ($LASTEXITCODE -ne 0) { throw "flutter failed: $CmdArgs" }
}

Write-Output '=== ensure version.json (bypass git) ==='
$vj = "$t\flutter\bin\cache\flutter.version.json"
if (-not (Test-Path $vj)) {
  $json = '{"frameworkVersion":"3.29.3","channel":"stable","repositoryUrl":"https://github.com/flutter/flutter.git","frameworkRevision":"69c3bb2e113c165cae2f740d32ace02fa92edac8","frameworkCommitDate":"2025-04-14T17:19:54.510470Z","engineRevision":"cf56914b326edb0ccb123ffdc60f00060bd513fa","dartSdkVersion":"3.7.2","devToolsVersion":"2.44.0","flutterVersion":"3.29.3"}'
  [System.IO.File]::WriteAllText($vj, $json, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output 'version.json written'
}

Write-Output '=== flutter create ==='
if (Test-Path $proj) { Remove-Item $proj -Recurse -Force }
Run-Flutter @('create', '--org', 'dev.astr', '--project-name', 'astrbot_manager', '--platforms', 'android', $proj)

Write-Output '=== copy sources ==='
Copy-Item "$ws\app\lib" $proj -Recurse -Force
Copy-Item "$ws\app\assets" $proj -Recurse -Force
Copy-Item "$ws\app\pubspec.yaml" $proj -Force
Copy-Item "$ws\app\analysis_options.yaml" $proj -Force
New-Item -ItemType Directory -Force -Path "$proj\test" | Out-Null
Copy-Item "$ws\app\test\widget_test.dart" "$proj\test\" -Force

Write-Output '=== patch AndroidManifest (label + INTERNET) ==='
$mf = "$proj\android\app\src\main\AndroidManifest.xml"
$label = 'astrbot' + [char]0x52A9 + [char]0x624B          # astrbot + 助 + 手 = astrbot助手
$c = [System.IO.File]::ReadAllText($mf)
$c = $c.Replace('android:label="astrbot_manager"', ('android:label="' + $label + '"'))
if (-not $c.Contains('android.permission.INTERNET')) {
  $needle = '<application'
  $insert = '<uses-permission android:name="android.permission.INTERNET" />'
  $c = $c.Replace($needle, $insert + "`r`n`r`n    " + $needle)
}
# Allow WebView to load http://127.0.0.1 (SSH tunnel to server WebUI)
if (-not $c.Contains('usesCleartextTraffic')) {
  $c = $c.Replace('<application', '<application android:usesCleartextTraffic="true"')
}
# Disable Impeller (fall back to Skia): some Adreno/MIUI GPUs render glyph
# atlas tiles as solid yellow strips over text fields under Impeller.
$c = $c.Replace('</application>', '    <meta-data' + "`r`n        " + 'android:name="io.flutter.embedding.android.EnableImpeller"' + "`r`n        " + 'android:value="false" />' + "`r`n    " + '</application>')
# Opt the activity out of the Android autofill framework: the system draws a
# yellow autofill highlight over autofillable text fields on some OEM ROMs.
$c = $c.Replace('android:name=".MainActivity"', 'android:name=".MainActivity" android:importantForAutofill="noExcludeDescendants"')
[System.IO.File]::WriteAllText($mf, $c, (New-Object System.Text.UTF8Encoding($false)))

Write-Output '=== patch MainActivity (disable Android autofill) ==='
$ma = "$proj\android\app\src\main\kotlin\dev\astr\astrbot_manager\MainActivity.kt"
$kt = @"
package dev.astr.astrbot_manager

import android.os.Build
import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "astr/frame_rate"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block the Android autofill framework app-wide so the system never
        // draws its yellow autofill highlight over our text fields.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.importantForAutofill =
                View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setFrameRate") {
                    val fps = (call.arguments as? Number)?.toInt() ?: 0
                    runOnUiThread { applyFrameRate(fps) }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    // fps: 30 / 60 / 120; fps <= 0 means unlimited (system default).
    // preferredRefreshRate is deprecated since API 30 but remains the only
    // public app-window API and is honored by MIUI to unlock high refresh rate.
    private fun applyFrameRate(fps: Int) {
        try {
            @Suppress("DEPRECATION")
            window.attributes = window.attributes.apply {
                preferredRefreshRate = fps.toFloat()
            }
        } catch (_: Exception) {
            // ignore: some devices may not support the requested frame rate
        }
    }
}
"@
[System.IO.File]::WriteAllText($ma, $kt, (New-Object System.Text.UTF8Encoding($false)))

Write-Output '=== patch gradle wrapper (Tencent mirror) ==='
$gp = "$proj\android\gradle\wrapper\gradle-wrapper.properties"
$c = [System.IO.File]::ReadAllText($gp)
$c = $c.Replace('https\://services.gradle.org/distributions/gradle-8.10.2-all.zip', 'https\://mirrors.cloud.tencent.com/gradle/gradle-8.10.2-all.zip')
[System.IO.File]::WriteAllText($gp, $c, (New-Object System.Text.UTF8Encoding($false)))

Write-Output '=== patch maven repos (dl.google.com direct) ==='
foreach ($gf in @("$proj\android\settings.gradle.kts", "$proj\android\build.gradle.kts")) {
  $c = [System.IO.File]::ReadAllText($gf)
  $c = $c.Replace('google()', 'maven { url = uri("https://dl.google.com/dl/android/maven2/") }')
  [System.IO.File]::WriteAllText($gf, $c, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Output '=== launcher icon ==='
# Use user-provided icon (png in workspace root, not astrbot/napcat)
$userIcon = Get-ChildItem $ws -Filter "*.png" | Where-Object { $_.Name -ne 'astrbot.png' -and $_.Name -ne 'napcat.png' } | Select-Object -First 1
if ($userIcon -ne $null) {
  Add-Type -AssemblyName System.Drawing
  $img = [System.Drawing.Image]::FromFile($userIcon.FullName)
  $legacy = @{ "mipmap-mdpi" = 48; "mipmap-hdpi" = 72; "mipmap-xhdpi" = 96; "mipmap-xxhdpi" = 144; "mipmap-xxxhdpi" = 192 }
  foreach ($k in $legacy.Keys) {
    $size = $legacy[$k]
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.DrawImage($img, 0, 0, $size, $size)
    $out = "$proj\android\app\src\main\res\$k\ic_launcher.png"
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
  }
  $fg = @{ "mipmap-mdpi" = 108; "mipmap-hdpi" = 162; "mipmap-xhdpi" = 216; "mipmap-xxhdpi" = 324; "mipmap-xxxhdpi" = 432 }
  foreach ($k in $fg.Keys) {
    $size = $fg[$k]
    $inner = [int]($size * 0.62)
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $off = [int](($size - $inner) / 2)
    $g.DrawImage($img, $off, $off, $inner, $inner)
    $out = "$proj\android\app\src\main\res\$k\ic_launcher_foreground.png"
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
  }
  $img.Dispose()
  # Adaptive icon background: white
  $bgXml = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n<resources>`r`n    <color name=`"ic_launcher_background`">#FFFFFF</color>`r`n</resources>`r`n"
  [System.IO.File]::WriteAllText("$proj\android\app\src\main\res\values\ic_launcher_background.xml", $bgXml, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output "icon from: $($userIcon.Name)"
} else {
  & "$ws\tools\make-icon.ps1" -ProjectDir $proj
  if ($LASTEXITCODE -ne 0) { throw 'icon generation failed' }
}

Write-Output '=== pub get ==='
Push-Location $proj
Run-Flutter @('pub', 'get')

Write-Output '=== flutter analyze ==='
& $dart --packages="$pkgs" $snap analyze --no-fatal-infos
Write-Output "analyze exit: $LASTEXITCODE"

Write-Output '=== build apk release ==='
Run-Flutter @('build', 'apk', '--release')
Pop-Location

Write-Output '=== copy artifact ==='
$apk = "$proj\build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) { throw "apk not found: $apk" }
Copy-Item $apk "$ws\astrbot-assistant.apk" -Force
Write-Output "BUILD_OK $apk"
