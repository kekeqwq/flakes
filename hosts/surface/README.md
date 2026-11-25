# Surface

`nixosConfigurations.surface` is the native AArch64 installation and replaces the old standalone and `secret-lab-surface-test` configurations. The unrelated `secret-lab` instance is unchanged.

- Hardware, kernel, device tree, touch, and zboot UKI lifecycle: the `surface.nix` input.
- Desktop and accounts: the standard NixOS desktop and shared programs in this flake. The host explicitly selects the Denali protected FullIO render module for its internal stereo speakers and MicArray. It does not install experimental audio monitors or tools into the user profile.
- The test install keeps NVMe root `NIXOS_ROOT` (ext4) and ESP `NIXOS_EFI` (VFAT), no swap, NTFS or initrd LVM. The formal install will separately review `secret-lab`'s LUKS2/FIDO2 setup and Btrfs/zstd; this configuration does not repartition, encrypt or enroll keys.
- Provision owner-held firmware at `/var/lib/surface-firmware` as documented in `surface.nix`. Keep firmware, private UKIs and SSH credentials out of Git and the public Nix store. The existing SSH authorized keys are deployed privately.
- Dedicated testing only: `ssh -o BatchMode=yes keke@<Surface-IP>` needs neither a password nor a client key and has no source-IP restriction. Since `keke` also has a host-local `NOPASSWD: ALL` sudo rule, anyone who can reach SSH can become root. Do not expose this test system to an untrusted network. Direct SSH root login remains disabled; remove both the SSH/PAM and sudo exceptions before formal use.

```sh
nix build .#checks.aarch64-linux.surface-boundaries --no-link
sudo nixos-rebuild switch --flake .#surface
```

The regular systemd-boot generation list boots Denali UKIs. Keep the separately archived, verified rescue UKIs and their closures until the new generation passes a real boot and desktop test. No test render overrides belong in this host.
