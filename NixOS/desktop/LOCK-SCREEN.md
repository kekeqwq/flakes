# Niri idle lock

Only `my.desktop.enable` enables this Linux integration. Production timeout is
**300 seconds**. `swayidle` uses the compositor's real seat idle notifications,
including native idle inhibitors; it does not poll mouse coordinates or exempt
all fullscreen windows.

- Mouse motion and keyboard input reset idle.
- Playing video inhibits idle in a window or fullscreen when the player requests
  it. mpv explicitly enables `stop-screensaver=yes`; Chrome uses its normal
  playback inhibition. Window titles, terminal output and IPC polling are not
  keyboard activity.
- Pausing/stopping playback releases inhibition. A fullscreen static editor is
  not an exemption.

The locker is `swaylock-effects`, authenticated by the user's PAM password.
Desktop and lock screen import the same tracked `wallpaper.nix` image. A 140 px
clock is centered on each output; the idle ring is transparent. Click anywhere,
type the user's password, then Enter; Ctrl+U clears the input. Clicking does not
unlock. **Win+L (`Super+L`)** locks immediately, independently of the Alt-based
Niri `Mod` setting.

`screen-lock` holds an owner-session flock across the daemon's lifetime.
`swaylock --daemonize` waits for secure locking before returning; `swayidle -w`
uses the same command before sleep. No screenshot of private windows is used as
lock wallpaper. This borrows Omarchy's simple wallpaper/clock interaction, not
its Arch, Hyprland or Quickshell implementation.

## Opt-in regression (real desktop, no VM)

`tests/linux-idle-regression.py` launches separate Ghostty, mpv and Chrome
fixtures, using a disposable browser profile and generated local video. It
never types into an existing window or copies account data. `/dev/uinput`
access is required. Devices are destroyed and fixture process groups closed on
exit. The desktop user is already in the appropriate group on Deck.

Supply store roots containing `swayidle`, `mpv` and `ffmpeg`, one per line, to
`--tools-file`. First run observer mode with a short timeout:

```sh
python3 tests/linux-idle-regression.py --tools-file /tmp/idle-test-tools \
  --timeout 5 --report /tmp/idle-observer.json
```

This checks actual idle delivery, real playback position, confirmed fullscreen,
window/fullscreen muted Chrome video, paused/stopped video, moving/stopped mouse,
physical-keyboard typing/stopping, and an idle fullscreen static window.
Wayland virtual-keyboard events are **not** a substitute for physical keyboard
idle testing: Niri need not count those as seat activity. The test uses kernel
uinput keyboards and pointers instead.

After observer success and installing the PAM/configuration, stop the normal
idle service and run with `--lock-command /path/to/screen-lock
--password-stdin`. Read the password interactively without echo and pipe it to
the process; **never** place it in argv, this document, a report or Git. Real
mode verifies locker presence, password-free clicks remaining locked, one wrong
password being rejected and correct-password unlock. It only authenticates or
recovers timer lockers carrying this test's unique token; the explicit hotkey
check below has its own acquisition/ownership gate. Recovery is a failed test,
not a passed password check.

Real mode also presses physical **Win+L**, waits for a fresh secure-acquisition
marker plus a new locker, and authenticates only after that confirmation. This
manual-hotkey locker is scoped to the test's explicit request after verifying
that no locker existed. A click and one incorrect password must leave it locked.

Add `--production-seconds 300` to additionally start the actual production user
service and measure a complete five-minute idle-to-lock cycle. No input is
injected during that interval. The service command must contain `timeout 300`.
Only stop an idle service when its locker has already unlocked: the service
cgroup may contain the locker.

Restart the normal `swayidle.service` afterwards and verify its command contains
`timeout 300`. The short regression timeout is not a production setting.
Reports contain timings/booleans, not passwords, prompts or screenshots.
