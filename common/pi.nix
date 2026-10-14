{
  config,
  pkgs,
  inputs,
  ...
}:
let
  livePi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.python3 ];
    postInstall = (old.postInstall or "") + ''
      pi_root="$out/lib/node_modules/@earendil-works/pi-coding-agent"
      python ${./pi-live-theme.py} "$pi_root"
      PI_TEST_PACKAGE_DIR="$pi_root" node --test ${./pi-live-theme.test.mjs}
    '';
  });
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
      package = livePi;
      extensions = [
        "${pi-session-kit}/session-kit.ts"
      ];
    };
  };
}
