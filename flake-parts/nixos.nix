{
  self,
  inputs,
  withSystem,
  ...
}:

let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    config.permittedInsecurePackages = [ "electron-25.9.0" ];
    overlays = [ self.overlays.default ];
  };
  mkNixos =
    {
      system ? "x86_64-linux",
      modules ? [ ],
      desktop ? true,
      p ? pkgs,
    }:
    withSystem system (
      { pkgs, system, ... }:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          pkgs = p;
        };
        modules = [
          inputs.home-manager.nixosModules.home-manager
          ../common
          ../nixos/pkgs.nix
        ] ++ pkgs.lib.optionals desktop [ ../nixos/desktop ] ++ modules;
      }
    );
in
{
  flake.nixosConfigurations = {
    pc = mkNixos { modules = [ ../hosts/pc ]; };
    deck = mkNixos {
      modules = [ ../hosts/deck ];
      p = (pkgs.extend (import "${inputs.jovian}/overlay.nix"));
    };
  };
}
