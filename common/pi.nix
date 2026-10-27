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
  # Discoverable extension, not a wrapper --extension flag: child Pi processes
  # launched with --no-extensions must keep their restricted loadout. This
  # package publishes loopback account routes for those children itself.
  multiAccountSrc = pkgs.fetchzip {
    url = "https://registry.npmjs.org/pi-multi-account/-/pi-multi-account-1.26.0.tgz";
    hash = "sha256-+WAfwuqRK23BQF2xraasEPGbyrsB72ysxpAYz4ezLXg=";
  };
  multiAccountNpmSrc = pkgs.runCommand "pi-multi-account-npm-src" { } ''
    mkdir $out
    cp ${multiAccountSrc}/package.json $out/package.json
    cp ${./pi-multi-account/package-lock.json} $out/package-lock.json
  '';
  multiAccountNpmDeps = pkgs.fetchNpmDeps {
    src = multiAccountNpmSrc;
    hash = "sha256-bk80QzBagPIkXsceer1CDvC4D6um/W/93cOpx3Zil4I=";
  };
  multiAccount = pkgs.stdenv.mkDerivation {
    pname = "pi-multi-account";
    version = "1.26.0";
    src = multiAccountSrc;
    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.npmHooks.npmConfigHook
    ];
    npmDeps = multiAccountNpmDeps;
    npmFlags = [ "--ignore-scripts" ];
    postPatch = ''
      cp ${./pi-multi-account/package-lock.json} package-lock.json
    '';
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -a . $out/
    '';
  };
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
    home.file.".pi/agent/extensions/pi-multi-account".source = multiAccount;
    programs.pi.coding-agent = {
      enable = true;
      package = livePi;
      extensions = [
        "${pi-session-kit}/session-kit.ts"
      ];
    };
  };
}
