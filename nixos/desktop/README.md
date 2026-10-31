# Niri / Catppuccin Mocha

- `niri/config.kdl` is the main template. Home Manager installs a read-only store symlink at `~/.config/niri/config.kdl` and replaces older hand-edited copies.
- `hosts/deck/outputs.kdl` is concatenated into the main configuration at build time: there are **no runtime includes**. The old `~/Downloads/deck.kdl` is no longer used and is left untouched as a backup.
- The AVerMedia capture card and PNP(LTM) LCD are matched by EDID identity because both use DP-1. Both use 1920×1080 at 60 Hz. The internal LCD uses `transform "normal"` and scale 1.5: the kernel's built-in 270° panel orientation already makes it landscape. Copying the effective transform reported by `niri msg outputs` back into the configuration would rotate it twice.
- The exact complete installed configuration is validated during the build and again before Home Manager activation. Invalid keybindings stop activation before files are replaced.
- Change permanent display settings in `hosts/deck/outputs.kdl` and rebuild. `switchscreen` only toggles eDP-1 at runtime through niri IPC; it never edits the managed configuration.
- Waybar and swaybg are started **only by user systemd services**. Do not additionally start them from niri, a shell, or XDG autostart. The default niri fallback configuration starts another Waybar if the main configuration cannot load.
- Icons use Papirus-Dark with the official Catppuccin Mocha/Mauve folder adaptation. Waybar explicitly overrides qBittorrent/Sunshine pixmaps with Papirus panel glyphs; Telegram keeps its dynamic attention/mute icons. Sunshine uses Papirus's screen-recording glyph because the theme has no dedicated Sunshine icon.
- Linux uses fixed Mocha (mauve accent); WezTerm retains native Mocha/Latte appearance switching on macOS/Windows. Emacs remains in the shared external dotfiles checkout.
- `wallpapers/generate.py` regenerates the seeded 4K Mocha mountain wallpaper without third-party dependencies.

## Sunshine on Deck

- Uses KMS capture of DP-1 with VA-API encoding, not the desktop portal. No screen-selection dialog is needed.
- Moonlight device pairing and portal screen consent are independent. The official client requires a pinned server certificate, so disabling pairing only on Sunshine is insufficient.
- Trusted clients remain in the private `~/.config/sunshine/sunshine_state.json`; certificates and keys must never be committed to Nix/Git. Exactly one enabled record per client certificate is required by the pinned Sunshine version.
- LAN Web UI access is allowed; UPnP is disabled. Device trust is provisioned separately, not disabled. Additional clients must be provisioned once before they can connect.

## Deck deployment

```sh
cd ~/Repos/flakes
nix eval .#nixosConfigurations.deck.config.warnings --json
sudo nixos-rebuild switch --flake .#deck --max-jobs 2 --cores 4
niri validate -c ~/.config/niri/config.kdl
systemctl status home-manager-keke.service
systemctl --user status waybar.service wallpaper.service
niri msg outputs
```

Both system and user failed-unit lists should be empty. Check that exactly one Waybar process exists (it may draw one bar on each active output).

Nix evaluation warnings are distinct from upstream compiler/initrd messages: the pinned kernel advertises firmware for GPUs other than the Deck, and systemd's optional dlopen-library scanner can report unavailable alternative SONAMEs. These messages are not suppressed by this configuration.
