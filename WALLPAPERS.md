# SakuraOS wallpapers — where every image came from

Wallpapers ship inside the launcher APK: static art under `src/res/drawable-nodpi/`,
real video loops under `src/res/raw/`. No network calls, no download services, no ads.
Personal-use, one TV.

## Anime art (from links you picked)

| File | Name | Source |
|------|------|--------|
| `wp_anime_zenitsu.jpg` | Zenitsu | Your Pinterest pin `731060952053738738` (artist signature: DimensionAiArt). Rotated to upright 1920x1080. |
| `wp_anime_kirito.jpg` | Kirito | Your Pinterest pin `1142647736735637602` (@Pv_Kirito). 3000x3000 square cover-cropped to 1920x1080 with a top bias so the face stays framed. |
| `wp_anime_ichigo.jpg` | Ichigo Storm | Your Pinterest pin `426082814768969417`. 2048x1148. |
| `wp_anime_samurai.jpg` | Samurai Dusk | Your Pinterest pin `978970037772913444`. 1280x720. |
| `wp_anime_moon.jpg` | Moonblade | Your Pinterest pin `1038431626636420695` (moewalls source; tiny bottom-corner mark). 3840x2160. |
| `wp_anime_saber.jpg` | Saber's Blade | Pin `1136807130965397576` (owner-picked link). 1200x675. Static fallback of the video below. |
| `wp_anime_gojo.jpg` | Hollow Purple | Pin `914864111798661642` (owner-picked link). 1913x1084. Static fallback of the video below. |
| `wp_anime_sao.jpg` | Aincrad Meadow | Pin `586945763982755001` (owner-picked link). 1200x675. Static fallback of the video below. |
| `wp_pixel_neon.jpg` | Pixel Tokyo | Pin `806003664582885854` (owner-picked link). 736x414. Static fallback of the video below. |

## Video walls — four pins are actual MP4 loops (the real live wallpapers)

The four pins above contain **actual video on Pinterest's CDN**, so the launcher
bundles those videos and plays them behind the home UI:

| Raw video | Name | Length | Source |
|-----------|------|--------|--------|
| `raw/vid_saber.mp4` (1.3 MB) | Saber's Blade | ~20 s loop | the video attached to pin `1136807130965397576` |
| `raw/vid_gojo.mp4` (0.8 MB) | Hollow Purple | ~8 s loop | the video attached to pin `914864111798661642` |
| `raw/vid_sao.mp4` (3.8 MB) | Aincrad Meadow | ~35 s loop | the video attached to pin `586945763982755001` |
| `raw/vid_pixel.mp4` (2.1 MB) | Pixel Tokyo | ~30 s loop | the video attached to pin `806003664582885854` |

How it works (honest description):
- `VideoLayer` hosts a `TextureView` + muted, seamless-looping `MediaPlayer`
  under the launcher's canvas.
- The canvas lifts its wallpaper paint away **only once the video is
  presenting frames** (verified by presented-buffer counting); before that and
  on any failure, the static art + ambience engine keeps rendering — an
  automatic fallback, never a black screen.
- Clock, home rows, petals and the corner watermark draw **on top** of the video.
- If the video can't decode on some TV, nothing breaks: you get the art version.

These four show "(video)" in Settings > Wallpaper; verified live on the target
TV with a 47.7 % frame-to-frame pixel diff two seconds apart.

## Anime scenery art (open anime art boards, safe-rated only)

| File | Name | Source |
|------|------|--------|
| `wp_a_sakura.jpg` | Sakura Over Crimson | konachan.net post 143486 (tags: cherry_blossoms, scenic) |
| `wp_a_torii.jpg` | Shrine Miko | konachan.net post 133978 (miko / torii) |
| `wp_a_city.jpg` | City Stargazer | konachan.net post 84686; re-cropped to remove the source's letterbox bars |

Downloaded at safe rating only with watermark/ad-look tag blacklist; every image manually
vetted visually before it shipped. Two candidates were rejected and deleted on sight.

## Photos (originals from Pexels, kept)

| File | Name |
|------|------|
| `wp_bloom.jpg` | Sakura Bloom |
| `wp_neon.jpg` | Neon Dusk |
| `wp_sea.jpg` | Moonlit Tide |
| `wp_dream.jpg` | Dream Sky |

## Procedural - true live (the entire scene is runtime-drawn AND animated)

| Style | Scene | What animates |
|-------|-------|---------------|
| `midnight` (Midnight Sakura) | indigo night, moon, layered mountains | twinkling stars, clouds drifting across the moon, breathing moon halo, mist on the mountain line, comet every ~21s |
| `ink` (Sumi-e Ink) | hinomaru sun + ink mountains | three mist bands breathing over the ridgelines, sun slow pulse |
| `void` (Void Black) | pure black + far stars | drifting twinkling starfield, comet every ~14s |

## Custom

`wp_custom` — your own JPEG via Settings > "Custom picture (USB)" (stored in app-private
storage as `sakura_custom.jpg`).

## Removed

The five Wikimedia-Commons photo walls (yozakura / torii / fuji / shibuya / hanami) were
removed at your request — the anime art replaced them.

## Renaming notes / mapping

Wallpaper styles array order (Settings > Wallpaper cycles through it):
Zenitsu, Kirito, Samurai Dusk, Moonblade, Ichigo Storm, Sakura Over Crimson, Shrine Miko,
City Stargazer, then the 4 photos, then Midnight, Sumi-e, Void.

Theme presets pair an accent color + wallpaper:
sakura_night, zenitsu, kirito, ichigo, samurai, moon, ember (Ember Sakura -> wp_a_sakura),
shrine (Shrine Miko), city (City Stargazer), neon, tide, dream, sumi, void.

## Ambience effects (real-time render, not baked in)

| Style | Effect |
|-------|--------|
| Zenitsu | lightning strikes (~9s period) with glow + room flash |
| Ichigo Storm | cold two-depth rain |
| Samurai Dusk | rising embers |
| Sakura Over Crimson | rising embers |
| Shrine Miko | green-gold fireflies |
| Kirito | shooting stars + twinkle dust (bluish) |
| City Stargazer | shooting stars + twinkle dust |
| Moonblade | shooting stars + twinkle dust (cold white) |
| Saber's Blade | blade-light breathing + blue motes (periodic surge) |
| Hollow Purple | orb pulse/surge + violet sparks |
| Aincrad Meadow | golden pollen drifting |
| Pixel Tokyo | soft drizzle + neon flicker + wet-road glints |

On top of the Ken-Burns drift that animates every art/photo style. The three
runtime styles above are **fully live** - the whole scene animates, not just
an effect layer on top of art.

## Tooling (if you ever want to redo this)

* `fetch_pins.ps1` — pulls pins via the public pidgets widget API and downloads the full
  resolution file from `i.pinimg.com/originals/` (must go through `curl.exe`; the
  PowerShell web request gets 403).
* `fetch_anime.ps1` — konachan.net / yande.re search with rating + tag blacklist.
* `fix_wallpapers.ps1` + `finalize_wallpapers.ps1` — rotations / cover crops / renames.
