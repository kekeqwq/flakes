# Deck lock/unlock streaming incident — 2026-11-16

## Status: severe unresolved failure

The desktop lock/unlock/stream-resume regression is **failed**, not passed.
Niri IPC responsiveness alone is not proof of working desktop presentation or
input. Earlier wording that Niri was normal was too broad and is withdrawn.
The separately scoped LUKS primary-Key/recovery-password boot results do not
establish desktop streaming acceptance.

## Observations (CST / UTC+8)

- Owner reported frozen Moonlight presentation and pointer confined to Deck's
  internal display. Screenshot showed host Waybar/QEMU chrome with black guest
  content. A later screenshot remained at **Resuming Desktop** after reconnect.
- Niri's journal records lock at 21:10:40 and unlock at 21:31:04. Temporal
  association is established; causation is not yet established.
- Read-only checks after unlock: no active swaylock, Niri IPC responsive,
  DP-1 at (0,0), 1920x1080; eDP-1 at (1920,0), logical 853x533. Both connectors
  enabled with DPMS On. No display was disabled or rearranged during diagnosis.
- Configured Sunshine capture is DP-1/KMS/VAAPI. Mac Moonlight's
  `mouseacceleration` preference remains 0 (relative mode). These settings alone
  do not prove the live input mapping is correct.
- Sunshine PID 2258 remained alive. Last observed client disconnect: 21:38:24.
  Thread names include nvhttp, nvhttp::47984 and stream::videoBr. Sleeping thread
  states alone do not prove or locate a deadlock; no stack trace was obtained.
- Local server probes: HTTP 47989 `/serverinfo` returned 200 immediately;
  HTTPS Web UI 47990 returned 401 immediately. GameStream HTTPS 47984 completed
  TCP connection in about 0.0002 seconds but failed TLS establishment within the
  2-second connection timeout.
- `ss -lnt` showed 47984 listening with **Recv-Q 9**, while 47989/47990 had 0.
  Local timed-out TLS probes left queued/closing connections. This is evidence
  of a stalled secure GameStream service path, not simply a dead client window.
  No further repeated probes should add unnecessary backlog.
- No recent GPU timeout/reset was found in the inspected kernel-log sample.
  That does not exclude graphics/capture bugs or prove Niri rendering healthy.

## Safety and remaining work

Initial diagnosis did not restart Sunshine/Niri, switch compositor/session,
shut down monitors, signal a locker or bypass authentication. The USB Key had already been
returned to the host. The encrypted guest remains a separate VM; black output
alone does not diagnose LUKS corruption or permanent password lockout.

Owner subsequently authorized a **Sunshine-only restart**. Its cgroup was checked
for locker/authentication processes before restarting. Sunshine PID changed from
2258 to 457518; Niri PID 1849 and the VM remained running. The 47984 accept queue
returned to zero; an unauthenticated diagnostic connection completed TLS in
about 0.006 seconds, then received the expected client-certificate-required
alert (not an authenticated-stream acceptance test). Owner then confirmed QEMU
was visible and successfully completed guest recovery-password reboot testing.

This restored access but is **mitigation, not a verified fix**. Per owner request,
further Sunshine investigation is paused until the VM regression is complete.
Need identify the blocked secure-service path and repeat
real lock/unlock/reconnect plus input/output regression before closing this
incident. Do not change pairing state, client certificates or private keys.

## Further observations / end-of-day handoff

The owner encountered the same lock/unlock failure again. The 47984 accept queue
was 5 and TLS again timed out; another authorized Sunshine-only restart restored
TLS. Later the owner reported a frozen view/input even with an empty 47984 queue.
A host-native capture of only QEMU at 22:31 showed the guest desktop while the
owner's earlier stream frame showed the 22:22 password console. Therefore do not
reduce the whole incident to HTTPS alone or call alive IPC proof of healthy
presentation. Rendering/capture/transport/input still need separate isolation.

The owner accepted the separately measured disk-unlock results and stopped work
for the night. Niri's environment-import warning has a code/test fix but no
updated-session acceptance; it is not a demonstrated Sunshine fix. No stream
stability patch was deployed. Public repos are to be synchronized and guest/host
normally powered off; shutdown outcome must be reported separately, not assumed.
See [`HANDOFF-2026-11-16.md`](HANDOFF-2026-11-16.md).
