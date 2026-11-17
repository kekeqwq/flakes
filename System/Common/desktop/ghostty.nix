{
  pkgs,
  ...
}:
let
  fonts = import ./font-policy.nix;
  # Ghostty prefers the first family covering a codepoint, so the color emoji
  # face must precede the symbol fonts. Small platform adaptation is allowed.
  emoji = if pkgs.stdenv.hostPlatform.isDarwin then "Apple Color Emoji" else "Noto Color Emoji";
  families = cjk: [
    fonts.latin
    cjk
    emoji
    "DejaVu Sans Mono"
    "Symbols Nerd Font Mono"
    "Noto Sans Symbols 2"
  ];
in
{
  myuser.hm.programs.fish.interactiveShellInit = ''
    if set -q GHOSTTY_SURFACE_ID; and not set -q TMUX
      function fish_title
        printf 'ghostty-shell:%s' "$GHOSTTY_SURFACE_ID"
      end
    end
  '';

  # Shared Ghostty terminal on the desktop layer. Linux uses nixpkgs; macOS
  # installs the Homebrew cask (nixpkgs ghostty is Linux-only), so package is
  # null there and only the config is written.
  myuser.hm.programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.ghostty;

    settings = {
      # Latin remains MonoLisa. Select the vendor's actual CJK faces explicitly;
      # both files report regular weight, so do not thicken Latin or modify fonts.
      font-family = families fonts.cjkRegular;
      font-family-bold = families fonts.cjkBold;
      font-family-bold-italic = families fonts.cjkBold;
      font-size = if pkgs.stdenv.hostPlatform.isDarwin then 16 else 12;
      # Text-default emoji and keycap components would otherwise lose to
      # monochrome symbol faces; force them to the color emoji face.
      font-codepoint-map = [
        "U+20E3=${emoji}"
        "U+FE0F=${emoji}"
        "U+1F000-U+1FAFF=${emoji}"
      ];
      background-opacity = 0.95;
      unfocused-split-opacity = 1;
      # Give both the tmux bar and terminal content room inside rounded edges.
      window-padding-x = 12;
      window-padding-y = 10;
      confirm-close-surface = false;
      cursor-style = "block";
      cursor-style-blink = false;
      shell-integration-features = "no-cursor";
      command = "${pkgs.fish}/bin/fish --login";
      # Follows the desktop light/dark theme; themes are defined below.
      theme = "light:catppuccin-latte,dark:catppuccin-mocha";
    };

    themes = {
      catppuccin-mocha = {
        background = "#1e1e2e";
        foreground = "#cdd6f4";
        cursor-color = "#f5c2e7";
        selection-background = "#353749";
        selection-foreground = "#cdd6f4";
        palette = [
          "0=#45475a"
          "1=#f38ba8"
          "2=#a6e3a1"
          "3=#f9e2af"
          "4=#89b4fa"
          "5=#f5c2e7"
          "6=#94e2d5"
          "7=#bac2de"
          "8=#585b70"
          "9=#f38ba8"
          "10=#a6e3a1"
          "11=#f9e2af"
          "12=#89b4fa"
          "13=#f5c2e7"
          "14=#94e2d5"
          "15=#a6adc8"
        ];
      };
      catppuccin-latte = {
        background = "#eff1f5";
        foreground = "#4c4f69";
        cursor-color = "#ea76cb";
        selection-background = "#bcc0cc";
        selection-foreground = "#4c4f69";
        palette = [
          "0=#ccd0da"
          "1=#d20f39"
          "2=#40a02b"
          "3=#df8e1d"
          "4=#1e66f5"
          "5=#8839ef"
          "6=#179299"
          "7=#acb8be"
          "8=#bcc0cc"
          "9=#d20f39"
          "10=#40a02b"
          "11=#df8e1d"
          "12=#1e66f5"
          "13=#8839ef"
          "14=#179299"
          "15=#5c5f77"
        ];
      };
    };
  };
}
