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

The locker is the pinned `swaylock-effects` with a local concurrent hardware-key
backend (`pkgs/swaylock-security-key/`). Unlock with **the account password +
Enter, or one touch of an enrolled Key**. Touch requires neither Enter nor a PIN.
The password and key PAM transactions are independent: an inserted Key waiting
for touch must not delay typing a password. Missing keys retain password unlock;
a newly inserted enrolled Key is picked up automatically while locked.

Public authorization records live in
`System/Common/security-keys/credentials.json` with a stable relying-party ID;
new NixOS instances inherit the same sudo policy and desktop instances inherit
the lock policy without per-host switches. This does not enroll a disk: each
LUKS2 volume requires its own installation-time hardware enrollment.

Desktop and lock screen import the same tracked `wallpaper.nix` image. A 140 px
clock is centered on each output; the idle ring is transparent. Click anywhere,
type the user's password, then Enter; Ctrl+U clears the input. Alternatively,
just touch the blinking authorized Key. Clicking does not unlock. **Win+L (`Super+L`)** locks immediately, independently of the Alt-based
Niri `Mod` setting.

`screen-lock` holds an owner-session flock across the daemon's lifetime.
`swaylock --daemonize` waits for secure locking before returning; `swayidle -w`
uses the same command before sleep. No screenshot of private windows is used as
lock wallpaper. This borrows Omarchy's simple wallpaper/clock interaction, not
its Arch, Hyprland or Quickshell implementation.

Key authentication starts only after compositor-confirmed secure acquisition.
Only a successful authentication/account check on the strict `swaylock-key` PAM
stack can release the key path. A private socketpair verifies the helper's
kernel-supplied PID/UID credentials; failure, EOF, an unknown key, missing
configuration and worker exit do not unlock. SIGUSR1 is not authentication and
is ignored. The password path remains available if the key helper fails. See the
package README for lifecycle and singleton-FD safeguards. Niri's session-unlock
handler itself notifies native idle activity, so touch unlock re-arms idle without
synthetic typing or a fake mouse-movement loop.

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
password being rejected and correct-password unlock. Use a dedicated transient
test unit/cgroup: hardened lockers are nondumpable, so ownership is checked via
actual process UIDs/cgroups rather than requiring access to `/proc/.../environ`.
The explicit hotkey check below has its own acquisition/ownership gate. Failed
acquisition/authentication leaves the lock intact for manual recovery; tests do
not bypass authentication with signals or kill a lock-containing cgroup.

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

Additional opt-in hardware checks:

- `tests/linux-security-key-pam.py`: isolated real PAM with no production edits;
  refuses every PIN/password input request.
- `tests/linux-security-key-regression.py`: temporary test activation and secure,
  owned real-lock password/singleton/concurrency/cleanup tests. A disposable
  password-field window catches any unexpected post-unlock fixture input.
- `tests/linux-security-key-touch.py`: bounded actual lock touch or sudo `true`
  reauthentication; no injected password, no cached sudo credential acceptance.
- `tests/linux-security-key-idle.py`: no-secret native input/video observations
  followed by a real 300-second production lock; leaves the lock intact for
  manual password or hotplug/touch acceptance.

Never request or record a PIN/password in chat. If a local secret prompt times
out, report the test as not run rather than counting it as successful. Separate
isolated PAM results, owner-reported manual tests, real lock tests and persistent
system activation when reporting acceptance.
