$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing

$project = "C:\Users\ARNAV\Documents\Default Project"
$out = Join-Path $project "SakuraOS\src\res\drawable-nodpi"
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

# Anime-scenery wallpapers from the safe anime wallpaper boards.
# konachan.net = safe-only Konachan mirror; yande.re filtered to rating:safe.
$themes = @(
    @{ name = "wp_a_sakura";  tags = @("cherry_blossoms wallpaper", "cherry_blossoms order:score", "sakura scenery") },
    @{ name = "wp_a_torii";   tags = @("torii wallpaper", "torii order:score") },
    @{ name = "wp_a_fuji";    tags = @("fuji wallpaper", "fuji scenic", "fuji scenery", "mount_fuji scenery") },
    @{ name = "wp_a_city";    tags = @("city night scenery wallpaper", "night city order:score", "cityscape night") },
    @{ name = "wp_a_sky";     tags = @("night_sky scenery wallpaper", "milky_way scenery", "night_sky scenery", "night_sky starry") },
    @{ name = "wp_a_rain";    tags = @("rain scenery wallpaper", "rain night scenery", "rain cityscape", "rain street") }
)

function Save-Resized([string]$srcPath, [string]$dest) {
    $img = [System.Drawing.Image]::FromFile($srcPath)
    try {
        $scale = [Math]::Min(1.0, 1920.0 / [Math]::Max($img.Width, $img.Height))
        $nw = [int]($img.Width * $scale)
        $nh = [int]($img.Height * $scale)
        $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.InterpolationMode = 'HighQualityBicubic'
        $gfx.DrawImage($img, 0, 0, $nw, $nh)
        $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 82L)
        $bmp.Save($dest, $enc, $ep)
        $gfx.Dispose(); $bmp.Dispose()
    } finally { $img.Dispose() }
}

function Get-BoardPosts([string]$board, [string]$tags) {
    if ($board -eq "konachan") {
        $api = "https://konachan.net/post.json?limit=16&tags=" + [uri]::EscapeDataString($tags + " rating:s")
        return Invoke-RestMethod -Uri $api -UserAgent $UA -TimeoutSec 30
    }
    $api = "https://yande.re/post.json?limit=16&tags=" + [uri]::EscapeDataString($tags + " rating:s")
    return Invoke-RestMethod -Uri $api -UserAgent $UA -TimeoutSec 30
}

foreach ($t in $themes) {
    $name = $t.name
    $dest = Join-Path $out ($name + ".jpg")
    if (Test-Path $dest) { Write-Host ("HAVE " + $name); continue }
    Write-Host ("== " + $name)
    $got = $false
    foreach ($board in @("konachan", "yande")) {
        if ($got) { break }
        foreach ($tags in $t.tags) {
            if ($got) { break }
            Write-Host ("   [" + $board + "] " + $tags)
            Start-Sleep -Seconds 2
            try { $r = Get-BoardPosts $board $tags }
            catch { Write-Host ("      QUERYFAIL " + $_.Exception.Message); continue }
            if (-not $r) { Write-Host "      NORESULT"; continue }
            $cands = @($r | Where-Object {
                    $_.rating -eq 's' -and $_.width -ge 1500 -and $_.height -ge 900 -and
                    $_.file_url -match '\.(jpe?g|png)(\?|$)' -and
                    $_.tags -notmatch 'watermark|tagme|cleavage|nopan|underwear|see_through|bikini|cameltoe|pantyhose|striptease'
                } | Sort-Object { $_.score } -Descending)
            Write-Host ("      candidates: " + $cands.Count)
            foreach ($p in $cands) {
                if ($got) { break }
                $url = $p.jpeg_url
                if (-not $url) { $url = $p.file_url }
                $tmp = Join-Path $env:TEMP ($name + ".raw.jpg")
                try {
                    Invoke-WebRequest -Uri $url -OutFile $tmp -UserAgent $UA -TimeoutSec 90
                    $rawSz = (Get-Item $tmp).Length
                    if ($rawSz -gt 40MB) { throw ("too big " + $rawSz) }
                    Save-Resized $tmp $dest
                    Remove-Item $tmp -ErrorAction SilentlyContinue
                    $sz = (Get-Item $dest).Length
                    Write-Host ("      SAVED $name.jpg  $sz bytes  <- $board post " + $p.id + " score " + $p.score + " " + $p.width + "x" + $p.height)
                    Write-Host ("      CREDIT board=$board id=" + $p.id + " score=" + $p.score + " tags=" + $p.tags.Substring(0, [Math]::Min(110, $p.tags.Length)))
                    $got = $true
                } catch {
                    Write-Host ("      SKIP post " + $p.id + ": " + $_.Exception.Message)
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
    if (-not $got) { Write-Host ("   GAVEUP " + $name) }
}
Write-Host "--- directory:"
Get-ChildItem $out | ForEach-Object { Write-Host ("   " + $_.Name + "  " + $_.Length) }
