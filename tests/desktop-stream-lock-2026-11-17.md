# Deck follow-up — 2026-11-17 (CST)

## Verified current state, not yesterday's assumptions

Read-only SSH via existing `deck.local` resolution, BatchMode, strict host-key
checking and connection timeout. Host/user verified as `deck` / `keke`.

- Boot 18:36; repository HEAD `1a448b5f2777a6f2844afdb7819f337be753dffc`, clean.
- Running and persistent system both
  `/nix/store/ffbdv2x7svas3xrnp6c1bqnm3g8cjjby-nixos-system-deck-26.11.20261115.5da7db4`.
- Niri PID 1810; Sunshine PID 2215, running since boot. SDDM/Jovian entry,
  not greetd. Journal records lock at 18:43:11, no subsequent unlock in the
  inspected log. Two swaylock processes remain; neither was signalled.
- DP-1 logical 1920x1080 at (0,0), eDP-1 logical 853x533 at (1920,0),
  scale 1.5 / transform 270. No layout or DPMS changes were made.
- Sunshine 2026.914.233613; logged KMS DP-1 / H.264 VAAPI, Mesa 26.1.2,
  vendor kernel 7.2.10-valve1. Last inspected stream establishment 18:38:07;
  no disconnect in the filtered log. This is not client-side acceptance.

## Current contrast to historical failure

Around 20:01, one unauthenticated local probe per endpoint:

| endpoint | result |
| --- | --- |
| HTTPS 47984 `/serverinfo` | TLS established in 0.0072s; no HTTP response (no client certificate supplied) |
| HTTP 47989 `/serverinfo` | HTTP 200, 0.0005s total |
| HTTPS 47990 `/serverinfo` | TLS 0.0057s, HTTP 404 (route is not the Web UI root) |

47984 listener queue was zero before and during later samples. No repeated
TLS probes or authenticated requests were issued. This does **not** reproduce
last night's blocked TLS service, nor validate pairing/resume.

A single `session::video` wait on `drm_syncobj_array_wait_timeout` was followed
by futex waits and later active CPU. Across three two-second-interval samples,
video CPU grew by 3 then 2 ticks; capture grew by 2 then 1 (100 ticks/sec).
UDP queues were empty; this does not measure packet/frame progress. Whole-Wi-Fi
transmit counters also grew, but are not attributable solely to Sunshine.
No new GPU fault/reset was found in the inspected boot-log sample; this is not
proof of GPU/capture health. `/proc/.../stack` was permission-denied; no sudo or
ptrace was attempted. No stacks establishing a deadlock have been obtained.

## Discriminating hypothesis / next evidence

Inspected public upstream `src/nvhttp.cpp` at tag `v2026.914.233613` (matching
the running derivation, whose patches list is empty). `/resume`, when session
count is zero, synchronously calls display preparation and `video::probe_encoders`
before writing the response. A blocked handler is a candidate for the earlier
secure-service symptom, **not a proven cause**. Need a blocked-service stack
and logs around the specific request to distinguish this from session teardown,
certificate handling or another lock. Do not increase HTTP worker counts or
change capture backends based on this hypothesis alone.

`tests/sunshine-snapshot.py` samples only process/thread identity, CPU ticks,
wait channels and owned socket queues. It does not collect addresses, peer
ports, packet contents, environments, certificates or app state; does not
connect, attach, signal, inject input, or use sudo. Bounds: 1–5 samples,
0.2–10s interval. Run as keke on Linux with the **currently verified** service PID:

```sh
python3 tests/sunshine-snapshot.py --pid PID --samples 3 --interval 2
```

The script passed three offline parser tests and ran successfully against PID
2215 on Deck. Wait/CPU/queue samples alone are not an end-to-end streaming test.
The optional 463.8 MiB full public source substitution was cancelled by terminating
only this task's `nix-store` client; necessary source files were instead retrieved
on Mac. No running service was stopped.

## Niri and validation boundaries

The actual launcher `/run/current-system/sw/bin/niri-session` resolves to
`d2r1zcvri3fiz8wfzmj1mbylv3rnvbnl-niri-26.04/bin/niri-session`, containing bare
`systemctl --user import-environment`. Thus the explicit-environment patch is
**not deployed**. No matching warning was found in the readable boot journal;
launcher output may be on the login terminal, so absence is not a fix.

Current independent worktree full Deck toplevel derivation evaluation succeeded:
`/nix/store/qk1mrylxqdarwgx7gjzx3g5cbai0d0ym-nixos-system-deck-26.11.20261116.4bc82a2.drv`.
Existing `checks.x86_64-linux.niri-session` was copied as a derivation to Deck
and realized successfully with `--max-jobs 1 --cores 1`:
`/nix/store/1pq60dqy9fhpg6h2h168zffxa4ij460h-niri-session-environment-check`.
This is launcher test/build acceptance, not actual login acceptance. No system
configuration was changed this round; no full system build or boundaries rerun,
activation (`test`/`switch`), relogin, service restart, VM or disk operation.

Sunshine is still **unresolved**, without a new mitigation or root-cause patch.
Await owner confirmation of current Moonlight output and normal interactive
unlock/reconnect/input reproduction before invasive diagnosis. A ptrace attach,
Sunshine restart or deployment needs separate permission; never stop an active
locker's cgroup. All private pairing, VM and recovery state remains untouched.
