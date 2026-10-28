# SakuraOS - a clean, anime-styled home OS for Android TV

A home-screen replacement for **Android TV / Google TV** (also runs on Fire TV).
No ads. No sponsored rows. No recommendations. No analytics. **Zero network
permissions, zero third-party libraries** - the entire OS shell is hand-written
non-native Java 8 with a GPU-light custom render loop.

![Home - Kirito](screenshots/home-kirito.png)

## Highlights

- Boots as your TV's home screen - installs in front of the stock Google TV ad feed
- **4 real video wallpapers** - Saber's Blade, Hollow Purple, Aincrad Meadow and
  Pixel Tokyo ship as bundled, muted, seamlessly looping MP4s played behind the
  UI (clock, rows and petals render on top). If a video ever can't play, the
  launcher silently shows the static art - never a black screen
- 12 anime art wallpapers + 4 photo wallpapers + 3 **true-live** runtime scenes
  - the art walls are static images; their **ambience layer on top is real-time**
    (slow Ken-Burns drift + a signature effect, rendered every frame)
  - the runtime scenes are fully animated by code
- Real-time ambience engine (pure math, no allocation, 30 fps idle cap):
  - Zenitsu: lightning strikes every ~9s (glow pass + room flash)
  - Ichigo: cold two-depth rain
  - Samurai Dusk / Sakura Over Crimson: rising embers
  - Shrine Miko: green-gold fireflies
  - Kirito / Moonblade / City Stargazer: shooting stars + twinkle dust
  - Saber's Blade: the blade-light breathes and surges, blue motes rising
  - Hollow Purple: the cursed-energy orb pulses + violet sparks
  - Aincrad Meadow: golden pollen drifting in the warm breeze
  - Pixel Tokyo: soft drizzle, neon-sign flicker, wet-road glints
- Sakura petals + leaves + fireflies particle layer (toggleable)
- Adaptive readability scrims: wallpaper stays bright, text shadows keep UI legible
- Clicky UI sounds (pure SoundPool), minimalist monochrome UI
- Settings: 5 accent palettes, 19 wallpaper styles, 18 one-tap themes,
  petals on/off, 12/24h clock, games row, custom USB photo, app pin/hide
- Long-press OK on any card: open / pin / hide / app info / uninstall
- Auto-starts on boot, with a **boot veil**: the firmware's dead black churn screen
  gets replaced by a branded SakuraOS warm-up slate until home wins the race

## Screenshots

| | |
|---|---|
| ![Settings - Moonblade](screenshots/settings-moonblade.png) | ![Settings - Samurai](screenshots/settings-samurai.png) |
| ![Settings - Ichigo](screenshots/settings-ichigo.png) | ![Settings - Zenitsu](screenshots/settings-zenitsu.png) |
| ![Settings - Hollow Purple](screenshots/settings-gojo.png) | ![Settings - Aincrad Meadow](screenshots/settings-sao.png) |

## Wallpaper styles (cycled in Settings)

Zenitsu, Kirito, Samurai Dusk, Moonblade, Ichigo Storm, Sakura Over Crimson,
Shrine Miko, City Stargazer, **Saber's Blade (video)**, **Hollow Purple (video)**,
**Aincrad Meadow (video)**, **Pixel Tokyo (video)**, Sakura Bloom, Neon Dusk,
Moonlit Tide, Dream Sky, Midnight Sakura, Sumi-e Ink, Void Black, Custom (USB photo).

The four video walls play the real animated loops from the owner-picked
Pinterest pins; everything about where they came from is in
[WALLPAPERS.md](WALLPAPERS.md).

Image sources are documented in [WALLPAPERS.md](WALLPAPERS.md), and every
creator credit lives in **[CREDITS.md](CREDITS.md)** — including the artists
whose names were legible and an explicit "**attribution wanted / takedown on
request**" policy for the rest. All bundled art is personal-use, sourced from
links the owner picked out and safe-rated anime art boards; nothing is
downloaded at runtime. The art is **static images** — but the four pinned
walls ship as **real looping videos**, and every other wall's motion is the
launcher's own real-time ambience layer.

## Remote controls

| Key | Action |
|-----|--------|
| D-pad | navigate rows / cards |
| OK | open item |
| OK on Settings row / arrows | change value |
| HOLD OK | context menu: open / pin / hide / uninstall |
| MENU button | app options |
| BACK | close menu / page around |

## Install (ADB)

```powershell
adb connect <TV-IP>:5555
adb install -r SakuraOS\build\SakuraOS.apk
adb shell am start -n tv.sakura.launcher/.HomeActivity
```

Then: system Settings > Apps > Default home > pick SakuraOS (the first-run
welcome card walks you through it). To put Google TV back:
`adb shell pm set-home-activity com.google.android.tvlauncher/.Home`

## Build from source

No Gradle, no dependencies - just the Android build tools:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File SakuraOS\setup-toolchain.ps1   # one-time (JDK17 + platform + build-tools)
powershell -NoProfile -ExecutionPolicy Bypass -File SakuraOS\build.ps1             # -> SakuraOS\build\SakuraOS.apk
```

The pipeline is scripted `aapt2 -> javac -> d8 -> zipalign -> apksigner`
(~13 MB APK with the four bundled video loops. No icons beyond two pre-scaled
ones, no extra libraries).
`signing.jks` is auto-generated on first build and intentionally **not** kept
in git. Keep yours somewhere safe if you want to keep updating the same install
without uninstalling.

## Repo layout

```
SakuraOS/
  src/            Java + resources + manifest (the entire OS shell)
  build.ps1       build pipeline
  setup-toolchain.ps1   fetches JDK + Android tools once
  ship.ps1        install + launch helper over ADB
  fetch_pins.ps1  pulls wallpaper art from Pinterest pin links you give it
  fetch_anime.ps1 pulls art from open anime boards (safe-rated, tag blacklist)
  fix_wallpapers.ps1 + finalize_wallpapers.ps1   crop/rotate/rename pass
  screenshots/    captured on a real TV
  WALLPAPERS.md   every image, where it came from
  CREDITS.md      artist/source credits + takedown policy
  SHIP.md         internal ship procedure + firmware notes
```

## License

Code: **MIT** - see [LICENSE](LICENSE).
The bundled wallpapers and the video loops are **not** covered by it: they are
anime fan art and animations by other creators, bundled for personal use.
Who made what lives in [CREDITS.md](CREDITS.md) - attribution wanted,
takedown on issue.
