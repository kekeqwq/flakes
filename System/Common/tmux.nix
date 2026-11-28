{ lib, pkgs, ... }:
let
  colors = import ./terminal-colors.nix;
  # Match the session name shown by `tmux ls`, not the selected window index.
  # Numeric sessions get keycap emoji; custom session names retain their text.
  numberedSessions = lib.imap0 (number: symbol: { inherit number symbol; }) [
    "0️⃣"
    "1️⃣"
    "2️⃣"
    "3️⃣"
    "4️⃣"
    "5️⃣"
    "6️⃣"
    "7️⃣"
    "8️⃣"
    "9️⃣"
    "🔟"
  ];
  sessionMarker = lib.foldr (
    item: rest: "#{?#{==:#{session_name},${toString item.number}},${item.symbol},${rest}}"
  ) "#{session_name}" numberedSessions;
in
{

  # Installing the new file alone leaves existing servers on their old title,
  # hooks and palette. Reload without detaching clients or restarting panes.
  myuser.hm.xdg.configFile."tmux/tmux.conf".onChange = ''
    if ${pkgs.tmux}/bin/tmux has-session 2>/dev/null; then
      ${pkgs.tmux}/bin/tmux source-file "$HOME/.config/tmux/tmux.conf"
    fi
  '';
  myuser.hm.programs.tmux = {
    enable = true;
    shell = "${pkgs.fish}/bin/fish";
    prefix = "C-Space";
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    historyLimit = 50000;
    escapeTime = 0;
    focusEvents = true;
    terminal = "tmux-256color";
    aggressiveResize = true;
    resizeAmount = 5;

    extraConfig = ''
      set -g extended-keys on
      set -g extended-keys-format csi-u
      # Secondary prefix
      set -g prefix2 C-b
      bind -N "Send prefix" C-Space send-prefix

      # Config reload & keybinding help
      bind -N "Reload configuration" q source-file ~/.config/tmux/tmux.conf \; display "Configuration reloaded"
      bind -N "Show Tmux keybindings" ? list-keys -N

      # Vi mode for copy
      bind -N "Begin selection" -T copy-mode-vi v send -X begin-selection
      bind -N "Copy selection" -T copy-mode-vi y send -X copy-selection-and-cancel

      # Pane Controls
      bind -N "Split pane vertically" -n M-Enter split-window -v -c "#{pane_current_path}"
      bind -N "Split pane horizontally" -n M-S-Enter split-window -h -c "#{pane_current_path}"
      bind -N "Kill pane" -n M-Escape kill-pane

      bind -N "Split pane vertically" h split-window -v -c "#{pane_current_path}"
      bind -N "Split pane horizontally" v split-window -h -c "#{pane_current_path}"
      bind -N "Kill pane" x kill-pane

      bind -N "Focus pane left" -n C-M-Left select-pane -L
      bind -N "Focus pane right" -n C-M-Right select-pane -R
      bind -N "Focus pane up" -n C-M-Up select-pane -U
      bind -N "Focus pane down" -n C-M-Down select-pane -D

      bind -N "Resize pane left" -n C-M-S-Left resize-pane -L 5
      bind -N "Resize pane down" -n C-M-S-Down resize-pane -D 5
      bind -N "Resize pane up" -n C-M-S-Up resize-pane -U 5
      bind -N "Resize pane right" -n C-M-S-Right resize-pane -R 5

      # Window navigation
      bind -N "Rename window" r command-prompt -I "#W" "rename-window -- '%%'"
      bind -N "Create window" c new-window -c "#{pane_current_path}"
      bind -N "Kill window" k kill-window

      bind -N "Switch to window 1" -n M-1 select-window -t 1
      bind -N "Switch to window 2" -n M-2 select-window -t 2
      bind -N "Switch to window 3" -n M-3 select-window -t 3
      bind -N "Switch to window 4" -n M-4 select-window -t 4
      bind -N "Switch to window 5" -n M-5 select-window -t 5
      bind -N "Switch to window 6" -n M-6 select-window -t 6
      bind -N "Switch to window 7" -n M-7 select-window -t 7
      bind -N "Switch to window 8" -n M-8 select-window -t 8
      bind -N "Switch to window 9" -n M-9 select-window -t 9

      bind -N "Previous window" -n M-Left select-window -t -1
      bind -N "Next window" -n M-Right select-window -t +1
      bind -N "Move window left" -n M-S-Left swap-window -t -1 \; select-window -t -1
      bind -N "Move window right" -n M-S-Right swap-window -t +1 \; select-window -t +1

      # Session controls
      bind -N "Rename session" R command-prompt -I "#S" "rename-session -- '%%'"
      bind -N "Create session" C new-session -c "#{pane_current_path}"
      bind -N "Kill session" K kill-session
      bind -N "Previous session" P switch-client -p
      bind -N "Next session" N switch-client -n

      bind -N "Previous session" -n M-Up switch-client -p
      bind -N "Next session" -n M-Down switch-client -n

      # Terminal & behavior
      set -ag terminal-overrides ",*:RGB"
      set -g renumber-windows on
      set -g set-clipboard on
      set -g allow-passthrough on
      set -g detach-on-destroy off
      set -g cursor-style block
      set -g cursor-colour '#f5c2e7'

      # Status bar
      set -g status-position top
      set -g status-interval 5
      set -g status-left-length 30
      set -g status-right-length 50
      set -g window-status-separator ""
      set -gw automatic-rename on
      set -gw automatic-rename-format '#{b:pane_current_path}'
      set -g set-titles on
      # Socket + client tty disambiguate windows, even on the same session.
      set -g set-titles-string 'tmux:#{socket_path}:#{client_tty}'

      # Native per-client palettes, not async scripts writing server-global
      # hex colours. Two clients may have different appearances at once.
      set-hook -gu client-light-theme[92]
      set-hook -gu client-dark-theme[92]
      set -g theme detect
      set -g dark-theme-black '#1e1e2e'
      set -g dark-theme-white '#cdd6f4'
      set -g dark-theme-light-grey '#a6adc8'
      set -g dark-theme-blue '${colors.dark.accent}'
      set -g light-theme-black '#eff1f5'
      set -g light-theme-white '#4c4f69'
      set -g light-theme-light-grey '#6c6f85'
      # Keep the native per-client accent slot; vivid pink only in light mode.
      set -g light-theme-blue '${colors.light.accent}'
      set -g status-style 'bg=default,fg=default'
      # One transparent separator row below the top bar, sized per client.
      set -g status 2
      set -g status-format[1] '#[fg=themeblue,bg=default]#{R:─,#{client_width}}'
      set -g status-left '#[fg=themeblue,bg=default,bold] ${sessionMarker} '
      set -g status-right '#[fg=themeblue]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}#[fg=themelightgrey]#h '
      set -g window-status-style 'fg=themelightgrey,bg=default,bold,nounderscore'
      set -g window-status-current-style 'fg=themeblue,bg=default,bold,underscore'
      set -g window-status-format '#[fg=themelightgrey,bg=default,bold,nounderscore] #I.#W '
      set -g window-status-current-format '#[fg=themeblue,bg=default,bold,nounderscore] #[underscore]#I.#W#[nounderscore] '
      set -g pane-border-style 'fg=themelightgrey'
      set -g pane-active-border-style 'fg=themeblue'
      set -g message-style 'bg=default,fg=themeblue'
      set -g message-command-style 'bg=default,fg=themeblue'
      set -g mode-style 'bg=themeblue,fg=themeblack'
      # Built-in context menus use the same per-client palette as the bar.
      set -g menu-style 'bg=themeblack,fg=themewhite'
      set -g menu-border-style 'bg=themeblack,fg=themelightgrey'
      set -g menu-selected-style 'bg=themeblue,fg=themeblack'
      # A popup is its own surface; tmux's stock grey clashes with both palettes.
      set -g popup-style 'bg=themeblack,fg=themewhite'
      set -g popup-border-style 'bg=themeblack,fg=themeblue'
    '';
  };
}
