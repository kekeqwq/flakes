# Desktop update validation — 2026-11-15

## Immutable updates / compatibility

- Ran `nix flake update` first: nixpkgs `82566dfe`, Jovian `cda4687c`,
  Pi input `06ee2f93`.
- Emacs HEAD `6fcbd85d` (2026-11-14), shared NS/PGTK/nox definitions;
  graphical binaries report `32.0.50`.
- qBittorrent Enhanced stable maintenance HEAD `dce58732`, version `5.2.4.10`.
- Pi registry latest is still `1.5.2`. Multi-account `1.28.1` is current and
  remains **disabled**. xrock's existing pin is already upstream HEAD. The
  unused `weylus-community` overlay was not changed or enabled; the deployed
  Weylus is nixpkgs' `0.11.4-unstable-2026-2-16` / `38a01a8f`.
- **Intentional Deck kernel exception:** updated Jovian's 7.3.1 kernel exceeds
  stable ZFS 2.4.4's compatibility bound. Only Deck's vendor-kernel expression is
  fixed to the previously deployed `7.2.10-valve1` via a revision + NAR hash in
  `hosts/deck/kernel-compat.nix`. Other Jovian updates remain active. No
  `allowBroken`, ignored compatibility check or experimental ZFS is used.

## Real Niri/PAM idle regression (no VM)

`tests/linux-idle-regression.py`: **18/18 passed**, after full-system build and
actual `nixos-rebuild switch`. Five-second test instances use the same swayidle
and screen-lock implementation as production.

- Genuine idle, moving/stopped kernel-uinput mouse, typing/stopped kernel-uinput
  keyboard: correct behavior. Positive short cases securely acquired the lock
  at approximately 5.41 seconds, including daemon readiness overhead.
- mpv window/fullscreen video; Chrome window/fullscreen video, with sound and
  muted: no lock. Real playback position was checked every second (10–11 checks
  per case), and fullscreen state was independently verified.
- Paused/stopped playback and an idle fullscreen static terminal: lock.
- Actual PAM password unlock succeeded; a click and an incorrect password did
  not unlock. The daemon retained its singleton flock; duplicate invocation
  neither replaced the locker nor produced a new secure-acquisition marker.
- Physical **Win+L**: secure lock in **0.28 seconds**, correct-password unlock.
- Started the **actual production service**, injected no input during the wait:
  configured 300 seconds, secure lock at **300.2 seconds**, password unlock.
- Restored production `swayidle.service` with `timeout 300`. It is conditioned on
  both Wayland and `XDG_CURRENT_DESKTOP=niri`, not Deck's Gamescope session.

Fixtures used isolated windows/browser profile and generated local video, not
existing chats, accounts or browser profiles. Passwords were supplied on stdin,
not stored in scripts/reports. Recovery signaling is not counted as an unlock
pass. The initial virtual-keyboard observer was insufficient for physical idle
validation; the final reports use actual kernel uinput devices instead.

## Build / activation / preservation

- Full Deck system and `checks.x86_64-linux.desktop-boundaries` built. The long
  Telegram 7.4.3 compilation completed normally, without interruption.
- Linux `dry-activate` showed no Niri/greetd restart; actual switch succeeded
  without switching the desktop session.
- Compared complete system/Home Manager package names and host settings against
  deployed source `7be690a`: no system package dropped. The only replaced user
  package is Emacs PGTK 31.1 → HEAD; locker/Snipaste packages are additions.
  Filesystems, kernel version, user, hostname/host ID, display outputs and
  Sunshine enable/autostart/firewall settings are unchanged.
- Before switching, stopped qBittorrent/fcitx cleanly and saved their private
  state under root-only `/var/backups/flakes-updates/` on Deck. Downloads were
  excluded, static Rime symlinks were not dereferenced. Backups contain private
  configuration/training state: retain privately, never publish or copy to Nix
  store. Existing credentials, sessions, independent Emacs dotfiles, Rime
  training and firmware/recovery backups were not replaced.
- macOS complete system build and user Home Manager activation succeeded.
  Emacs reports 32.0.50; Pi reports 1.5.2. The **privileged Darwin system switch
  was not performed** (non-interactive sudo unavailable); no unsafe
  `darwin-rebuild check` was attempted. Homebrew cleanup is now non-destructive;
  cask/data removal must be explicitly requested.
- macOS native Pi clipboard getter read an in-memory synthetic PNG
  (`image/png`, 174 bytes); original clipboard was restored unless concurrently
  changed by another application. No screenshot/image file or model request.
  Fixture: `tests/macos-clipboard-image.m`. Snipaste cask installed; first
  macOS screen capture may still require the user's privacy consent.
- Snipaste's Linux AppImage initially failed at runtime despite successful
  build: missing `libgpg-error.so.0`. The package overlay adds it to the AppImage
  FHS closure; the corrected autostart service runs successfully. Niri capture,
  rather than an X11 framebuffer read, is used for native Wayland windows.
- Actual Linux clipboard acceptance: full screen and focused window (1920×1080),
  selected region (294×166), all read as PNG by Pi's own clipboard getter without
  writing screenshot files or sending messages. Physical F3 produced a real
  Snipaste **floating** image window. This caught two additional integration
  gaps: background X11 clients need an in-memory clipboard bridge, and Niri's
  original environment lacks DISPLAY if XWayland starts later. `pin-clipboard`
  handles both; no intermediate image file is used. Reloaded the live Niri
  configuration explicitly, without restarting or switching the session.
  Repeated **17/17 real short-delay/PAM/Win+L cases with corrected Snipaste
  running**: all passed, so its background process does not globally inhibit idle.
- ARM lab full toplevel derivation evaluation passed (not an ARM build).
  macOS treefmt and qBittorrent-policy checks, both IME policy suites, native
  Hammerspoon/Rime lifecycle tests, Linux prefix Lua, real tmux title test,
  prefix lease writer, Pi editor-focus tests and popup geometry tests passed.

## Earlier fresh-install evidence and remaining boundaries

The official-minimal-ISO manual installation reproduction at `7be690a` completed
`nixos-install`, removed the ISO and booted from the installed disk. User testing
succeeded. It exposed EFI mount permissions and first-boot state-parent ownership
issues, fixed in `137c146` / `67dda58`; the user declined another reinstall.
Runtime ownership repair allowed that guest's Home Manager activation to finish.
The requested guest/disk/ISO and dedicated LAN forwarding/alias/cache were later
removed; no VM was recreated for this update.

This is **not** a claim that the entire desktop is fully reproducible: font
licensing/external files remain under the audit documented in
`NixOS/desktop/README.md`; Homebrew casks and private application state are also
separate boundaries. Build success, activation and actual GUI acceptance above
are deliberately distinguished.
