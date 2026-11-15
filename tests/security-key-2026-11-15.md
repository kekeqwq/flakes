# Hardware-key desktop acceptance — 2026-11-15

## Scope and state

Linux only: sudo policy in `NixOS/server/`, concurrent lock authentication in
`NixOS/desktop/`, public registry shared by new instances. The two physical keys
are YubiKey 5 NFC and 5C NFC. No device PIN, OTP/PIV/OpenPGP configuration,
partition, filesystem, disk key or LUKS header was changed. No VM was started.

Both registry entries were explicitly authorized for publication. They contain
public credential handles/keys, not private keys or PINs. Relying party is fixed
at `pam://keke-flakes`, not tied to the enrollment host's hostname.

The v5 runtime candidate was activated with **test** and then persisted with
**switch**. It passed password, touch, sudo, native idle, hotplug and FIDO
timeout-retry acceptance. The earlier v4 candidate failed hotplug (OTP keyboard
output + event-loop UAF); v5 replaced long-lived processes with bounded
per-attempt processes and fixed the deferred fd-removal bug. All acceptance
steps below reflect the v5 candidate.

## Real hardware and PAM

- Primary: isolated real `pam_u2f` authentication passed, with user presence
  required and PIN/UV disabled. The conversation refused every secret-input
  request; no PIN/password was requested. First human-response window: 18.34 s.
- Secondary: already had a PIN. Initial CTAP2 creation requested one and was
  aborted without a PIN guess/reset (retry count remained intact). Client-only
  CTAP1/U2F registration then succeeded; attestation was verified and the normal
  unmodified PAM module authenticated that credential with no PIN/password.
  Two touch windows timed out; the successful attempt took 0.51 s.
- Real negative authorization: primary hardware against a secondary-only list
  was rejected in 0.39 s, with no secret-input request. This is an actual
  non-enrolled-relative-to-the-list test, **not** a claim to have tested a third
  physical key.

## Actual temporarily activated system

- `sudo -k -S ... true`, with EOF stdin, passed by touching the primary Key.
  Cached sudo credentials were not accepted and no PIN/password was provided.
  Two windows timed out before the successful human response (85.40 s total).
- Real lock touch passed without any injected keyboard input; lock and hardware
  worker exited. 37.09 s includes the human-response wait, not touch latency.
- Real password regression: secure compositor acquisition, active parallel key
  worker, singleton, mouse/empty-Enter remaining locked, wrong-password denial,
  correct-password unlock while the Key waited, worker cleanup, immediate
  relock and no stale authentication proof all passed. Password submission to
  full cleanup took **0.177 s** while the Key waited.
- Owner subsequently reported working sudo and lock tests after removing the
  Key. This is owner-reported manual password-fallback evidence, not a captured
  automated password test. The second local secret prompt timed out; its
  longer password-driven test was **not run** and is not counted as a pass.
- A no-secret native-input/playback suite passed **16/16**: actual kernel mouse
  and keyboard activity, mpv window/fullscreen playback and pause/stop, Chrome
  window/fullscreen audio/muted playback, and static fullscreen becoming idle.
  Playback position was checked repeatedly. No blanket fullscreen exception or
  pointer-position polling was used. A complete real production lock then
  acquired securely in **300.30 s** with no Key present. Its background key
  worker existed, and SIGUSR1 sent to the compositor-facing locker did not
  unlock it. No password or keyboard input was injected during that timing.
- **Hotplug acceptance PASSED** after v5 fix: key inserted after lock → 3
  different FIDO auth processes successively held the device lock across
  unattended timeout windows (no stale-lock deadlock) → one touch unlocked
  the session → auth workers cleaned up. No OTP keyboard output observed.
  The v5 fix resolved the event-loop UAF (loop_remove_fd called from within
  loop_poll callback, fixed to deferred removal) and replaced long-lived
  PAM/FIDO processes with bounded per-attempt processes. ASan regression:
  200 deferred EOF/retry cycles PASS. Full `switch-to-configuration switch`
  persisted successfully.

Authentication/account approval is required by the key worker. The unprivileged
`pam_unix` account helper can log `setuid failed: Operation not permitted` at
DEBUG level before executing its expiry-check helper; reviewed Linux-PAM 1.7.2
`pam_unix_acct.c` explicitly permits this non-root path. It is not an auth bypass:
the locker only accepts success after `pam_acct_mgmt` and `pam_end` return success.

Niri's pinned `SessionLockHandler::unlock` calls `notify_activity`, which calls
the native idle notifier. Touch unlock therefore re-arms native idle without
injecting fake keyboard/mouse activity.

## Build and non-hardware checks

- Full Deck system built; desktop and secret-lab boundary checks built. Generic
  fixtures cover desktop without Jovian and headless sudo without GUI locking.
- macOS system derivation evaluated; treefmt check built. No Darwin activation.
- Worker tests (fake PAM linked only into the test binary): success, auth denial,
  expired-account denial and refusal to answer a PIN request.
- Client tests (fake helper never installed): success, invalid message, EOF,
  spoofed sender PID, FD 9/10 isolation, cancellation/reaping and parent death.
- Production helper uses an anonymous credential-checked socketpair, not a
  public unlock socket or signal. Kernel PID/UID credentials must match this
  exact worker. Locker/worker are nondumpable. Password cancellation uses a
  pidfd; auth workers must not retain the singleton flock.

All secret input was local GUI → memory/stdin only. No password was placed in
argv, reports, Git, Nix store or screenshot artifacts. Tests used isolated GUI
fixtures and a disposable password-field input catcher, never user chats.
Failed tests preserve the secure lock for manual recovery instead of killing it
or its service cgroup. Long observation/timing tests do not collect passwords.
