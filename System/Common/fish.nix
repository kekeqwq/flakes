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
