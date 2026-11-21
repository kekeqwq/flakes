# Surface

`nixosConfigurations.surface` is the native AArch64 installation and replaces the old standalone and `secret-lab-surface-test` configurations. The unrelated `secret-lab` instance is unchanged.

- Hardware, kernel, device tree, touch, and zboot UKI lifecycle: the `surface.nix` input.
- Desktop and accounts: the standard NixOS desktop and shared programs in this flake.
- Existing NVMe root `NIXOS_ROOT` (ext4) and `/boot` `NIXOS_EFI` (vfat), no swap or implicit encryption migration.
- Provision owner-held firmware at `/var/lib/surface-firmware` as documented in `surface.nix`. Keep firmware, private UKIs and SSH credentials out of Git and the public Nix store. The existing SSH authorized keys are deployed privately.

```sh
nix build .#checks.aarch64-linux.surface-boundaries --no-link
sudo nixos-rebuild switch --flake .#surface
```

The regular systemd-boot generation list boots Denali UKIs. Keep the separately archived, verified rescue UKIs and their closures until the new generation passes a real boot and desktop test. No test render overrides belong in this host.
