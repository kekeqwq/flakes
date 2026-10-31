# Niri / Catppuccin Mocha

- `niri/config.kdl` is the main template. Home Manager installs a read-only store symlink at `~/.config/niri/config.kdl` and replaces older hand-edited copies.
- The mutable display include is `~/Downloads/<hostname>.kdl` (`deck.kdl` on Deck). **Nix never creates or overwrites this file.** Keep it present before activating the desktop configuration.
- `hosts/deck/outputs.kdl` is a reference/test fixture, not a deployed file. The Deck capture-safe baseline is 1920×1080 at 60 Hz; the built-in panel is rotated 270° at scale 1.5.
- The complete main configuration is validated during the build against the reference outputs, and again before Home Manager activation against the actual mutable display include. Invalid keybindings/includes stop activation before any files are replaced.
- Validate manual display edits with `niri validate -c ~/.config/niri/config.kdl`. Niri watches the included file; no rebuild is required.
- Waybar and swaybg are started **only by user systemd services**. Do not additionally start them from niri, a shell, or XDG autostart. The default niri fallback configuration starts another Waybar if the main configuration cannot load.
- Linux uses fixed Mocha (mauve accent); WezTerm retains native Mocha/Latte appearance switching on macOS/Windows. Emacs remains in the shared external dotfiles checkout.
- `wallpapers/generate.py` regenerates the seeded 4K Mocha mountain wallpaper without third-party dependencies.

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
