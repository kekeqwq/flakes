{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  rimeIceData = "${pkgs.rime-ice}/share/rime-data";
  squirrelCustom = ./rime/squirrel.custom.yaml;
  # WenKai contains monochrome 🀄/🈚️ glyphs. Strip those cmap entries so
  # Squirrel can fall back to Apple Color Emoji without putting emoji first
  # (which stretches Latin metrics).
  lxgwWenkaiIme = pkgs.stdenvNoCC.mkDerivation {
    pname = "lxgw-wenkai-ime";
    version = pkgs.lxgw-wenkai.version;
    src = pkgs.lxgw-wenkai;
    nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.fonttools ])) ];
    dontUnpack = true;
    buildPhase = ''
      python3 ${./rime/strip-wenkai-emoji.py} \
        $src/share/fonts/truetype/LXGWWenKai-Medium.ttf \
        LXGWWenKaiIME-Medium.ttf
    '';
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      cp LXGWWenKaiIME-Medium.ttf $out/share/fonts/truetype/
    '';
  };
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    fonts.packages = [ lxgwWenkaiIme ];
    myuser.hm.home.activation.syncRimeIce =
      inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ]
        ''
          set -euo pipefail
          src=${rimeIceData}
          dest="$HOME/Library/Rime"
          mkdir -p "$dest" "$HOME/Library/Fonts"
          # Copy the IME font; ATS often ignores nix-store symlinks in Fonts.
          cp -f ${lxgwWenkaiIme}/share/fonts/truetype/LXGWWenKaiIME-Medium.ttf \
            "$HOME/Library/Fonts/LXGWWenKaiIME-Medium.ttf"
          # Schema and dictionaries follow nixpkgs. User-trained data stays local:
          # *.userdb, user.yaml, installation.yaml, build/, and sync/.
          find "$src" -type f -print0 | while IFS= read -r -d "" f; do
            rel="''${f#"$src"/}"
            case "$rel" in
              AGENTS.md|LICENSE|recipe.yaml|weasel.yaml|build/*) continue ;;
            esac
            target="$dest/$rel"
            mkdir -p "$(dirname "$target")"
            ln -sfn "$f" "$target"
          done
          # nixpkgs renames ice default.yaml to rime_ice_suggestion.yaml so it
          # can share a data dir with other schemas. Squirrel still needs default.yaml.
          ln -sfn "$src/rime_ice_suggestion.yaml" "$dest/default.yaml"
          # Copy (do not symlink) so mtime is now; Rime skips rebuilds on 1970 store files.
          rm -f "$dest/squirrel.custom.yaml" "$dest/default.custom.yaml"
          cp -f ${squirrelCustom} "$dest/squirrel.custom.yaml"
          squirrel="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
          if [ -x "$squirrel" ]; then
            rm -f "$dest/build/squirrel.yaml"
            "$squirrel" --reload || true
          fi
        '';
  };
}
