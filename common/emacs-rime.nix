{ pkgs, lib, inputs, ... }:
let
  # Only the C module is exported. Elpaca manages the Lisp frontend.
  native = pkgs.runCommand "emacs-rime-native" { } ''
    mkdir -p "$out"
    cp ${pkgs.emacsPackages.rime}/share/emacs/site-lisp/elpa/rime-*/librime-emacs${pkgs.stdenv.hostPlatform.extensions.sharedLibrary} "$out/"
  '';
  base = builtins.fromJSON (builtins.readFile ./rime/karabiner-base.json);
  shiftRule = {
    description = "Emacs Rime: left Shift alone -> F13; Shift chords unchanged";
    manipulators = [{
      type = "basic";
      from.key_code = "left_shift";
      to = [{ key_code = "left_shift"; lazy = true; }];
      to_if_alone = [{ key_code = "f13"; }];
      parameters."basic.to_if_alone_timeout_milliseconds" = 500;
      conditions = [{
        type = "frontmost_application_if";
        bundle_identifiers = [ "^org\\.gnu\\.Emacs$" ];
      }];
    }];
  };
  karabiner = base // {
    profiles = map (profile:
      if !(profile.selected or false) then profile else
      profile // {
        complex_modifications = (profile.complex_modifications or { }) // {
          rules = (profile.complex_modifications.rules or [ ]) ++ [ shiftRule ];
        };
      }) base.profiles;
  };
in
{
  environment.systemPackages = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.macism ];
  myuser.hm = lib.mkMerge [
    { home.file.".local/share/emacs-rime-native".source = native; }
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    xdg.configFile."karabiner/karabiner.json" = {
      text = builtins.toJSON karabiner;
      force = true;
    };
    home.activation.backupKarabinerBeforeNix =
      inputs.home-manager.lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
        target="$HOME/.config/karabiner/karabiner.json"
        if [ -f "$target" ] && [ ! -L "$target" ]; then
          cp -p "$target" "$target.before-nix-$(date +%Y%m%d-%H%M%S)"
        fi
      '';
    })
  ];
}
