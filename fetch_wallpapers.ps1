$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing

$project = "C:\Users\ARNAV\Documents\Default Project"
$out = Join-Path $project "SakuraOS\src\res\drawable-nodpi"
$UA = "SakuraOS-ship/1.0 (personal device, wallbank@example.invalid)"

$themes = @(
    @{ name = "wp_yozakura";  term = "Cherry blossom festival at night" },
    @{ name = "wp_torii";     term = "torii night" },
    @{ name = "wp_fuji";      term = "Mount Fuji cherry blossom" },
    @{ name = "wp_shibuya";   term = "Shibuya night lights" },
    @{ name = "wp_hanami";    term = "sakura blossom close up" }
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
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 80L)
        $bmp.Save($dest, $enc, $ep)
        $gfx.Dispose(); $bmp.Dispose()
    } finally { $img.Dispose() }
}

foreach ($t in $themes) {
    $name = $t.name
    $term = $t.term
    $dest = Join-Path $out ($name + ".jpg")
    Write-Host ("== try " + $name + " -> " + $term)
    if (Test-Path $dest) { Write-Host ("   HAVE"); continue }
    Start-Sleep -Seconds 4
    $api = "https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search&gsrsearch=" + [uri]::EscapeDataString($term) + "&gsrnamespace=6&gsrlimit=10&prop=imageinfo&iiprop=url%7Csize&iiurlwidth=2200"
    try { $r = Invoke-RestMethod -Uri $api -UserAgent $UA -TimeoutSec 30 }
    catch { Write-Host ("   QUERYFAIL: " + $_.Exception.Message); continue }
    if (-not $r.query) { Write-Host "   NORESULT"; continue }
    $pages = @($r.query.pages.PSObject.Properties.Value | Where-Object {
            $_.imageinfo -and ($_.imageinfo[0].url -match '\.jpe?g(\?|$)') -and $_.imageinfo[0].width -ge 1300
        })
    Write-Host ("   candidates: " + $pages.Count)
    foreach ($p in ($pages | Select-Object -First 5)) { Write-Host ("     · " + $p.title + "  " + $p.imageinfo[0].width + "x" + $p.imageinfo[0].height) }
    $got = $false
    foreach ($p in $pages) {
        if ($got) { break }
        $u = $p.imageinfo[0].thumburl
        $tmp = Join-Path $env:TEMP ($name + ".raw.jpg")
        try {
            Invoke-WebRequest -Uri $u -OutFile $tmp -UserAgent $UA -TimeoutSec 60
            Save-Resized $tmp $dest
            Remove-Item $tmp -ErrorAction SilentlyContinue
            $sz = (Get-Item $dest).Length
            Write-Host ("   SAVED $name.jpg " + $sz + " bytes  <- " + $p.title)
            $got = $true
        } catch {
            Write-Host ("   SKIP: " + $_.Exception.Message)
            Start-Sleep -Seconds 3
        }
    }
    if (-not $got) { Write-Host ("   GAVEUP " + $name) }
}
Write-Host "--- directory:"
Get-ChildItem $out | ForEach-Object { Write-Host ("   " + $_.Name + "  " + $_.Length) }
