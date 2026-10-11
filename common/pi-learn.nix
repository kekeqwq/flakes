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

  courseSeed = pkgs.runCommand "python-scraping-course-seed" { } ''
    mkdir -p $out
    cp -R ${./pi-learn/course}/. $out/
  '';

  piTutor = pkgs.writeShellScriptBin "pi-tutor" ''
    set -eu
    course="''${PI_TUTOR_COURSE:-$HOME/Repos/python-scraping-learning}"
    cd "$course"
    exec pi "$@"
  '';
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    myuser.hm = {
      home.packages = [
        piTutor
        pkgs.librsvg
        pkgs.imagemagick
      ];

      programs.pi.coding-agent.rules = ./pi-learn/tutor-rules.md;

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
        ".pi/agent/extensions/learn-session.ts".source = ./pi-learn/learn-session.ts;
        ".pi/agent/extensions/visual-tools".source = visualTools;
        ".pi/agent/extensions/interactive-subagents".source =
          inputs.eero-interactive-subagents + "/pi-extension/subagents";
        ".pi/agent/extensions/web-search".source = webSearch;
        ".pi/agent/extensions/web-fetch".source = webFetch;
        ".pi/agent/skills/teach".source = inputs.eero-learn + "/skills/teach";
        ".pi/agent/skills/visualize".source = inputs.eero-learn + "/skills/visualize";
        ".pi/agent/agents/researcher.md".source = "${learnAgents}/researcher.md";
        ".pi/agent/agents/mermaid-maker.md".source = "${learnAgents}/mermaid-maker.md";
        ".pi/agent/agents/svg-maker.md".source = "${learnAgents}/svg-maker.md";
      };

      home.activation.seedPythonScrapingCourse =
        inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ]
          ''
                    set -eu
                    dest="$HOME/Repos/python-scraping-learning"
                    seed=${courseSeed}
                    mkdir -p "$dest/exercises" "$dest/projects" "$dest/src" "$dest/viz" \
                      "$dest/data/raw" "$dest/data/processed" "$dest/notes/sessions"
                    find "$seed" -type f | while IFS= read -r src; do
                      rel="''${src#"$seed"/}"
                      target="$dest/$rel"
                      if [ ! -e "$target" ]; then
                        mkdir -p "$(dirname "$target")"
                        cp "$src" "$target"
                      fi
                    done
                    # Store copies are mode 0444. The course repo must stay editable.
                    chmod -R u+w "$dest"

                    search_auth="$HOME/.pi/agent/web-search-auth.json"
                    if [ ! -e "$search_auth" ]; then
                      install -m 0600 /dev/null "$search_auth"
                      cat > "$search_auth" <<'JSON'
            {
              "brave_search_api_key": ""
            }
            JSON
                      chmod 0600 "$search_auth"
                    fi

                    obsidian_json="$HOME/Library/Application Support/obsidian/obsidian.json"
                    if [ -f "$obsidian_json" ]; then
                      if [ ! -e "$obsidian_json.bak-pi-learn" ]; then
                        cp -p "$obsidian_json" "$obsidian_json.bak-pi-learn"
                      fi
                      tmp="$(mktemp)"
                      ${pkgs.jq}/bin/jq \
                        --arg path "$dest" \
                        --argjson ts "$(date +%s%3N)" \
                        '
                          .vaults //= {} |
                          if ([.vaults[]?.path] | index($path)) then .
                          else .vaults["python-scraping-learning"] = { path: $path, ts: $ts, open: true }
                          end
                        ' \
                        "$obsidian_json" > "$tmp"
                      mv "$tmp" "$obsidian_json"
                    fi
          '';
    };
  };
}
