{
  config,
  pkgs,
  inputs,
  ...
}:
let
  piPackage = import ./pi-native-theme.nix {
    inherit pkgs;
    raw = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;
  };
  catppuccinThemes = import ./pi-catppuccin.nix {
    inherit pkgs;
    pi = piPackage;
  };
  # Discoverable extension, not a wrapper --extension flag: child Pi processes
  # launched with --no-extensions must keep their restricted loadout. This
  # package publishes loopback account routes for those children itself.
  # Reports only editor focus for the input-method switcher; no prompt text.
  # Shared by macOS (Hammerspoon) and Linux (fcitx5 watcher).
  inputMethod = pkgs.runCommand "pi-input-method" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
    node ${./input-method/pi-ime.test.mjs} ${./input-method/pi-ime.ts}
    mkdir -p "$out"
    cp ${./input-method/pi-ime.ts} "$out/input-method.ts"
  '';
  webSearch = pkgs.fetchzip {
    url = "https://registry.npmjs.org/pi-web-search/-/pi-web-search-1.7.0.tgz";
    hash = "sha256-8HgICeK/HB07pLb+KRpB6kxIRW9Vc8s0VcJmtutuKr8=";
  };
  codexGoal = pkgs.fetchzip {
    url = "https://registry.npmjs.org/pi-codex-goal/-/pi-codex-goal-0.7.11.tgz";
    hash = "sha256-VLtDvSZ/xeR7pyTriilFvCos7NPh00jBRDlquqqrlKg=";
  };
  multiAccountSrc = pkgs.fetchzip {
    url = "https://registry.npmjs.org/pi-multi-account/-/pi-multi-account-1.28.1.tgz";
    hash = "sha256-TUjGG5hi83voCw/pek2NzvD/z4zKbChl4Rbv16MDDFg=";
  };
  multiAccountNpmSrc = pkgs.runCommand "pi-multi-account-npm-src" { } ''
    mkdir $out
    cp ${multiAccountSrc}/package.json $out/package.json
    cp ${./pi-multi-account/package-lock.json} $out/package-lock.json
  '';
  multiAccountNpmDeps = pkgs.fetchNpmDeps {
    src = multiAccountNpmSrc;
    hash = "sha256-qhrOjH2KfaHYlLJ4uR68HhJyiIw514we/4iveoox18E=";
  };
  multiAccount = pkgs.stdenv.mkDerivation {
    pname = "pi-multi-account";
    version = "1.28.1";
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

  myuser.hm = { config, ... }: {
    imports = [
      inputs.pi.homeModules.default
    ];
    # Prefer only this Pi wrapper in new shells (no unrelated PATH shadowing).
    # useUserPackages otherwise leaves a narrow HM deployment on the old system
    # profile's Pi until a full system switch. The local link also serves shells
    # that were already running before this activation.
    home.sessionPath = [ "${config.programs.pi.coding-agent.finalPackage}/bin" ];
    home.file.".local/bin/pi".source = "${config.programs.pi.coding-agent.finalPackage}/bin/pi";
    # home.file.".pi/agent/extensions/pi-multi-account".source = multiAccount;
    home.file.".pi/agent/extensions/input-method.ts".source = "${inputMethod}/input-method.ts";
    # The published entry point is src/index.ts; Pi supplies all runtime imports.
    home.file.".pi/agent/extensions/pi-web-search".source = "${webSearch}/src";
    home.file.".pi/agent/extensions/pi-codex-goal".source = codexGoal;
    home.file.".pi/agent/prompts/create-goal.md".source = "${codexGoal}/prompts/create-goal.md";
    home.file.".pi/agent/themes/catppuccin-latte.json".source =
      "${catppuccinThemes}/catppuccin-latte.json";
    home.file.".pi/agent/themes/catppuccin-mocha.json".source =
      "${catppuccinThemes}/catppuccin-mocha.json";
    programs.pi.coding-agent = {
      enable = true;
      # Ghostty/tmux support native appearance notifications (mode 2031).
      # No WezTerm-specific periodic palette-query patch is needed.
      package = piPackage;
      # Upstream merges these public display preferences into mutable settings.json;
      # accounts, models, extensions and other private settings remain untouched.
      settings = {
        theme = "catppuccin-latte/catppuccin-mocha";
        # Native cursor inherits Ghostty's color/shape across appearance changes.
        showHardwareCursor = true;
      };
      extensions = [ ];
    };
  };
}
