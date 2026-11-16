{ pkgs, pi }:
let
  colors = import ./terminal-colors.nix;
  borderRoles = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = "terminalAccent";
      })
      [
        "border"
        "borderAccent"
        "borderMuted"
        "thinkingOff"
        "thinkingMinimal"
        "thinkingLow"
        "thinkingMedium"
        "thinkingHigh"
        "thinkingXhigh"
        "thinkingMax"
        "bashMode"
      ]
  );
  # Data-only import: do not evaluate the upstream flake or install a Pi package.
  src = pkgs.fetchFromGitHub {
    owner = "otahontas";
    repo = "pi-coding-agent-catppuccin";
    rev = "9a716a630c911a4d29d9520a8d5f87e3b8867f93";
    hash = "sha256-vGLVjYeLeySjNFD6yfpog9Z8YEe5amg8ZngEPBRGs00=";
  };
in
pkgs.runCommand "pi-catppuccin-themes"
  {
    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.jq
    ];
  }
  ''
    mkdir -p "$out/share/doc"
    # Keep upstream content/syntax/panel colors; only unify the editor borders.
    jq --arg accent '${colors.light.accent}' --argjson roles '${builtins.toJSON borderRoles}' \
      '.vars.terminalAccent = $accent | .colors += $roles' \
      ${src}/catppuccin-latte.json > "$out/catppuccin-latte.json"
    jq --arg accent '${colors.dark.accent}' --argjson roles '${builtins.toJSON borderRoles}' \
      '.vars.terminalAccent = $accent | .colors += $roles' \
      ${src}/catppuccin-mocha.json > "$out/catppuccin-mocha.json"
    node ${./pi-catppuccin.test.mjs} "$out" ${pi}/lib/node_modules/@earendil-works/pi-coding-agent
    cp ${src}/README.md ${src}/package.json "$out/share/doc/"
  ''
