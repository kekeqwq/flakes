{
  config,
  pkgs,
  inputs,
  ...
}:
let
  pi-session-kit = pkgs.fetchzip {
    url = "https://registry.npmjs.org/pi-session-kit/-/pi-session-kit-0.1.2.tgz";
    hash = "sha256-KCuNAkTw8mEVpyiaCjF+qvihAbxUC/pq9W8LOdNW34A=";
  };
in
{
  nix.settings = {
    extra-substituters = [
      "https://pi.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  myuser.hm = {
    imports = [
      inputs.pi.homeModules.default
    ];
    programs.pi.coding-agent = {
      enable = true;
      extensions = [
        "${pi-session-kit}/session-kit.ts"
      ];
    };
  };
}
