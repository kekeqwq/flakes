{ ... }:
{
  # Shared graphical programs only. Merely importing Common must not install
  # these on a headless Linux server.
  imports =
    map
      (
        path:
        {
          config,
          lib,
          pkgs,
          inputs,
          ...
        }@args:
        {
          _file = toString path;
          config = lib.mkIf config.my.desktop.enable (import path args);
        }
      )
      [
        ./fonts.nix
        ./apps.nix
        ./emacs.nix
        ./emacs-rime.nix
        ./wezterm.nix
      ];
}
