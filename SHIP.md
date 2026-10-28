# Shipping SakuraOS to the TV

**Uses `SakuraOS\ship.ps1` (automated)** — connects, installs, re-grants the
`SYSTEM_ALERT_WINDOW` op (reset by every reinstall), sets as default home,
disables the vendor setup wizard for the session, and opens the launcher. Run
it when the TV shows the debug prompt (tap OK on the remote).

**Full removal**: `SakuraOS\unship.ps1` — uninstalls the app and restores every
system bit SakuraOS touched (overlay op, animation scales, `launcherx`,
`katniss`, `adservices`, the setup wizard). Complete, reversible, no residue.

Manual equivalent:
```powershell
& SakuraOS\toolchain\android-sdk\platform-tools\adb.exe connect <TV-IP>:<PORT>
& SakuraOS\toolchain\android-sdk\platform-tools\adb.exe install -r SakuraOS\build\SakuraOS.apk
& SakuraOS\toolchain\android-sdk\platform-tools\adb.exe shell cmd package set-home-activity tv.sakura.launcher/.HomeActivity
```

Data safety: installing does not reset/wipe anything — it only adds an app and
(originally) changes the default home selection, fully reversible:
long-press HOME → pick another launcher, or uninstall SakuraOS (zero residue).

## Google TV home takeover (the `launcherx` problem)

On this TV's Google TV build, `com.google.android.apps.tv.launcherx` intercepts
the HOME key above the role/preferred-activity system (verified: role +
preferred + priority-999 filter all set, HOME still went to launcherx).
The reliable fix, done at ship time:

```powershell
$adb = "SakuraOS\toolchain\android-sdk\platform-tools\adb.exe"
& $adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
& $adb shell cmd package set-home-activity tv.sakura.launcher/.HomeActivity
& $adb reboot    # required: the system caches the old home until reboot
```

After reboot the HOME key resolves to SakuraOS (only remaining HOME app +
persistent role holder). Apps, HDMI inputs and data are untouched.

Revert (with the TV's debug connection still on):
```powershell
& $adb shell pm enable com.google.android.apps.tv.launcherx
```
Then press HOME once on the remote to get the stock Google launcher back.

Note: system/OTA updates can silently re-enable `launcherx`; repeat the disable
after a major TV firmware update if HOME reverts.

## Boot takeover details (verified on this firmware, Oct 27)

**How power-on works now:**

1. `BootReceiver` fires on `BOOT_COMPLETED` and starts `HomeActivity`. On a
   clean boot this wins outright and you get the sakura home by itself.
2. The vendor wizard `com.google.android.tungsten.setupwraith/.RecoveryActivity`
   can win the boot race instead (happened on ~half of observed boots): the
   screen goes black, `mCurrentFocus=null`, and HOME/BACK on the remote are dead.
3. The receiver therefore also runs a bounded salvage chain: first kick `+3s`
   after boot-complete, then a 5s burst x10, then 15s x3, then 45s hops
   (~20 kicks over ~6 min). Each check reads the firmware's own top-app note
   (`Settings.Global top_packageName` / `top_activity` — tungsten keeps it
   updated live for every app) and brings Home forward **only when the wizard
   or nothing is on top**. A real app (YouTube, Live TV `com.realtek.tv`,
   ...) is respected: the chain stands down and cancels its alarms. After the
   churn window it ends itself; nothing keeps running for the rest of the day.
4. Boot veil: for ~2.5 min after a boot signal, while the wizard (or nothing)
   is still on top, Home draws a branded SakuraOS slate (own window overlay,
   TYPE_APPLICATION_OVERLAY) OVER the wizard's black screen - the boot then
   looks like a warm-up screen instead of a dead box. Real apps are never
   covered; outside the boot window the veil cannot appear.
5. Direct-boot splash: HomeActivity is directBootAware, so its first pixels go
   up during the locked phase (before the normal BOOT_COMPLETED dispatch lag);
   the full home loads the instant storage unlock lands
   (ACTION_USER_UNLOCKED). The splash is the same sakura slate the veil uses,
   and no credential-encrypted data is touched before unlock.

**Black wizard screen / dead HOME button — the fix that sticks** (no reboot):

```powershell
& $adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
& $adb shell cmd package set-home-activity tv.sakura.launcher/.HomeActivity
```

Disabling the wizard while things are settled (a) held for the whole session
(disable survived 75+ minutes, simulated HOME presses verified) and (b) makes
the HOME key land straight on SakuraOS — the wizard's entry stops winning
resolution. The firmware can re-enable it at some boots; if the black screen
ever returns after a power-on, repeat these two lines. Instant exit when the
wizard is merely on screen (proven repeatedly):
```powershell
& $adb shell am force-stop com.google.android.tungsten.setupwraith
& $adb shell am start -n tv.sakura.launcher/.HomeActivity
```
Re-enable the wizard (fully reversible):
`& $adb shell pm enable com.google.android.tungsten.setupwraith`

**Android 14 background-start clearance** (one command, persistent, revert
below): the salvage start is a background activity launch, which Android 14
blocks unless the app has `SYSTEM_ALERT_WINDOW`:
```powershell
& $adb shell appops set tv.sakura.launcher SYSTEM_ALERT_WINDOW allow
# revert: & $adb shell appops set tv.sakura.launcher SYSTEM_ALERT_WINDOW default
```
(Declared in the manifest too — appops only sticks after that declaration.)

**The op silently RESETS on every reinstall** (verified Oct 27): `adb install -r`
flips `SYSTEM_ALERT_WINDOW` back to `default`, and every salvage start is then
swallowed by the background-start rule with no error anywhere — the only trace
is `appops get ... SYSTEM_ALERT_WINDOW` showing `default; rejectTime=+...ms ago`.
This caused an entire evening of "kicks fire but home never lands" while the
process stayed otherwise healthy. The ritual is therefore: **re-grant the op
after every single install** (ship.ps1 does this automatically now).

All of the above is undone by simply uninstalling SakuraOS. The wizard task
also churns task IDs during the first minutes after a boot and then settles;
force-stopping it once ends the churn for the whole session (observed).

## Findings from this firmware (tungsten / Google TV)

- The HOME KEY itself resolves through a vendor path that preferred launchers
  could not override in testing; even a `2147483647` priority HOME filter lost.
- Disabling `setupwraith` (the recovery/setup wizard) while things are settled
  DOES NOT survive a power cycle: the firmware re-enables it at every boot
  (verified Oct 27). So every power-on has a wizard-churn window; SakuraOS's
  burst alarm salvage now covers it (first kick +3s after the (LOCKED_)BOOT
  broadcast, then 5s bursts, 15s, then 45s cadence, ~20 kicks total, ends
  itself) and the boot veil paints a SakuraOS slate over the wizard's black
  screen during the churn. During the churn the HOME key can still open the wizard's
  blank screen; once SakuraOS is front, HOME is fine. Re-disable the wizard
  and re-set home any session where the churn grabs too long:
  `pm disable-user --user 0 com.google.android.tungsten.setupwraith` +
  `cmd package set-home-activity tv.sakura.launcher/.HomeActivity`.
  Instant manual exit when it holds the screen:
  `am force-stop com.google.android.tungsten.setupwraith` +
  `am start -n tv.sakura.launcher/.HomeActivity` (no reboot needed).
- Landing-back: after boot churn the wizard stops relaunching for the whole
  session; SakuraOS's own AlarmManager salvage covers the churn window.
- Verified config that always boots safely: launchers enabled + SakuraOS set via
  `set-home-activity` (never leave the system with zero eligible home apps).

## Video walls (Hollow Purple + three more)

HomeActivity hosts a `FrameLayout` with a `TextureView` (index 0) under the
`HomeView` canvas. `VideoLayer` (`VideoLayer.java`) keeps one muted, looping
`MediaPlayer` alive, mapped from the style key to `raw/vid_*.mp4`:

- `HomeView.drawHome` notifies the layer of the current style every frame
  (`VideoSink.onStyle`) and only leaves its wallpaper region transparent —
  drawing just two soft readability scrims — when `VideoSink.videoReady`
  reports the player presenting (verified by counting the frames handed to the
  surface). Any miss (style without video, surface lost, decode failure,
  lifecycle pause) falls back to the ordinary static-art + ambience render on
  the very same frame; there is never a black snapshot of the wall.
- Lifecycle: **hibernate when another app is front** (`onPause` → the player is
  released, the SurfaceTexture and its graphics buffers are freed by detaching
  the texture view; roughly 60 MB returns to the system). When home comes back
  (`onResume`) the texture view is re-attached and the next rendered frame
  rebuilds the player — a brief static-art moment is the only visible seam.
  `release()` on destroy and on the direct-boot unlock "upgrade" re-entry.
  The canvas view sits above the video, so clock, rows, petals and the corner
  mark always draw on top. The canvas render loop itself already stops when
  the activity pauses (petals/ambience are gated on `resumed`).
- Verified on the TV Oct 27: Hollow Purple loop presenting behind the home UI,
  two frames 2 s apart differ in 47.7 % of sampled pixels (static fallback
  would differ under ~2 %); crash buffer empty; ~127 MB PSS with the media
  surface (60 MB graphics).

## Performance pass (applied)

- SakuraOS render: petal bitmap-atlas (no per-frame Path rasterization),
  30 fps cap for idle petals, downscaled wallpaper decode (inSampleSize),
  cached ellipsized labels. Measured on the TV: median frame 13 ms, p95 16 ms,
  GPU 6-8 ms, janky 4.5% (live petals), idle burn roughly halved vs 60 fps.
- Memory: SakuraOS ~156 MB vs stock launcher pair ~306 MB.
- TV-side (all reversible, one command each):
  - `settings put global window_animation_scale 0.5` (+ transition/animator)
    — snappier system everywhere; revert = set back to `1.0`.
  - `pm disable-user --user 0 com.google.android.katniss` — Assistant processes
    free ~250 MB RAM; revert = `pm enable com.google.android.katniss`.
  - `pm disable-user --user 0 com.android.adservices.api` — Android ad-tech
    pipeline; revert = `pm enable com.android.adservices.api`.
- Uninstalled order of operations in future sessions: enumerate bodies with
  `dumpsys meminfo` (top RSS), act only on packages that burn RAM while idle.
