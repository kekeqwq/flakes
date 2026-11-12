{ pkgs, ... }:
{
  projectRootFile = "flake.nix";
  package = pkgs.treefmt;

  settings.global.excludes = [
    "flake.lock"
  ];

  programs = {
    nixfmt.enable = true;
    shfmt.enable = true;
    fish_indent.enable = true;
    prettier.enable = true;
  };
}
