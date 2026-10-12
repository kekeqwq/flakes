{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # mkIf still forces this attrset on Linux eval, so every derivation here must
  # evaluate on both darwin and linux. They are only installed on Darwin.
  webSearch = pkgs.runCommand "pi-web-search" { } ''
    mkdir -p $out
    cp ${./pi-learn/web-search}/index.ts $out/index.ts
    cp ${./pi-learn/web-search}/auth.example.json $out/auth.example.json
  '';
  webFetchSrc = inputs.eero-pi-config + "/extensions/web-fetch";
  webFetch = pkgs.stdenv.mkDerivation {
    pname = "pi-web-fetch";
    version = "0.0.0";
    src = webFetchSrc;
    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.npmHooks.npmConfigHook
    ];
    npmDeps = pkgs.fetchNpmDeps {
      src = webFetchSrc;
      hash = "sha256-Rbdj6jd25Urxr1wJj1Vl7mefv1IKu5zQhHgt6dOEqaU=";
    };
    npmFlags = [ "--ignore-scripts" ];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -a index.ts package.json package-lock.json node_modules $out/
    '';
  };

  visualTools = pkgs.runCommand "eero-visual-tools" { } ''
    mkdir -p $out/tools $out/node_modules/.bin
    cp ${inputs.eero-learn}/extensions/visual-tools/index.ts $out/index.ts
    cp ${inputs.eero-learn}/extensions/visual-tools/tools/*.ts $out/tools/
    ln -s ${pkgs.mermaid-cli}/bin/mmdc $out/node_modules/.bin/mmdc
  '';

  learnAgents = pkgs.runCommand "eero-learn-agents" { } ''
    mkdir -p $out
    for f in researcher.md mermaid-maker.md svg-maker.md; do
      # Upstream pins OpenRouter/Anthropic models this account cannot use.
      # Omitting model: makes subagents inherit the parent Pi model.
      ${pkgs.gnused}/bin/sed '/^model: /d' ${inputs.eero-learn}/agents/$f > $out/$f
    done
  '';

  # The upstream PDF skill assumes it can pip-install into its own directory.
  # A Nix store path is read-only; bundle the scripts with a Nix Python instead.
  pdfPython = pkgs.python3.withPackages (ps: [ ps.pymupdf ]);
  pdfReader = pkgs.runCommand "pi-pdf-reader" { } ''
    mkdir -p $out/scripts
    cp ${inputs.eero-pi-config}/skills/pdf-reader/scripts/*.py $out/scripts/
    ${pkgs.gnused}/bin/sed 's|@PDF_PYTHON@|${pdfPython}/bin/python3|g' \
      ${./pi-learn/pdf-reader/SKILL.md} > $out/SKILL.md
  '';
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    myuser.hm = {
      home.packages = [
        pkgs.librsvg
        pkgs.imagemagick
      ];

      # Discoverable agent-dir resources, not wrapper --extension flags.
      # interactive-subagents launches child `pi` processes with --no-extensions;
      # flags injected by the pi.nix wrapper would leak into those sandboxes.
      # web-search/web-fetch must live at these exact paths: the subagent
      # extension resolves them from PI_CODING_AGENT_DIR/extensions.
      home.file = {
        ".pi/agent/extensions/ask-user-question.ts".source =
          inputs.eero-learn + "/extensions/ask-user-question.ts";
        ".pi/agent/extensions/quiz.ts".source = inputs.eero-learn + "/extensions/quiz.ts";
        ".pi/agent/extensions/md-log.ts".source = inputs.eero-learn + "/extensions/md-log.ts";
        ".pi/agent/extensions/visual-tools".source = visualTools;
        ".pi/agent/extensions/interactive-subagents".source =
          inputs.eero-interactive-subagents + "/pi-extension/subagents";
        ".pi/agent/extensions/web-search".source = webSearch;
        ".pi/agent/extensions/web-fetch".source = webFetch;
        ".pi/agent/skills/teach".source = inputs.eero-learn + "/skills/teach";
        ".pi/agent/skills/visualize".source = inputs.eero-learn + "/skills/visualize";
        ".pi/agent/skills/pdf-reader".source = pdfReader;
        ".pi/agent/agents/researcher.md".source = "${learnAgents}/researcher.md";
        ".pi/agent/agents/mermaid-maker.md".source = "${learnAgents}/mermaid-maker.md";
        ".pi/agent/agents/svg-maker.md".source = "${learnAgents}/svg-maker.md";
      };

    };
  };
}
