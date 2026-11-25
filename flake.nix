{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    surface = {
      url = "github:kekeqwq/surface.nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chinese-fonts-overlay = {
      url = "github:brsvh/chinese-fonts-overlay/a14d554299d1c8a5f4329a215d4d6217d99bf307";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
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
        inputs.chinese-fonts-overlay.overlays.default
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
        modules = [ ./hosts/lab ];
      };
      # Same private lab file. Only the NixOS system differs.
      nixosConfigurations.lab-x86 = mkNixos {
        system = "x86_64-linux";
        modules = [ ./hosts/lab ];
      };
      nixosConfigurations.secret-lab = mkNixos { modules = [ ./hosts/secret-lab ]; };
      nixosConfigurations.surface = mkNixos {
        system = "aarch64-linux";
        modules = [ ./hosts/surface ];
      };
      darwinConfigurations.mba = mkDarwin { modules = [ ./hosts/mba ]; };

      formatter = forAllSystems (system: treefmtFor.${system}.config.build.wrapper);
      checks = forAllSystems (
        system:
        {
          treefmt = treefmtFor.${system}.config.build.check self;
          desktop-fonts = import ./tests/fonts.nix {
            pkgs =
              {
                aarch64-darwin = self.darwinConfigurations.mba.pkgs;
                aarch64-linux = self.nixosConfigurations.lab.pkgs;
                x86_64-linux = self.nixosConfigurations.deck.pkgs;
              }
              .${system};
          };
          pi-native-theme = import ./System/Common/pi-native-theme.nix {
            pkgs = pkgsFor.${system};
            raw = inputs.pi.packages.${system}.coding-agent;
          };
          pi-catppuccin = import ./System/Common/pi-catppuccin.nix {
            pkgs = pkgsFor.${system};
            pi = self.checks.${system}.pi-native-theme;
          };
          pi-theme-cli = import ./tests/pi-theme-cli.nix {
            pkgs = pkgsFor.${system};
            pi = self.checks.${system}.pi-native-theme;
            themes = self.checks.${system}.pi-catppuccin;
          };
          tmux-foreground = import ./tests/tmux-foreground.nix { pkgs = pkgsFor.${system}; };
          zoxide-fish = import ./tests/zoxide-fish.nix { pkgs = pkgsFor.${system}; };
          wallpaper-selection =
            let
              pkgs = pkgsFor.${system};
              pack = import ./NixOS/desktop/wallpaper-initrd.nix { inherit pkgs; };
              default = import ./NixOS/desktop/wallpaper.nix;
            in
            pkgs.runCommand "wallpaper-selection-check"
              {
                nativeBuildInputs = [
                  (pkgs.python3.withPackages (ps: [ ps.pillow ]))
                  pkgs.cpio
                ];
              }
              ''
                python3 -I ${./tests/wallpaper.py} ${./NixOS/desktop/wallpaper-select.py}
                ${lib.getExe pack} ${default} "$PWD/wallpaper.cpio"
                if ${lib.getExe pack} "$PWD/missing.png" "$PWD/wallpaper.cpio"; then exit 1; fi
                mkdir extracted
                (cd extracted; cpio --quiet -id --no-preserve-owner < ../wallpaper.cpio)
                cmp ${default} extracted/var/lib/keke-plymouth/wallpaper.png
                test "$(find extracted -type f | wc -l)" -eq 1
                touch "$out"
              '';
          qbittorrent-policy =
            pkgsFor.${system}.runCommand "qbittorrent-policy-check"
              { nativeBuildInputs = [ pkgsFor.${system}.python3 ]; }
              ''
                python3 ${./tests/qbittorrent-policy.py} ${./NixOS/server/qbittorrent-policy.py}
                touch "$out"
              '';
        }
        // lib.optionalAttrs (system == "aarch64-darwin") {
          tmux-theme = import ./tests/tmux-theme.nix {
            pkgs = pkgsFor.${system};
            darwin = self.darwinConfigurations.mba;
          };
          sudo-touchid = import ./tests/macos-sudo-auth.nix {
            pkgs = pkgsFor.${system};
            darwin = self.darwinConfigurations.mba;
          };
        }
        // lib.optionalAttrs (system == "aarch64-linux") {
          surface-boundaries = import ./tests/surface.nix {
            pkgs = pkgsFor.${system};
            surface = self.nixosConfigurations.surface;
          };
          package-boundaries = import ./tests/aarch64-linux.nix {
            inherit inputs;
            baseModule = self.nixosModules.default;
            desktop = self.nixosConfigurations.lab;
            pkgs = pkgsFor.${system};
          };
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          niri-session = import ./tests/niri-session.nix { pkgs = pkgsFor.${system}; };
          secret-lab-boundaries = import ./tests/secret-lab.nix {
            pkgs = pkgsFor.${system};
            secretLab = self.nixosConfigurations.secret-lab;
            lab = self.nixosConfigurations.lab-x86;
          };
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
