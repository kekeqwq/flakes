{ config, pkgs, ... }:
{
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
        alias sc="screen /dev/cu.usbmodem5B162124901 9600"

        function switchscreen
            # Runtime toggle only: never mutate the Nix-managed configuration.
            set -l outputs (niri msg --json outputs)
            or return 1
            if not printf '%s' "$outputs" | ${pkgs.jq}/bin/jq -e 'has("eDP-1")' >/dev/null
                echo "eDP-1 not found"
                return 1
            end
            if printf '%s' "$outputs" | ${pkgs.jq}/bin/jq -e '."eDP-1".current_mode != null' >/dev/null
                niri msg output eDP-1 off
            else
                niri msg output eDP-1 on
            end
        end
      '';
    };
  };
}
