{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cjkFont = pkgs.callPackage ../../pkgs/wenkai-mono-terminal { };
in
{
  # ATS may ignore nix-store symlinks in Fonts (as with the private IME font).
  # Copy this reproducible asset, not user state; its Nix source is retained
  # by the activation closure. Full deployments also use fonts.packages.
  myuser.hm.home.activation.installGhosttyCjkFont =
    inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ]
      ''
        target="$HOME/Library/Fonts/KekeCJKTerminal-Regular.ttf"
        run mkdir -p "$HOME/Library/Fonts"
        if [ -L "$target" ]; then run rm "$target"; fi
        if ! cmp -s ${cjkFont}/share/fonts/truetype/KekeCJKTerminal-Regular.ttf "$target"; then
          run ${pkgs.coreutils}/bin/install -m 0644 \
            ${cjkFont}/share/fonts/truetype/KekeCJKTerminal-Regular.ttf "$target"
        fi
      '';

  # Native macOS window chrome and Liquid Glass are private integrations.
  # Keep the shared terminal palette/fonts/shell in System/Common/desktop.
  myuser.hm.programs.ghostty.settings = {
    macos-titlebar-style = "hidden";
    background-blur = "macos-glass-clear";
    background-opacity = lib.mkForce 0.8;
  };
}
