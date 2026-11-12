{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    # Keep the app's tested Swift/SDK toolchain pinned independently.
    kikieye.url = "github:kekeqwq/kikieye";
    kikinavmap.url = "github:kekeqwq/KikiNavMap";
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
    spotx-nix = {
      url = "github:SpotX-Official/SpotX-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
    inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
      treefmtFor = forAllSystems (
        system: inputs.treefmt-nix.lib.evalModule pkgsFor.${system} ./treefmt.nix
      );

      mkNixos =
        {
          system ? "x86_64-linux",
          modules ? [ ],
        }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ self.nixosModules.default ] ++ modules;
        };
      mkDarwin =
        {
          system ? "aarch64-darwin",
          modules ? [ ],
        }:
        inputs.darwin.lib.darwinSystem {
          inherit system;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ self.overlays.default ];
          };
          specialArgs = { inherit inputs; };
          modules = [
            inputs.home-manager.darwinModules.home-manager
            inputs.nix-homebrew.darwinModules.nix-homebrew
            ./macOS/private
          ]
          ++ modules;
        };
    in
    {
      overlays.default = lib.composeManyExtensions [
        (import ./pkgs)
        inputs.kikieye.overlays.default
        inputs.kikinavmap.overlays.default
        inputs.spotx-nix.overlays.default
      ];

      nixosModules = {
        default = {
          _module.args.inputs = inputs;
          imports = [
            inputs.home-manager.nixosModules.home-manager
            ./NixOS
          ];
          nixpkgs = {
            config.allowUnfree = true;
            overlays = [ self.overlays.default ];
          };
        };
        desktop = ./NixOS/desktop;
        server = ./NixOS/server;
      };

      nixosConfigurations.deck = mkNixos { modules = [ ./hosts/deck ]; };
      nixosConfigurations.lab = mkNixos {
        system = "aarch64-linux";
        modules = [ ./hosts/lab.nix ];
      };
      darwinConfigurations.mba = mkDarwin { modules = [ ./hosts/mba ]; };

      formatter = forAllSystems (system: treefmtFor.${system}.config.build.wrapper);
      checks = forAllSystems (
        system:
        {
          treefmt = treefmtFor.${system}.config.build.check self;
          qbittorrent-policy =
            pkgsFor.${system}.runCommand "qbittorrent-policy-check"
              { nativeBuildInputs = [ pkgsFor.${system}.python3 ]; }
              ''
                python3 ${./tests/qbittorrent-policy.py} ${./NixOS/server/qbittorrent-policy.py}
                touch "$out"
              '';
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          desktop-boundaries = import ./tests/desktop.nix {
            inherit inputs;
            pkgs = pkgsFor.${system};
            baseModule = self.nixosModules.default;
            deck = self.nixosConfigurations.deck;
          };
        }
      );
    };
}
