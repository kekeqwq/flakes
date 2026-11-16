# LUKS2/FIDO2 lab deployment — 2026-11-16

## Completed evidence (not cold-boot acceptance)

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
  Installed-disk first boot awaits explicit viewing confirmation.

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

## Pending — do not report as passed

- First installed-disk boot, without ISO or network adapter; visible Plymouth
  password UI, wrong-password denial and successful recovery-password unlock.
- Cold boot with registered Key: physical touch, no PIN, correct mounts/desktop.
- Unregistered physical Key denial, boot hotplug/fallback behavior.
- Secondary Key per-volume enrollment and independent add/revoke tests.
- Post-install 300-second idle/lock/password/Key regression in the guest.
- Host cold reboot persistence and renewed physical lock-screen acceptance.

Guest Sunshine is disabled. Deck's normal display/streaming remains host-owned;
no guest pairing, LAN alias, bridge or Sunshine forwarding was configured.
