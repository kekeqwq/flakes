{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem.treefmt =
    { pkgs, ... }:
    {
      projectRootFile = "flake.nix";
      # formatter for nix
      package = pkgs.treefmt2;
      programs.nixfmt.enable = true;
    };
}
