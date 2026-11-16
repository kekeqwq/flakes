# secret-lab: LUKS2 + Btrfs zstd / FIDO2 desktop regression

This is a **new QEMU disk**, not a conversion of Deck. `lab` / `lab-x86` remain
unencrypted ext4. The earlier uninstalled native-ZFS reference is replaced here
by standard LUKS2 + Btrfs integration. Deck's disks, kernel and services are not
changed by these scripts.

## Boot and authorization

UEFI → systemd-boot → systemd initrd / virtio KMS → shared Plymouth → LUKS2
unlock → Btrfs `@root`, `@nix`, `@home` → shared Niri desktop. All three
subvolumes share one encrypted container and use `compress=zstd:3`. The ESP is
unencrypted, mounted with `umask=0077`; there is no swap or hibernation image.

Unlock requires **the recovery password OR an individually enrolled Key's
physical touch**, without a daily PIN or biometric requirement. No insertion-only
unlock. `my.luks.fido2.enable` adds native systemd crypttab options and initrd USB
support; it does not format, enroll, or read the PAM public registry. Every
volume needs separate physical enrollment. Only the private LUKS header carries
its credential/salt/slot metadata; no disk key enters Git, initrd or Nix store.

An absent device has a 10-second discovery timeout before password fallback.
This is **not** the touch timeout, nor a claim that systemd's disk password and
FIDO prompts are concurrent like our independent lock-screen backends. The actual
Plymouth touch/password interaction must be verified at cold boot.

## Installation — only inside the new official-ISO guest

The launch helper pins the official minimal ISO:
`nixos-minimal-26.11pre1119549.d5cc68339997-x86_64-linux.iso`, SHA256
`927b3102d3d1e2e7339803e2055c7511eb693e9869f7cc5202829341dfc0119e`.
Source: `https://releases.nixos.org/nixos/unstable/nixos-26.11pre1119549.d5cc68339997/`.

The helper refuses physical/non-QEMU systems, non-EFI boot, any existing vda
signature/partition/mount, existing mapper/labels, or an installed target. It is
never invoked by a rebuild. Choose a strong independent recovery password in a
local private prompt; it is not the login password.

```sh
sudo bash hosts/secret-lab/partition-and-mount.sh --erase-fresh-qemu-vda
```

`--key-fd N` is available for private provisioning: one password line on an
inherited private FD, never argv/environment/chat/logs. The minimum is 12
characters. The helper leaves password slot **0** intact. Do not supply secrets
through tool arguments, QMP keystrokes, screenshots or shell tracing.

### Enroll each owner-designated Key separately

First confirm Deck is unlocked, insert the specified Key, and grant the VM that
exact USB bus/address. Never select all Yubico devices or treat a USB serial as
authentication. Do not reset FIDO/PIN, disable OTP, or overwrite PIV/OpenPGP.

Inside the guest, list FIDO devices with `systemd-cryptenroll --fido2-device=list`.
Use the pinned flake's `pkgs.python3`, `pkgs.cryptsetup` and `pkgs.systemd` tools
if the live ISO lacks any helper. Then, on a local interactive terminal:

```sh
sudo bash hosts/secret-lab/enroll-key.sh --fido2-device /dev/hidrawN --label primary
# Later, with the other physical Key, repeat using --label secondary.
```

The helper tests recovery password slot 0 before changes, saves root-only header
backups under the encrypted target's `/var/backups/flakes-luks`, and enrolls with
client PIN **no**, user presence **yes**, user verification **no**. It does not
wipe slots. **Explicitly prompt the owner to touch when the LED flashes**; a
second enrollment touch may be required. Stop if a Key demands an unknown PIN;
never guess/reset it. Enrollment is not a successful cold-boot test.

It verifies one added slot, retained existing slots and the recorded touch/no-PIN
policy. Private `inventory.json` links the owner label to the new slot/token IDs.
Export backups **privately off this virtual disk**: an encrypted in-volume copy
alone cannot recover a damaged header. Never commit/copy these files into the
public store. Protect both before/after headers as recovery materials.

Install and set the independent login password privately:

```sh
sudo nixos-install --flake /root/flakes#secret-lab --root /mnt --no-root-passwd
sudo passwd --root /mnt keke
sudo umount -R /mnt
sudo cryptsetup close cryptroot
sudo poweroff
```

Only after installation, unmount, close and VM shutdown create the private
`installed-and-closed` marker. The ISO must be detached for installed-disk boot.

## Display / USB / networking

`tests/secret-lab-vm.sh installer PRIVATE_DIR` opens the official minimal ISO in
an actual **GTK/VirGL window on Deck**. Installer-only SSH management is bound to
**127.0.0.1:22323**, not LAN. Guest outbound NAT can fetch installation packages.
There is no bridge, LAN alias, Sunshine proxy, pairing state or guest streaming.
The guest's Sunshine is disabled; Deck's existing Sunshine is not modified.

Provide `QEMU_ROOT`, `OVMF_ROOT`, and optionally the owner-approved `USB_BUS` /
`USB_ADDR`. The helper checks permissions/vendor only as a sanity check and
refuses USB capture while the host's locker/key worker is active. Direct USB
passthrough temporarily removes the whole Key from host applications. It does
not change the Key's enabled functions. Replugging can change its bus/address;
reselect explicitly. Without USB arguments the VM can test password recovery.
Whole-device passthrough also needs the CCID interface: a host `scdaemon` can
cause guest `can't set config #1, error -32` even though OTP/FIDO interfaces were
claimed. Close smartcard clients, explicitly release the idle user's connection
with `gpgconf --kill scdaemon` (not the whole gpg-agent), and let pcscd auto-exit.
This closes a connection, not a FIDO factory reset or PIV/OpenPGP credential
change. The launcher refuses competing card daemons rather than killing them.

**Do not start the installed disk until the owner confirms they are watching
Deck's desktop/window.** Only then:

```sh
VIEWING_CONFIRMED=yes QEMU_ROOT=/nix/store/... OVMF_ROOT=/nix/store/... \
  USB_BUS=1 USB_ADDR=2 bash tests/secret-lab-vm.sh desktop PRIVATE_DIR
```

Installed-disk mode has **no network adapter**. A private virtio guest-agent Unix
socket becomes usable only after root unlock for non-secret status checks. QMP,
serial and agent sockets/logs stay inside the owner-only VM directory. There is
no VNC listener (GTK/VirGL and VNC cannot share this QEMU GL display). Do
not use QMP/guest-agent argv for passwords. Shut down gracefully from the guest
or QMP power button; do not kill QEMU while filesystems are mounted.

## Add / revoke / acceptance

Adding a later Key repeats per-volume enrollment without touching existing slots.
For revocation, first independently test the recovery password, privately back up
the current header, identify the **exact slot** from private inventory, then use
`systemd-cryptenroll --wipe-slot=NUMBER DEVICE` for that slot only. Never use
`--wipe-slot=fido2` to remove one of several Keys. Verify remaining Key(s) and
password afterward. PAM authorization is separate and must be revoked separately.
Old headers/snapshots/disk copies can restore old authority: synchronize private
backup handling, and never claim current revocation invalidates previous copies.

Cold-boot matrix: no Key/password, wrong password denial, correct password;
registered Key touch without PIN; unregistered Key denial; unplug/replug and
second-Key enrollment; no desktop before unlock; all Btrfs mounts/compression;
shared 300-second lock and independent login-password recovery. Tests involving
physical third Keys or cold boots remain pending until actually performed.
Build/evaluation/metadata checks do not establish hardware/GUI acceptance.

The shared mountain/Mocha Plymouth, lavender Nix logo, loading ring and password
UI are unchanged. Esc exposes boot diagnostics. Unencrypted desktops still have
no disk prompt. Secure Boot/signing/measured boot are **not** configured: this
protects data at rest, not an evil-maid replacement of ESP/initrd. Autologin leaves
the unlocked desktop accessible until lock. Firmware/GPU link training can still
produce black frames; no guaranteed zero-black-frame claim is made.
