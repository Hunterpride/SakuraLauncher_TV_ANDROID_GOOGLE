$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing

$out = "C:\Users\ARNAV\Documents\Default Project\SakuraOS\src\res\drawable-nodpi"

function Save-Jpeg([System.Drawing.Image]$img, [string]$dest) {
    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 85L)
    $img.Save($dest, $enc, $ep)
    $img.Dispose()
    Write-Host ("  -> " + $dest + "  " + (Get-Item $dest).Length + " bytes")
}

function Cover-Crop([System.Drawing.Image]$img, [double]$scaleW, [double]$scaleH, [double]$biasY, [string]$dest) {
    $sc = [Math]::Max($scaleW, $scaleH)
    $tw = 1920; $th = 1080
    $nw = [int]($img.Width * $sc); $nh = [int]($img.Height * $sc)
    $maxY = [Math]::Max(0, $nh - $th)
    $dy = $maxY * $biasY
    $bmp = New-Object System.Drawing.Bitmap($tw, $th)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.InterpolationMode = 'HighQualityBicubic'
    $sx = [float]((0) / $sc); $sy = [float](($dy) / $sc)
    $srcRect = New-Object System.Drawing.RectangleF($sx, $sy, [float]($tw / $sc), [float]($th / $sc))
    $dstRect = New-Object System.Drawing.RectangleF(0, 0, $tw, $th)
    $gfx.DrawImage($img, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $gfx.Dispose()
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $bmp.Dispose()
    Write-Host ("  -> " + $dest + "  " + (Get-Item $dest).Length + " bytes")
}

# ---- pin1 Zenitsu: rotate 270 (CCW) to upright 1920x1080
$p1 = Join-Path $env:TEMP "pin1.raw.jpg"
$wpZen = Join-Path $out "wp_anime_zenitsu.jpg"
if (Test-Path $p1) {
    $im = [System.Drawing.Image]::FromFile($p1)
    $im.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone)
    Save-Jpeg $im $wpZen
} else { Write-Host "MISSING $p1" }

# ---- pin2 Kirito: 0.08 top-bias cover-crop -> 1920x1080
$p2 = Join-Path $env:TEMP "pin2.raw.jpg"
$wpKir = Join-Path $out "wp_anime_kirito.jpg"
if (Test-Path $p2) {
    $im = [System.Drawing.Image]::FromFile($p2)
    Cover-Crop $im ([double]1920 / 3000) ([double]1080 / 3000) 0.08 $wpKir
    $im.Dispose()
} else { Write-Host "MISSING $p2" }

# ---- pins 3/4/5 already correct 16:9 -> rename to semantic names
if (Test-Path (Join-Path $out "wp_pin3.jpg")) { Move-Item -Force (Join-Path $out "wp_pin3.jpg") (Join-Path $out "wp_anime_ichigo.jpg") ; Write-Host "renamed pin3 -> wp_anime_ichigo.jpg" }
if (Test-Path (Join-Path $out "wp_pin4.jpg")) { Move-Item -Force (Join-Path $out "wp_pin4.jpg") (Join-Path $out "wp_anime_samurai.jpg"); Write-Host "renamed pin4 -> wp_anime_samurai.jpg" }
if (Test-Path (Join-Path $out "wp_pin5.jpg")) { Move-Item -Force (Join-Path $out "wp_pin5.jpg") (Join-Path $out "wp_anime_moon.jpg")   ; Write-Host "renamed pin5 -> wp_anime_moon.jpg" }

# ---- delete the rejected commons photos
foreach ($n in @("wp_yozakura", "wp_torii", "wp_fuji", "wp_shibuya", "wp_hanami")) {
    Remove-Item (Join-Path $out ($n + ".jpg")) -Force -ErrorAction SilentlyContinue
}
Write-Host "deleted commons photos"

# ---- final directory
Write-Host "--- drawable-nodpi now:"
Get-ChildItem $out | ForEach-Object { Write-Host ("   " + $_.Name + "  " + $_.Length) }
