{ lib, pkgs, ... }:
{
  myuser.hm.programs.emacs = lib.mkMerge [
    {
      package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs-head else pkgs.emacs-pgtk;
      # ghostel is shared desktop Emacs functionality (Ghostty terminal
      # integration); both platforms get it from the same package set.
      extraPackages = epkgs: [ epkgs.ghostel ];
    }
    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      overrides = _final: prev: {
        emacsWithPackages =
          packages:
          (prev.emacsWithPackages packages).overrideAttrs (old: {
            deps = old.deps.overrideAttrs (depsOld: {
              # Emacs master also displays leftover native compilation arguments.
              buildCommand =
                builtins.replaceStrings
                  [ "-f batch-native-compile" ]
                  [
                    "--eval \"(advice-add 'batch-native-compile :after (lambda (&rest _) (setq command-line-args-left nil)))\" -f batch-native-compile"
                  ]
                  depsOld.buildCommand;
            });
          });
        ghostel = prev.ghostel.overrideAttrs (old: {
          # melpa2nix must consume its arguments; otherwise Emacs master
          # treats them as files and tries to display windows in batch mode.
          preBuild = (old.preBuild or "") + ''
            cp "$melpa2nix" "$NIX_BUILD_TOP/melpa2nix-fixed.el"
            cp "$elpa2nix" "$NIX_BUILD_TOP/elpa2nix-fixed.el"
            chmod +w "$NIX_BUILD_TOP/"{melpa2nix,elpa2nix}-fixed.el"
            printf '\n(advice-add (quote melpa2nix-build-package) :after (lambda (&rest _) (setq command-line-args-left nil)))\n' \
              >> "$NIX_BUILD_TOP/melpa2nix-fixed.el"
            printf '\n(advice-add (quote elpa2nix-install-package) :after (lambda (&rest _) (setq command-line-args-left nil)))\n' \
              >> "$NIX_BUILD_TOP/elpa2nix-fixed.el"
            melpa2nix="$NIX_BUILD_TOP/melpa2nix-fixed.el"
            elpa2nix="$NIX_BUILD_TOP/elpa2nix-fixed.el"
          '';
        });
      };
    })
  ];
}
