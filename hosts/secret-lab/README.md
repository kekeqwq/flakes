# secret-lab: encrypted ZFS desktop reference

`lab` / `lab-x86` remain the existing **unencrypted ext4** reference; their private
files are unchanged. `secret-lab` is a separate x86_64 QEMU instance importing the
same desktop baseline, with its own storage/identity/virtio output. Plymouth is
now part of the public Linux desktop layer, not a host-specific package list.

## Boot design

Firmware → systemd-boot → systemd initrd + early virtio KMS → Plymouth ZFS key
question → mount encrypted root/Nix/home → Niri autologin → ordinary 300-second
true-idle PAM lock. The disk passphrase and account password are independent.
There is no LUKS container: OpenZFS encrypts `secret-lab/secure`; all three
children inherit this single encryption root. `keylocation=prompt` means no
secret key file is embedded in initrd or the public store.

The common Plymouth design uses our tracked mountain wallpaper, a Catppuccin
Mocha veil, lavender Nix snowflake and an indeterminate loading ring. Password
entry replaces the ring; it resumes after unlock. Boot, reboot and poweroff use
the same animation, with no guessed percentage or artificial progress timer.
ZFS unlocks a key; it does not decrypt the entire filesystem at boot.
Unencrypted desktops also animate without a password step.

Omarchy reference: `basecamp/omarchy@74de10479d3bf7aa7865408e33219064cfe45432`,
`default/plymouth/omarchy.script`. Its graphic prompt and progress come from
Plymouth in the initramfs, while its disk encryption uses LUKS. NixOS's native
ZFS import service already uses `systemd-ask-password`; Plymouth services supply
the graphical agent. No Arch/Hyprland boot framework is imported here.

## Fresh installation — destructive steps only in the NEW QEMU guest

Use a fresh 64 GiB qcow2 and the official minimal ISO. Never run the following
against Deck or an existing disk. The helper requires QEMU, an entirely blank
`/dev/vda`, and an explicit erase flag; rebuild never calls it.

```sh
sudo bash hosts/secret-lab/partition-and-mount.sh --erase-fresh-qemu-vda
# Secret prompt: choose at least eight characters (OpenZFS requirement).
sudo nixos-install --flake /root/flakes#secret-lab --root /mnt --no-root-passwd
sudo passwd --root /mnt keke
sudo umount -R /mnt
sudo zpool export secret-lab
sudo poweroff
```

For unattended provisioning the helper also accepts `--key-fd N`: provide the
passphrase over a private pipe, not argv, environment, Git, a boot parameter or a
Nix option. Set the account password in the target shadow database at install
time. Trivial regression credentials are supplied privately, not in this file.
All future real installations must select strong independent passwords.

The script enables `compression=zstd` at the pool root; descendants inherit it.
Compression is transparent and precedes encryption. Changing compression only
affects newly written blocks; it does not rewrite existing data. Deck already
has `zstd` on its pool/root/Nix/home; no live property change was necessary.

## VM control / viewing gate

`tests/secret-lab-vm.sh installer PRIVATE_DIR` starts only the ISO, with no local
window, Unix QMP/VNC sockets and installer SSH forwarded on **127.0.0.1:22323**.
Supply `QEMU_ROOT` and `OVMF_ROOT` from this flake's Nix packages. This is test
infrastructure, never a `build-vm` installation or a NixOS service.

After successful installation, unmount and export, create the private
`installed-and-exported` marker. The emulator is then **off**. Do not start the
installed disk before the user confirms that Moonlight is showing Deck's
existing desktop. Only then run:

```sh
QEMU_ROOT=/nix/store/...-qemu OVMF_ROOT=/nix/store/...-OVMF-fd \
  bash tests/secret-lab-vm.sh desktop PRIVATE_DIR
```

This opens the new VM as a GTK/VirGL window on Deck, with the ISO detached. No
LAN alias, DNAT, bridge, guest remote-desktop pairing or public port forwarding
is created. The guest retains shared Sunshine integration for future private
provisioning, but it is not used for this boot/crypto test.

## Acceptance / limits

Before unlock: see the wallpaper/password UI, no desktop, key unavailable.
Wrong passphrase must not continue. Correct passphrase should ask only once,
mount all three encrypted children and proceed directly into Niri. Check
`encryptionroot`, `keylocation`, `keystatus`, `compression`, mounts and kernel;
verify a real PAM lock at 300 seconds and password unlock with the account
password, not the disk key. Also test a static fullscreen window and playing
window/fullscreen video against the shared idle policy.

Build/evaluation and installation are not a successful cold-boot regression.
When the user requests an installation-only handoff, report the cold-boot/UI
acceptance as **pending**, and do not boot the disk to silently collect evidence.

This protects data at rest, **not against an evil-maid bootloader replacement**:
ESP/initrd are unencrypted, Secure Boot/signing/measured boot are not configured,
ZFS exposes some dataset/pool metadata, and autologin leaves the unlocked session
accessible until screen lock. No unencrypted swap or unsafe hibernation is
configured. Keep private key backups/recovery material outside Git/Nix store.

Firmware logos, GPU modesetting and monitor link training can still cause a
brief physical black frame; quiet kernel/systemd settings do not control those.
Failures remain diagnosable (Esc for Plymouth details; Space at power-on for the
boot menu). No fake claim of guaranteed zero black frames on every GPU is made.
