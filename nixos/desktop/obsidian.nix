{ pkgs, ... }:

let
  # Official theme: defaults to Latte in light mode and Mocha in dark mode.
  # Pin both files to one commit; no extension registry or runtime downloads.
  revision = "7ebbd577464d6ef8a18cb02811983bee623f30d6";
  themeCss = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/catppuccin/obsidian/${revision}/theme.css";
    hash = "sha256-bBMwcArgB39cedlQqQF5pC53eHIp3hJ25cvloEjlcu0=";
  };
  themeManifest = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/catppuccin/obsidian/${revision}/manifest.json";
    hash = "sha256-tjVkGOZ7922GJApDRi5kE7eq/j5x8/7ljoVEJR7iVxI=";
  };
  # HM/CSS cannot change creation-time NSWindow transparency or vibrancy.
  # Patch the pinned macOS app, not a runtime plugin or window-wide opacity.
  obsidianTransparent = pkgs.obsidian.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [
      pkgs.asar
      pkgs.python3
      pkgs.rcodesign
    ];
    postInstall = (old.postInstall or "") + ''
      resources="$out/Applications/Obsidian.app/Contents/Resources"
      asar extract "$resources/obsidian.asar" obsidian-src
      substituteInPlace obsidian-src/main.js \
        --replace-fail 'backgroundColor:"#00000000"' 'transparent:!0,backgroundColor:"#00000000"' \
        --replace-fail 'Y[t]=f;' 'f.setWindowButtonVisibility(!1),Y[t]=f;'
      substituteInPlace obsidian-src/app.js \
        --replace-fail 't?e.setVibrancy("sidebar"):e.setVibrancy(null)' 'e.setVibrancy(null)'
      asar pack obsidian-src "$resources/obsidian.asar"

      # Cached self-updates must not bypass the Nix-patched app.
      asar extract "$resources/app.asar" launcher-src
      substituteInPlace launcher-src/main.js \
        --replace-fail 'if (updatedAsarPath) {' 'if (false && updatedAsarPath) {'
      asar pack launcher-src "$resources/app.asar" \
        --unpack-dir '{node_modules/btime,node_modules/get-fonts}'

      # Electron checks ASAR header hashes; refresh them before ad-hoc signing.
      python3 - "$out/Applications/Obsidian.app" <<'PY'
      import hashlib, pathlib, plistlib, struct, sys
      app = pathlib.Path(sys.argv[1])
      plist = app / "Contents/Info.plist"
      info = plistlib.loads(plist.read_bytes())
      for name in ("app", "obsidian"):
          data = (app / f"Contents/Resources/{name}.asar").read_bytes()
          length = struct.unpack_from("<I", data, 12)[0]
          info["ElectronAsarIntegrity"][f"Resources/{name}.asar"]["hash"] = hashlib.sha256(data[16:16+length]).hexdigest()
      plist.write_bytes(plistlib.dumps(info))
      PY
    '';
    # Signing must run after fixup/strip and symlink normalization.
    dontStrip = true;
    postFixup = (old.postFixup or "") + ''
      rcodesign sign "$out/Applications/Obsidian.app"
    '';
  });
  selectionIndexManifest = pkgs.writeText "selection-index-manifest.json" (
    builtins.toJSON {
      id = "selection-index";
      name = "Selection Index";
      version = "1.0.0";
      minAppVersion = "1.5.0";
      description = "Append selected text as a precise source link to another note, without moving the original.";
      author = "Local Nix configuration";
      isDesktopOnly = false;
    }
  );
  selectionIndex =
    pkgs.runCommand "obsidian-selection-index-1.0.0"
      {
        nativeBuildInputs = [
          pkgs.nodejs
          pkgs.esbuild
        ];
        passthru.manifestId = "selection-index";
      }
      ''
        node --test ${./obsidian-index}/anchors.test.js
        mkdir -p "$out"
        esbuild ${./obsidian-index}/main.js --bundle --platform=browser \
          --format=cjs --external:obsidian --outfile="$out/main.js"
        cp ${selectionIndexManifest} "$out/manifest.json"
      '';
  catppuccin =
    pkgs.runCommand "obsidian-catppuccin-0.4.51"
      {
        # Lets HM determine the directory/name without import-from-derivation.
        passthru.manifestId = "Catppuccin";
      }
      ''
        mkdir -p "$out"
        ln -s ${themeCss} "$out/theme.css"
        ln -s ${themeManifest} "$out/manifest.json"
      '';
in
{
  myuser.hm.programs.obsidian = {
    enable = true;
    package = if pkgs.stdenv.hostPlatform.isDarwin then obsidianTransparent else pkgs.obsidian;
    vaults.learning.target = "Learning";
    defaultSettings = {
      appearance = {
        theme = "system";
        translucency = pkgs.stdenv.hostPlatform.isDarwin;
        showRibbon = false;
        showViewHeader = false;
        nativeMenus = true;
        baseFontSize = 16;
        textFontFamily = "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif";
        interfaceFontFamily = "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif";
        monospaceFontFamily = "MonoLisa Nasy, SFMono-Regular, monospace";
      };
      themes = [ catppuccin ];
      communityPlugins = [ selectionIndex ];
      hotkeys."selection-index:append-selection" = [
        {
          modifiers = [
            "Mod"
            "Shift"
          ];
          key = "E";
        }
      ];
      # Keep core plugins, editor settings and workspace state mutable.
      # HM generates appearance.json and enabledCssSnippets itself.
      cssSnippets = [
        {
          name = "catppuccin-minimal";
          text = ''
            /* Never use window/element opacity: only the background has alpha. */
            body {
              --ctp-accent: var(--ctp-lavender);
              --tab-outline-width: 0px;
              --tab-curve: 0px;
              --tab-radius-active: 6px;
              --tab-container-background: transparent;
              --tab-background-active: rgba(var(--ctp-surface0), 0.35);
              --titlebar-background: transparent;
              --titlebar-background-focused: transparent;
              --divider-color: rgba(var(--ctp-overlay0), 0.16);
              --background-modifier-border: rgba(var(--ctp-overlay0), 0.2);
              --file-line-width: 760px;
              --line-height-normal: 1.65;
              --p-spacing: 1em;
              --h1-color: rgb(var(--ctp-lavender));
              --h2-color: rgb(var(--ctp-blue));
              --h3-color: rgb(var(--ctp-teal));
              --h4-color: rgb(var(--ctp-green));
              --h5-color: rgb(var(--ctp-yellow));
              --h6-color: rgb(var(--ctp-peach));
              --bold-color: rgb(var(--ctp-text));
              --italic-color: rgb(var(--ctp-mauve));
              --text-faint: rgb(var(--ctp-overlay1));
              --code-background: rgba(var(--ctp-surface0), 0.45);
              --scrollbar-bg: transparent;
              --scrollbar-thumb-bg: rgba(var(--ctp-overlay0), 0.2);
              --scrollbar-active-thumb-bg: rgba(var(--ctp-overlay1), 0.4);
            }

            /* No desktop title/tab bar. Sidebar commands and tab shortcuts
               still work; sidebar content itself is not hidden. */
            body:not(.is-mobile) :is(
              .titlebar, .workspace-tab-header-container,
              .sidebar-toggle-button, .status-bar
            ) {
              display: none !important;
            }
            /* An invisible 8px strip keeps the frameless window draggable
               without making note text or images into drag targets. */
            body:not(.is-mobile):not(.is-fullscreen) .app-container::before {
              content: "";
              position: absolute;
              inset: 0 0 auto;
              height: 8px;
              z-index: 100;
              -webkit-app-region: drag;
            }
            .markdown-rendered pre,
            .markdown-rendered code {
              border-radius: 6px;
            }
            .markdown-rendered blockquote {
              border-inline-start: 2px solid rgb(var(--ctp-lavender));
              background: rgba(var(--ctp-surface0), 0.18);
            }

            /* One 80% Catppuccin base layer, matching WezTerm. The macOS
               package removes vibrancy, so focus cannot change the material. */
            body.is-translucent:not(.is-fullscreen) {
              --workspace-background-translucent: rgba(var(--ctp-base), 0.8);
            }
            body.is-translucent:not(.is-fullscreen) .app-container {
              background: var(--workspace-background-translucent) !important;
            }
            body.is-translucent:not(.is-fullscreen) :is(
              .titlebar, .workspace, .workspace-split, .workspace-tabs,
              .workspace-leaf, .workspace-leaf-content, .view-content,
              .view-header, .markdown-source-view, .cm-editor, .cm-scroller,
              .markdown-reading-view, .markdown-preview-view,
              .workspace-tab-header-container, .workspace-sidedock-vault-profile
            ) {
              background-color: transparent !important;
            }
            /* Menus, dialogs and settings stay solid for readability. */
            body :is(.modal, .menu, .suggestion-container, .popover) {
              background-color: rgb(var(--ctp-base));
            }
          '';
        }
        {
          name = "bottom-tabs";
          text = ''
            /* Native bottom tabs: text/symbols only, existing click handlers. */
            body:not(.is-mobile) .mod-root .workspace-tab-header-container {
              display: flex !important;
              order: 2;
              flex: 0 0 28px;
              height: 28px;
              align-items: center;
              padding: 0 8px !important;
              border: 0;
              border-top: 1px solid rgba(var(--ctp-overlay0), 0.18);
              background: transparent !important;
              font-family: var(--font-monospace);
              font-size: 13px;
              -webkit-app-region: no-drag !important;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-container {
              order: 1;
              min-height: 0;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-header-container-inner {
              counter-reset: obsidian-tab;
              flex: 1 1 auto;
              min-width: 0;
              height: 100%;
              margin: 0;
              padding: 0 !important;
              gap: 12px;
              overflow-x: auto !important;
              overflow-y: hidden !important;
              -webkit-app-region: no-drag !important;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-header {
              counter-increment: obsidian-tab;
              flex: 0 0 auto !important;
              width: max-content !important;
              container-type: normal;
              max-width: 220px;
              align-items: center;
              padding: 0 !important;
              color: rgb(var(--ctp-subtext0)) !important;
              cursor: pointer;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-header.is-active {
              color: rgb(var(--ctp-lavender)) !important;
            }
            body:not(.is-mobile) .mod-root :is(.workspace-tab-header, .workspace-tab-header-inner) {
              background: transparent !important;
              border: 0 !important;
              border-radius: 0 !important;
              box-shadow: none !important;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-header::before {
              content: counter(obsidian-tab) ":";
              position: static;
              width: auto;
              height: auto;
              border-radius: 0;
              clip-path: none;
              box-shadow: none !important;
            }
            body:not(.is-mobile) .mod-root :is(.workspace-tab-header::after, .workspace-tab-header-inner::after, .workspace-tab-header-inner-icon) {
              display: none !important;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-header-inner {
              padding: 0 !important;
              gap: 5px;
              width: auto;
              min-width: 0;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-header-inner-title {
              color: inherit !important;
              font-family: inherit;
              font-size: inherit;
              font-weight: 400;
              width: auto !important;
              min-width: 0;
            }
            body:not(.is-mobile) .mod-root :is(.workspace-tab-header-inner-close-button, .workspace-tab-header-new-tab .clickable-icon, .workspace-tab-header-tab-list .clickable-icon) {
              display: flex !important;
              align-items: center;
              justify-content: center;
              flex-shrink: 0;
              width: 20px;
              height: 24px;
              padding: 0;
              color: rgb(var(--ctp-subtext0)) !important;
              font: inherit;
              cursor: pointer;
              background: transparent !important;
              -webkit-app-region: no-drag;
            }
            body:not(.is-mobile) .mod-root :is(.workspace-tab-header-inner-close-button, .workspace-tab-header-new-tab, .workspace-tab-header-tab-list) svg {
              display: none;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-header-inner-close-button::before { content: "×"; }
            body:not(.is-mobile) .mod-root .workspace-tab-header-new-tab .clickable-icon::before { content: "+"; }
            body:not(.is-mobile) .mod-root .workspace-tab-header-tab-list .clickable-icon::before { content: "⋯"; }
            body:not(.is-mobile) .mod-root :is(.workspace-tab-header-inner-close-button, .workspace-tab-header-new-tab .clickable-icon, .workspace-tab-header-tab-list .clickable-icon):hover {
              color: rgb(var(--ctp-lavender)) !important;
            }
            body:not(.is-mobile) .mod-root :is(.workspace-tab-header-new-tab, .workspace-tab-header-tab-list) {
              padding: 0;
              margin: 0 0 0 6px;
            }
            body:not(.is-mobile) .mod-root .workspace-tab-header-spacer { display: none; }
          '';
        }
      ];
    };
  };
}
