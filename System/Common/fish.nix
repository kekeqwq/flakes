{
  config,
  pkgs,
  lib,
  ...
}:
{
  # WezTerm starts the login shell. macOS will not switch to a shell
  # that is missing from /etc/shells.
  programs.fish.enable = true;
  myuser.users.shell = pkgs.fish;
  environment.shells = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [ pkgs.fish ];

  myuser.hm = {
    home.packages = [ pkgs.starship ];

    # Fish 4.3 can freeze old defaults into unmanaged conf.d files. Keep the
    # declared setup, removing only files identified as that auto-migration.
    # Never erase fish_variables, history or user-authored conf.d scripts.
    home.activation.removeFishFrozenDefaults = {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''
        for name in fish_frozen_theme.fish fish_frozen_key_bindings.fish; do
          file="$HOME/.config/fish/conf.d/$name"
          if [ -f "$file" ] && [ ! -L "$file" ] && \
            ${pkgs.gnugrep}/bin/grep -q 'This file was created by fish when upgrading to version 4.3' "$file"; then
            rm -- "$file"
          fi
        done
      '';
    };

    home.sessionVariables = {
      OPENCODEX_API_AUTH_TOKEN = "1";
    };

    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        set fish_greeting # Disable greeting
        starship init fish | source
        alias ls="exa"
      '';
    };
  };
}
