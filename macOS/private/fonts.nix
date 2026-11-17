{ pkgs, inputs, ... }:
let
  cjk = pkgs.callPackage ../../pkgs/tsanger-jinkai { };
  latin = pkgs.callPackage ../../pkgs/monolisa-nasy { };
in
{
  # CoreText/ATS may ignore nix-store font symlinks. Copy only managed assets;
  # leave all existing user/legacy font bodies untouched until requested cleanup.
  myuser.hm.home.activation.installManagedDesktopFonts =
    inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ]
      ''
        run mkdir -p "$HOME/Library/Fonts"
        for source in ${cjk}/share/fonts/truetype/*.ttf ${latin}/share/fonts/truetype/*.ttf; do
          target="$HOME/Library/Fonts/$(basename "$source")"
          if [ -L "$target" ]; then run rm "$target"; fi
          if ! cmp -s "$source" "$target"; then
            run ${pkgs.coreutils}/bin/install -m 0644 "$source" "$target"
          fi
        done
      '';
}
