{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    # Eero Alvar's current learning system. These repos have no flake.nix.
    # Revisions are the verified HEADs of 2026-08-25; flake.lock pins them.
    eero-learn = {
      url = "github:amosblomqvist/learn/7cfd8942f82ab9476e63572387e1fe9bcea5082c";
      flake = false;
    };
    eero-pi-config = {
      url = "github:amosblomqvist/pi-config/f82da563ab05d66729492d64c7ed4e96db3663f3";
      flake = false;
    };
    eero-interactive-subagents = {
      url = "github:amosblomqvist/pi-interactive-subagents/c3e8b53c0754ae5ccc19fdab5a7481ec039bc2f7";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      imports = [ ./flake-parts ];
    };
}
