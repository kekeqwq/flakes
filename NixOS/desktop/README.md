# Shared NixOS desktop / Niri / Catppuccin Mocha

## Host boundaries

`flake.nix` provides the common NixOS base (`nixosModules.default`),
including Home Manager, the shared packages/overlays and the optional desktop.
Every host imports that base; `my.desktop.enable = true` enables the complete
Linux desktop for user **keke**. The hostname is always host-specific.
The desktop is disabled by default. `NixOS/server/` always imports
`System/Common/` for the terminal environment. The desktop switch also enables
`System/Common/desktop/` for shared graphical applications. macOS imports
`macOS/private/`, which imports Common and enables that same shared desktop
layer, without importing Linux modules. See `AGENTS.md` for mandatory boundaries.

The desktop includes Niri, the application/package lists, themes, fonts,
input methods, Emacs, WezTerm, Waybar, wallpaper, audio, Steam, Sunshine,
NetworkManager, Bluetooth, removable-disk support and firmware updates.
Ordinary hosts use greetd/tuigreet to launch `niri-session`. Deck disables greetd
and uses Jovian's Steam/Niri session selector.

`hosts/deck/` owns Jovian, Deck hardware/kernel/storage, hostname/host ID,
resource limits, power-button behavior, display profiles, KMS/VA-API capture,
and its private LAN services. Nothing in `NixOS/desktop/` imports Deck files or
selects behavior by hostname. The retired `hosts/pc/` has been removed; it can
be recovered from Git history if its old hardware details are ever needed.

For a future host, add a `mkNixos { modules = [ ./hosts/new-host ]; }` entry in
`flake.nix`. Its module enables `my.desktop.enable = true` and supplies
only its own hostname, generated hardware/storage configuration, any GPU or
login overrides, and `system.stateVersion`. Optional display profiles go in
`my.desktop.niri.extraConfig = builtins.readFile ./outputs.kdl`. Provision the
user's password/SSH credentials separately; do not commit secrets. No VM or
`mynewvpc` host has been created yet.

## Reproducibility audit (not yet complete)

A successful Nix build does **not** yet mean the whole current home directory
can be reproduced on a fresh host. The following still need separate work:

- `~/.local/share/fonts/` contains manually installed MonoLisa Nasy (normal and
  italic), PingFang, Hiragino Maru Gothic ProN, Source Han Serif SC, and
  仓耳今楷. Only the declared Noto emoji / Nerd Font symbols are in the desktop's
  font package list. Fontconfig and WezTerm request the unmanaged fonts today.
  Audit licensing and package suitable sources before copying them into Nix;
  proprietary font files must not be committed blindly.
- WezTerm downloads `adriankarlen/bar.wezterm` at runtime; it is not pinned in
  this flake. The shared external Emacs dotfiles/Elpaca state are also outside
  this repository's complete control.
- Deck's `/kk/center` web content and Sunshine client state/certificates are
  external data. They remain Deck-only; client trust must be provisioned
  privately rather than placed in the public store.
- OpenList uses mutable state in `/home/keke`; the disabled sing-box service
  refers to an external configuration. Browser/app accounts and other user
  data are not supplied by enabling the desktop.

The wallpaper, Niri base/display profiles, Rofi theme, GTK/Qt themes, Rime
configuration and local Obsidian plugin sources are already tracked or fetched
with fixed hashes. Audit remaining runtime dependencies before the VM test.

## Niri configuration

- `niri/config.kdl` is the main template. Home Manager installs a read-only store symlink at `~/.config/niri/config.kdl` and replaces older hand-edited copies.
- Deck sets `my.desktop.niri.extraConfig` from `hosts/deck/outputs.kdl`, concatenated into the main configuration at build time: there are **no runtime includes**. The old `~/Downloads/deck.kdl` is no longer used and is left untouched as a backup.
- The AVerMedia capture card and PNP(LTM) LCD have EDID-specific profiles. A DP-1 fallback keeps replacement displays (including Ugreen/SAMZHE) at `(0,0)`, 1920×1080 at 60 Hz, so hotplug does not shift Sunshine's input coordinates. The internal LCD uses `transform "normal"` and scale 1.5: the kernel's built-in 270° panel orientation already makes it landscape. Copying the effective transform reported by `niri msg outputs` back into the configuration would rotate it twice.
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
- On the Mac, Moonlight defaults to relative/captured mouse mode. Its historical preference key is `mouseacceleration` (false); this key actually controls absolute remote-desktop mouse mode. Use Ctrl+Option+Shift+Z to release captured input, and click in the stream to capture again.
- LAN Web UI access is allowed; UPnP is disabled. Device trust is provisioned separately, not disabled. Additional clients must be provisioned once before they can connect.

## Deck deployment

```sh
cd ~/Repos/flakes
nix eval .#nixosConfigurations.deck.config.warnings --json
nix build .#checks.x86_64-linux.desktop-boundaries --no-link
sudo nixos-rebuild build --flake .#deck --max-jobs 2 --cores 4
# Only activate after reviewing the successful build:
sudo nixos-rebuild switch --flake .#deck --max-jobs 2 --cores 4
niri validate -c ~/.config/niri/config.kdl
systemctl status home-manager-keke.service
systemctl --user status waybar.service wallpaper.service
niri msg outputs
```

Both system and user failed-unit lists should be empty. Check that exactly one Waybar process exists (it may draw one bar on each active output).

Nix evaluation warnings are distinct from upstream compiler/initrd messages: the pinned kernel advertises firmware for GPUs other than the Deck, and systemd's optional dlopen-library scanner can report unavailable alternative SONAMEs. These messages are not suppressed by this configuration.
