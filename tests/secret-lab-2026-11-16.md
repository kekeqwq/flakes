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

## Core regression: passed within the primary-Key scope

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

The original installed image still uses systemd's default bounded retry count.
The new shared module policy adds **`tries=0`**, with a boundary assertion, to
allow unlimited recovery-password retries. This is a process-local unlock retry
policy, not a LUKS header/keyslot operation and not a change to YubiKey PIN retry
limits. Source evaluation passed; the updated initrd is **not yet deployed or
runtime-tested**. Multiple wrong passwords followed by a correct password on
that updated image remains pending.

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
longer/infinite wait is added. A true manual insert inside the 10-second window
was not separately measured; support there is established by source behavior,
not claimed as another completed physical test.

The owner accepts this boundary. The core primary-Key/password regression above
is passed; this does not turn the following untested cases into passes.

Plymouth password group is moved down 48px in source; touch/error message has
another 24px of clearance below it, avoiding the loading ring. Per owner request
there is **no VM rebuild or deployment** for this layout-only change; visual
acceptance of the new positions is not claimed.

## Pending — do not report as passed

- Updated `tries=0` initrd deployment and repeated-wrong-password recovery test.
- Unregistered physical Key denial; independently timed in-window hotplug test.
- Secondary Key per-volume enrollment and independent add/revoke tests.
- Post-install 300-second idle/lock/password/Key regression in the guest.
- Host cold reboot persistence and renewed physical lock-screen acceptance.

Guest Sunshine is disabled. Deck's normal display/streaming remains host-owned;
no guest pairing, LAN alias, bridge or Sunshine forwarding was configured.
