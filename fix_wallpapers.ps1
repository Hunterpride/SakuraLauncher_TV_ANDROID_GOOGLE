$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing

$project = "C:\Users\ARNAV\Documents\Default Project"
$out = Join-Path $project "SakuraOS\src\res\drawable-nodpi"
$prev = Join-Path $env:TEMP "fixprev"
New-Item -ItemType Directory -Force -Path $prev | Out-Null
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
$curl = "C:\Windows\System32\curl.exe"

function Scale-Preview([string]$src, [string]$name) {
    # read bytes first so the source file is never locked while we overwrite it
    $bytes = [System.IO.File]::ReadAllBytes($src)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $img = [System.Drawing.Image]::FromStream($ms)
    try {
        $s = [Math]::Min(768.0 / $img.Width, 432.0 / $img.Height)
        $nw = [Math]::Max(1, [int]($img.Width * $s)); $nh = [Math]::Max(1, [int]($img.Height * $s))
        $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.InterpolationMode = 'HighQualityBicubic'
        $gfx.DrawImage($img, 0, 0, $nw, $nh)
        $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 80L)
        $bmp.Save((Join-Path $prev $name), $enc, $ep)
        $gfx.Dispose(); $bmp.Dispose()
    } finally { $img.Dispose(); $ms.Dispose() }
}

function Cover-Crop([System.Drawing.Image]$img, [float]$scaleW, [float]$scaleH, [float]$biasX, [float]$biasY, [string]$dest, [int]$tw, [int]$th) {
    # scale to cover target, then crop with bias: bias in 0..1 of the excess
    $sc = [Math]::Max($scaleW, $scaleH)
    $nw = [int]($img.Width * $sc); $nh = [int]($img.Height * $sc)
    $bmp = New-Object System.Drawing.Bitmap($tw, $th)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.InterpolationMode = 'HighQualityBicubic'
    $maxX = $nw - $tw; $maxY = $nh - $th
    $dx = $maxX * $biasX; $dy = $maxY * $biasY
    $sx = [float]((-$dx) / $sc); $sy = [float]((-$dy) / $sc)
    $srcRect = New-Object System.Drawing.RectangleF($sx, $sy, [float]($tw / $sc), [float]($th / $sc))
    $dstRect = New-Object System.Drawing.RectangleF(0, 0, $tw, $th)
    $gfx.DrawImage($img, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $gfx.Dispose()
    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 82L)
    $bmp.Save($dest, $enc, $ep)
    $bmp.Dispose()
}

# ---- pin1 Zenitsu: download full-res, produce both rotations as previews
$p1 = Join-Path $env:TEMP "pin1.raw.jpg"
& $curl -s -o $p1 -L -A $UA -H "Referer: https://www.pinterest.com/" --max-time 90 "https://i.pinimg.com/originals/34/89/01/348901472d0f85ddc47a3076c6ad5d4c.jpg"
Write-Host ("pin1 raw: " + (Get-Item $p1).Length + " bytes")
$imCW = [System.Drawing.Image]::FromFile($p1); $imCW.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone)
$imCCW = [System.Drawing.Image]::FromFile($p1); $imCCW.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone)
$imCW.Save((Join-Path $prev "p1_cw.jpg"), [System.Drawing.Imaging.ImageFormat]::Jpeg)
$imCCW.Save((Join-Path $prev "p1_ccw.jpg"), [System.Drawing.Imaging.ImageFormat]::Jpeg)
$imCW.Dispose(); $imCCW.Dispose()
# previews of both (as full frame, scaled)
Scale-Preview (Join-Path $prev "p1_cw.jpg") "p1_cw.jpg"
Scale-Preview (Join-Path $prev "p1_ccw.jpg") "p1_ccw.jpg"
Write-Host "pin1 rotations previewed"

# ---- pin2 Kirito: top-biased cover-crop variants
$p2 = Join-Path $env:TEMP "pin2.raw.jpg"
& $curl -s -o $p2 -L -A $UA -H "Referer: https://www.pinterest.com/" --max-time 90 "https://i.pinimg.com/originals/ee/bf/e1/eebfe11f1f42d2ac643f52ba29916ac6.jpg"
Write-Host ("pin2 raw: " + (Get-Item $p2).Length + " bytes")
$img2 = [System.Drawing.Image]::FromFile($p2)
# square 3000x3000 -> cover 1920x1080, biasing toward top (face + KIRITO letters)
foreach ($bias in @("0.08", "0.20", "0.34")) {
    $dest = Join-Path $prev ("p2_b" + $bias.Replace('.', '_') + ".jpg")
    Cover-Crop $img2 ([double]1920 / 3000) ([double]1080 / 3000) 0 ([float]$bias) $dest 1920 1080
}
$img2.Dispose()
Get-ChildItem $prev -Filter "p2_b*.jpg" | ForEach-Object { Scale-Preview $_.FullName $_.Name }
Write-Host "pin2 top-bias variants previewed"

# ---- city: crop letterbox bars then cover-crop favoring the girl
$city = Join-Path $out "wp_a_city.jpg"
$img3 = [System.Drawing.Image]::FromFile($city)
if ($img3.Height -gt 1000) {
    $img3.Dispose()
    Write-Host "city already cropped; skip"
} else {
# saved 1920x750 with bars: content approx y 58..692
$srcRect = New-Object System.Drawing.RectangleF(0, 58, 1920, 640)
$dstRect = New-Object System.Drawing.RectangleF(0, 0, 1920, 1080)
# scale content (1920x640) to cover 1920x1080 -> scale 1.6875, then width-crop keeping girl (x~32%)
$sc = 1080 / 640
$sw = [int](1920 * $sc)
$full = New-Object System.Drawing.Bitmap($sw, 1080)
$g = [System.Drawing.Graphics]::FromImage($full)
$g.InterpolationMode = 'HighQualityBicubic'
$g.DrawImage($img3, (New-Object System.Drawing.RectangleF(0, 0, $sw, 1080)), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$img3.Dispose()
$girlX = [int](0.32 * $sw)
$cropX = $girlX - 660
if ($cropX -lt 0) { $cropX = 0 }
if ($cropX + 1920 -gt $sw) { $cropX = $sw - 1920 }
$fin = New-Object System.Drawing.Bitmap(1920, 1080)
$g2 = [System.Drawing.Graphics]::FromImage($fin)
$g2.InterpolationMode = 'HighQualityBicubic'
$g2.DrawImage($full, (New-Object System.Drawing.Rectangle(0, 0, 1920, 1080)), (New-Object System.Drawing.Rectangle($cropX, 0, 1920, 1080)), [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 82L)
$fin.Save((Join-Path $out "wp_a_city.jpg"), $enc, $ep)
$fin.Dispose(); $full.Dispose()
Scale-Preview (Join-Path $out "wp_a_city.jpg") "city.jpg"
Write-Host "city re-cropped in place"
}
Write-Host ("--- previews in " + $prev)
Get-ChildItem $prev | ForEach-Object { Write-Host ("   " + $_.Name + "  " + $_.Length) }
