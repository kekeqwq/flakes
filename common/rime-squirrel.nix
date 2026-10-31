{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  rimeIceData = "${pkgs.rime-ice}/share/rime-data";
  squirrelCustom = ./rime/squirrel.custom.yaml;
  defaultCustom = ./rime/default.custom.yaml;
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    myuser.hm.home.activation.syncRimeIce =
      inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ]
        ''
          set -euo pipefail
          src=${rimeIceData}
          dest="$HOME/Library/Rime"
          mkdir -p "$dest"
          # Schema and dictionaries follow nixpkgs. User-trained data stays local:
          # *.userdb, user.yaml, installation.yaml, build/, sync/.
          find "$src" -type f -print0 | while IFS= read -r -d "" f; do
            rel="''${f#"$src"/}"
            case "$rel" in
              AGENTS.md|LICENSE|recipe.yaml|weasel.yaml|build/*) continue ;;
            esac
            target="$dest/$rel"
            mkdir -p "$(dirname "$target")"
            ln -sfn "$f" "$target"
          done
          ln -sfn ${squirrelCustom} "$dest/squirrel.custom.yaml"
          ln -sfn ${defaultCustom} "$dest/default.custom.yaml"
          # nixpkgs ships ice defaults as rime_ice_suggestion.yaml. Drop a
          # leftover default.yaml symlink from the previous git checkout.
          if [ -L "$dest/default.yaml" ]; then
            rm -f "$dest/default.yaml"
          fi
          squirrel="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
          if [ -x "$squirrel" ]; then
            "$squirrel" --reload || true
          fi
        '';
  };
}
