{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem.treefmt =
    { pkgs, ... }:
    {
      projectRootFile = "flake.nix";
      package = pkgs.treefmt;

      settings.global.excludes = [
        "flake.lock"
        "**/.p10k.zsh"
        "**/p10k.zsh"
      ];

      programs = {
        # Nix
        nixfmt.enable = true;

        # Shell / Fish
        shfmt.enable = true;
        fish_indent.enable = true;

        # Web / Docs / Configs (Markdown, JSON, YAML, etc.)
        prettier.enable = true;
      };
    };
}
