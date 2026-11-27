{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  base = builtins.fromJSON (builtins.readFile ./rime/karabiner-base.json);
  shiftRule = {
    description = "Emacs Rime: left Shift alone -> F13; Shift chords unchanged";
    manipulators = [
      {
        type = "basic";
        from.key_code = "left_shift";
        to = [
          {
            key_code = "left_shift";
            lazy = true;
          }
        ];
        to_if_alone = [ { key_code = "f13"; } ];
        parameters."basic.to_if_alone_timeout_milliseconds" = 500;
        conditions = [
          {
            type = "frontmost_application_if";
            bundle_identifiers = [ "^org\\.gnu\\.Emacs$" ];
          }
        ];
      }
    ];
  };
  karabiner = base // {
    profiles = map (
      profile:
      if !(profile.selected or false) then
        profile
      else
        profile
        // {
          complex_modifications = (profile.complex_modifications or { }) // {
            rules = (profile.complex_modifications.rules or [ ]) ++ [ shiftRule ];
          };
        }
    ) base.profiles;
  };
  karabinerSeed = pkgs.writeText "karabiner-seed.json" (builtins.toJSON karabiner);
  seedKarabiner = pkgs.writeShellScript "seed-karabiner" ''
    set -eu
    dir=$1
    target="$dir/karabiner.json"
    seed=${karabinerSeed}
    legacy=$(readlink "$target" || true)
    if [ -L "$target" ]; then
      case "$legacy" in
        ${builtins.storeDir}/*-home-manager-files/.config/karabiner/karabiner.json)
          # Keep the exact config in use, not just the current template.
          if [ -f "$target" ]; then seed="$target"; fi ;;
        *) exit 0 ;;
      esac
    elif [ -e "$target" ]; then
      exit 0
    fi

    umask 077
    mkdir -p "$dir"
    temp=$(mktemp "$dir/.karabiner.json.XXXXXX")
    trap 'rm -f "$temp"' EXIT
    cp "$seed" "$temp"
    chmod 600 "$temp"
    if [ -n "$legacy" ]; then
      if [ "$(readlink "$target" || true)" = "$legacy" ]; then
        mv -f "$temp" "$target"
      fi
    else
      # Install only if Karabiner has not created the file in the meantime.
      ln -h "$temp" "$target" || [ -e "$target" ] || [ -L "$target" ]
    fi
  '';
in
{
  myuser.hm = lib.mkMerge [
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      # Karabiner 17 requires a writable regular file. Migrate before Home
      # Manager removes its old symlink; leave subsequent GUI edits alone.
      home.activation.seedKarabinerConfig =
        inputs.home-manager.lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
          run ${seedKarabiner} "$HOME/.config/karabiner"
        '';
    })
  ];
}
