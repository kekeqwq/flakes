# LUKS2/FIDO2 lab deployment — 2026-11-16

## Installation and enrollment evidence

- Both repositories synchronized. New 64 GiB qcow2 on Deck, private directory;
  official minimal ISO SHA256
  `927b3102d3d1e2e7339803e2055c7511eb693e9869f7cc5202829341dfc0119e` verified.
- Actual official-ISO guest booted in a local GTK/VirGL window, UEFI, QEMU Q35.
  `systemd-detect-virt` reports **kvm**; the destructive helper also requires
  QEMU DMI and a completely blank `/dev/vda`. No Deck disk was formatted.
- Owner entered and confirmed the disk recovery password locally in the guest;
  no chat/argv/store secret. LUKS2 created and opened with that password; Btrfs
  `@root`, `@nix`, `@home` mounted with `compress=zstd:3`, ESP umask 0077.
- Actual native `nixos-install --system PREBUILT_CLOSURE --root /mnt` completed
  successfully. Prebuilt closure came from this repository, not `build-vm`.
  A signed, host-loopback-only cache avoided guest compilation. Guest keke login
  password set separately through local `passwd`; password status verified P,
  without reading hashes or passwords. No production accounts/state copied.
- Installer retries: transient systemd unit needed an explicit NixOS PATH;
  private provisioning umask made Btrfs subvolume roots 0700, so standard target
  traversal permissions were corrected to 0755 (ESP and backup permissions stay
  private). These failures were not claimed as completed installations.
- Owner-designated **primary** Key selected with read-only identity checks.
  Direct USB transport initially stalled configuration because host scdaemon
  held CCID. Only the idle smartcard daemon was released; gpg-agent and stored
  credentials were preserved, pcscd auto-exited. No PIN reset/guess, OTP disable,
  PIV/OpenPGP overwrite or FIDO reset.
- Guest then exposed a real FIDO hidraw interface. Native enumeration reported
  compatibility, presence support, no configured client PIN/UV requirement.
- Actual `systemd-cryptenroll` completed with owner touch. Helper verified one
  new **slot 1**, preserved recovery **slot 0**, PIN false / presence true / UV
  false in token policy. PAM credential handles were not used for disk unlock.
- Before/after LUKS headers and label/slot/token inventory kept root-only in the
  encrypted target and copied to an owner-only private directory on the host,
  **outside the virtual disk, Git and Nix store**. No materials embedded here.
  Owner still needs an appropriate private off-machine backup for durability.
- Target cleanly unmounted, mapper closed, installer gracefully powered off.
  USB returned to host. `installed-and-closed` marker created only afterward.
  Subsequent installed-disk boots were explicitly viewed/approved by the owner.

## Build and host persistence

Full Deck + secret-lab systems, ordinary desktop/headless boundaries and secret
lab boundaries built successfully. Lab system:
`/nix/store/gvs3vprbqw5zgfv1rrkd3b23vx11fj2h-nixos-system-secret-lab-26.11.20261115.5da7db4`.

Deck had actually booted an older vanilla locker without the PAM mapping/key
service; touching the Key produced OTP keyboard input, not FIDO authentication.
After owner password unlock and explicit local administrator activation, the
running system, persistent profile and loader default were verified against:
`/nix/store/ffbdv2x7svas3xrnp6c1bqnm3g8cjjby-nixos-system-deck-26.11.20261115.5da7db4`.
This is **not** a successful host cold-reboot test. No locker was killed or
signalled, nor its swayidle cgroup restarted while it held the compositor lock.

## Disk-unlock functions passed; graphical acceptance remains incomplete

- No-Key cold boot: no ISO/network adapter/USB Key, visible shared Plymouth
  password UI. Owner confirmed wrong password denied and correct recovery
  password entered the desktop; supplied a screenshot of the graphical prompt.
- Separate cold boot with the registered primary Key: owner confirmed **one
  touch only, no recovery password or PIN**, then desktop. Initrd journal shows
  FIDO2 authentication/presence request followed by successful cryptroot setup.
  Guest-agent checks confirmed `/`, `/nix`, `/home` on their encrypted mapper's
  Btrfs subvolumes, all with zstd:3. No prior guest RAM/keyring was reused.
- Owner confirmed guest lock-screen touch unlock works after correcting an
  initially missed physical touch. This is not a timed 300-second regression.

### Recovery after the stalled/black-screen attempt: passed

After streaming access was restored, the owner confirmed the QEMU window was
visible and authorized recovery testing. Guest ACPI powerdown did not exit the
initrd, so only the test VM received a hardware reset. With no USB Key attached,
the owner entered the correct recovery password and confirmed desktop access.
Guest-agent checks again verified all three encrypted Btrfs subvolumes with
zstd:3. Disk formatting, slot changes, password reset or reenrollment were not
needed. The earlier attempts did not permanently lock the disk.

### Updated `tries=0`: six wrong passwords, then success

The original image used systemd's bounded retry count. The shared module now
adds **`tries=0`**, with a boundary assertion. This is a process-local unlock
retry policy, not a LUKS header/keyslot operation or a hardware PIN policy change.
Full system build and Linux secret-lab boundary build succeeded. Updated system:
`/nix/store/3ip3z7ls0w7a8lzs2b37x0x5b0gjpwin-nixos-system-secret-lab-26.11.20261115.5da7db4`.

Five public store paths (37,679,704 bytes) were transferred using the private
local guest-agent socket, imported and installed for **boot**, without live
activation, a NIC, ISO, formatting, password reset or reenrollment. Initial
query/transfer helper errors were corrected before import/boot installation.
The built crypttab contained `tries=0`; default loader entry referenced the new
system. Guest OS reboot then entered that exact system, verified via agent.

Initrd journal records **six** incorrect-passphrase failures at 22:21:23,
22:21:27, 22:21:31, 22:21:36, 22:22:19 and 22:22:28, followed by successful
cryptroot setup at **22:24:10**. No password values were read or recorded.
The unbounded retry function is runtime-verified, not just source-evaluated.

**Prior graphical-crash suspicion remains unconfirmed:** owner reported that repeated errors made
the graphical password UI disappear into a text prompt and later could not
operate through Moonlight. Plymouth start/quit commands returned success; no
Plymouth crash/OOM was found in the inspected journal. That does not establish
theme health or explain the graphical-to-text transition. A host-native capture
of only QEMU at 22:31 showed the actual guest desktop; owner confirmed Moonlight
had frozen again. Thus a stale streaming view also interfered with observation;
it does not establish the cause of the earlier graphical complaint.

In the later no-Key repeat, the owner reported many entries without a graphical
failure and suspected an accidental TTY switch previously. A paused host-native
QEMU capture confirmed an intact graphical password screen. The subsequently
read boot journal, however, contains only a successful unlock at 23:06:06 and no
incorrect-passphrase records, so it cannot substantiate six submitted failures
for that observation. We did not continue testing after the owner asked to stop.
Do not call this a confirmed Plymouth crash, a repaired bug, or a quantitatively
verified six-error graphical test. The earlier six-error **disk retry** result
is independently established; Sunshine's repeated failures remain open.

### In-window Key insertion: touch-only success on the updated image

Primary serial rechecked read-only; host unlocked and idle card clients released
before whole-device handoff. Normal guest reboot was observed through QMP RESET,
then the real primary Key was hot-added to the guest after 8.054 seconds. This
is a guest USB hotplug test, not a separately measured physical cable replug.

- 22:52:37.297545: initrd reports no token and starts waiting.
- 22:52:41.625425: host requests actual Key attachment, about **4.3 seconds**
  after the wait began (not merely an estimate from reboot).
- 22:52:42.485813: FIDO2 authentication/presence request, about **5.2 seconds**
  after the wait began; no discovery timeout occurred.
- 22:53:11.487546: successful cryptroot setup, same updated system, encrypted
  Btrfs root with zstd:3. Owner explicitly confirmed **touch only, no recovery
  password or PIN**. The Key was then detached and returned to the host.

This also demonstrates that discovery timeout is not the physical-touch timeout.

### Late insertion: expected boundary, not an unconditional hotplug promise

Key was attached after **124.6 seconds**, with no guest agent/unlocked root
before attachment. Owner reported no LED challenge; agent remained unavailable.
Later touches without a challenge may have produced OTP keyboard input. A host
locker was also observed during the black-screen report, so that screen alone
is **not** evidence of a guest crash. Key was returned to the host; no locker
was killed or signalled.

Source review uses the actual initrd's **systemd v262**, pinned source hash
`sha256-oGzFW2dD8abLXBwDczr1hvl712s03CHTUqOz6uPfhmQ=`:

- [`crypttab.xml`, token-timeout](https://github.com/systemd/systemd/blob/v262/man/crypttab.xml#L962-L973)
  says device discovery waits until timeout, then falls back to password.
- [`make_security_device_monitor` / `run_security_device_monitor`](https://github.com/systemd/systemd/blob/v262/src/cryptsetup/cryptsetup.c#L1318-L1396)
  install a udev security-device monitor plus timeout; timeout returns EAGAIN.
- [`verb_attach`, FIDO2 fallback](https://github.com/systemd/systemd/blob/v262/src/cryptsetup/cryptsetup.c#L2698-L2702)
  clears `arg_fido2_device` and `arg_fido2_device_auto` before continuing to the
  password path. The same activation process does not automatically re-arm
  FIDO2 after a late insert; even password retries do not restore those flags.

Our `token-timeout=10s` therefore permits insertion **during the discovery
window**, not arbitrary insertion after password fallback. The observed >2-minute
case matches this implementation. No special retry/concurrent-unlock patch or
longer/infinite discovery wait is added. The separate in-window guest hotplug
test above now confirms that supported path with actual hardware authentication.

The owner accepts this boundary. The core primary-Key/password regression above
is passed; this does not turn the following untested cases into passes.

Plymouth password group is moved down 48px; touch/error message has another
24px of clearance. Initially this was code-only as requested; the subsequently
authorized `tries=0` initrd update included those positions. Visual acceptance
is **not** claimed, particularly given the unresolved graphical retry issue.

## Pre-desktop environment warning: source fix verified

Owner's later screenshot clearly showed systemd's warning:
`Calling import-environment without a list of variable names is deprecated.`
The pinned upstream `niri-session` contained a bare import. The shared Linux
desktop now selects a lightweight package that preserves the compositor binary
and upstream lifecycle, but explicitly enumerates exported variable names for
that call. Environment values are not placed in argv and stderr is not hidden.
Both greetd session commands use the selected package; display-manager sessions
also receive it through `programs.niri.package`.

The original launcher reproduces the warning in an isolated fake-manager test;
the patched launcher passes, including multiline values and unchanged start/
shutdown/DBus behavior. Linux `niri-session`, ordinary desktop/headless boundaries
and secret-lab boundaries built successfully; full Deck system evaluation passed.
This is **not** a claim of a live session update: no running compositor was
restarted or activated for this warning fix. It takes effect after deployment
and subsequent session startup. This warning is not established as the cause of
Sunshine's separate failure.

## Pending — do not report as passed

- Optional quantified graphical retry observation; prior suspected crash was
  not reproduced, and the owner suspects manual TTY switching.
- Lock/unlock/stream-resume failure, tracked in
  [`desktop-stream-lock-2026-11-16.md`](desktop-stream-lock-2026-11-16.md).
- Unregistered physical Key denial.
- Secondary Key per-volume enrollment and independent add/revoke tests.
- Post-install 300-second idle/lock/password/Key regression in the guest.
- Host cold reboot persistence and renewed physical lock-screen acceptance.

Guest Sunshine is disabled. Deck's normal display/streaming remains host-owned;
no guest pairing, LAN alias, bridge or Sunshine forwarding was configured.
