# Generate launcher icons (gradient robot avatar). Pure ASCII for PS 5.1 safety.
param([Parameter(Mandatory = $true)][string]$ProjectDir)

Add-Type -AssemblyName System.Drawing

function New-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

function New-Icon([int]$size, [string]$outPath) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)

  $s = [float]$size
  # gradient rounded background
  $bgRect = New-Object System.Drawing.RectangleF(0, 0, $s, $s)
  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bgRect,
    [System.Drawing.Color]::FromArgb(255, 139, 124, 255),
    [System.Drawing.Color]::FromArgb(255, 79, 216, 235),
    45)
  $bgPath = New-RoundedRectPath ($s * 0.04) ($s * 0.04) ($s * 0.92) ($s * 0.92) ($s * 0.20)
  $g.FillPath($bgBrush, $bgPath)

  $white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
  $dark  = [System.Drawing.Color]::FromArgb(255, 53, 42, 120)

  # antenna
  $antPen = New-Object System.Drawing.Pen($white, [Math]::Max(1, $s * 0.045))
  $antPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $antPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawLine($antPen, $s * 0.5, $s * 0.30, $s * 0.5, $s * 0.17)
  $antBall = New-Object System.Drawing.SolidBrush($white)
  $g.FillEllipse($antBall, $s * 0.44, $s * 0.08, $s * 0.12, $s * 0.12)

  # head
  $headPath = New-RoundedRectPath ($s * 0.30) ($s * 0.28) ($s * 0.40) ($s * 0.34) ($s * 0.09)
  $headBrush = New-Object System.Drawing.SolidBrush($white)
  $g.FillPath($headBrush, $headPath)

  # eyes
  $eyeBrush = New-Object System.Drawing.SolidBrush($dark)
  $g.FillEllipse($eyeBrush, $s * 0.36, $s * 0.405, $s * 0.085, $s * 0.085)
  $g.FillEllipse($eyeBrush, $s * 0.555, $s * 0.405, $s * 0.085, $s * 0.085)

  # smile
  $smilePen = New-Object System.Drawing.Pen($dark, [Math]::Max(1, $s * 0.022))
  $smilePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $smilePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawArc($smilePen, $s * 0.40, $s * 0.46, $s * 0.20, $s * 0.11, 15, 150)

  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $smilePen.Dispose(); $eyeBrush.Dispose(); $headBrush.Dispose(); $antBall.Dispose(); $antPen.Dispose()
  $bgBrush.Dispose(); $bgPath.Dispose(); $g.Dispose(); $bmp.Dispose()
}

$resDir = Join-Path $ProjectDir "android\app\src\main\res"
$tmp = Join-Path $env:TEMP "dsh-tools\icon"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# legacy launcher icons
$legacy = @{ "mipmap-mdpi" = 48; "mipmap-hdpi" = 72; "mipmap-xhdpi" = 96; "mipmap-xxhdpi" = 144; "mipmap-xxxhdpi" = 192 }
foreach ($k in $legacy.Keys) {
  $dir = Join-Path $resDir $k
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  New-Icon $legacy[$k] (Join-Path $dir "ic_launcher.png")
}

# adaptive icon foreground (content inside safe zone)
$fg = @{ "mipmap-mdpi" = 108; "mipmap-hdpi" = 162; "mipmap-xhdpi" = 216; "mipmap-xxhdpi" = 324; "mipmap-xxxhdpi" = 432 }
foreach ($k in $fg.Keys) {
  $dir = Join-Path $resDir $k
  $size = $fg[$k]
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)
  $s = [float]$size
  $scale = 0.52
  $margin = ($s - $s * $scale) / 2
  $white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
  $dark  = [System.Drawing.Color]::FromArgb(255, 53, 42, 120)
  $cx = $s / 2

  # antenna
  $antPen = New-Object System.Drawing.Pen($white, [Math]::Max(1, $s * 0.05))
  $antPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $antPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawLine($antPen, $cx, $margin + $s * $scale * 0.50, $cx, $margin + $s * $scale * 0.16)
  $antBall = New-Object System.Drawing.SolidBrush($white)
  $ball = $s * $scale * 0.13
  $g.FillEllipse($antBall, $cx - $ball / 2, $margin + $s * $scale * 0.03, $ball, $ball)

  # head
  $headW = $s * $scale * 0.46
  $headH = $s * $scale * 0.38
  $headPath = New-RoundedRectPath ($cx - $headW / 2) ($margin + $s * $scale * 0.42) $headW $headH ($s * $scale * 0.10)
  $headBrush = New-Object System.Drawing.SolidBrush($white)
  $g.FillPath($headBrush, $headPath)

  # eyes
  $eyeBrush = New-Object System.Drawing.SolidBrush($dark)
  $eye = $s * $scale * 0.10
  $g.FillEllipse($eyeBrush, $cx - $s * $scale * 0.17, $margin + $s * $scale * 0.545, $eye, $eye)
  $g.FillEllipse($eyeBrush, $cx + $s * $scale * 0.07, $margin + $s * $scale * 0.545, $eye, $eye)

  # smile
  $smilePen = New-Object System.Drawing.Pen($dark, [Math]::Max(1, $s * 0.024))
  $smilePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $smilePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawArc($smilePen, $cx - $s * $scale * 0.12, $margin + $s * $scale * 0.60, $s * $scale * 0.24, $s * $scale * 0.14, 15, 150)

  $bmp.Save((Join-Path $dir "ic_launcher_foreground.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $smilePen.Dispose(); $eyeBrush.Dispose(); $headBrush.Dispose(); $headPath.Dispose(); $antBall.Dispose(); $antPen.Dispose()
  $g.Dispose(); $bmp.Dispose()
}

# adaptive icon background color
$valuesDir = Join-Path $resDir "values"
$bgXml = @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#6C5CE7</color>
</resources>
"@
Set-Content -Path (Join-Path $valuesDir "ic_launcher_background.xml") -Value $bgXml -Encoding UTF8

Write-Output 'ICON_OK'
