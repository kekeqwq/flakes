{ pkgs, ... }:
let
  applyTheme = pkgs.writeShellScript "tmux-apply-catppuccin" ''
    set -e
    export PATH="${pkgs.tmux}/bin:/usr/bin:/bin:$PATH"
    mode=''${1:-}
    if [ -z "$mode" ]; then
      if [ "$(uname)" = Darwin ]; then
        mode=$(defaults read -g AppleInterfaceStyle 2>/dev/null || printf Light)
      else
        mode=Dark
      fi
    fi
    case "$mode" in
      [Dd]ark|dark)
        blue=#89b4fa
        on_blue=#1e1e2e
        ;;
      *)
        blue=#7287fd
        on_blue=#eff1f5
        ;;
    esac
    tmux set -g status-style "bg=default,fg=default"
    tmux set -g status-left "#[fg=$on_blue,bg=$blue,bold] #S #[bg=default] "
    tmux set -g status-right "#[fg=$blue]"'#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}'"#[fg=brightblack]#h "
    tmux set -g window-status-format "#[fg=brightblack] #I:#W "
    tmux set -g window-status-current-format "#[fg=$blue,bold] #I:#W "
    tmux set -g pane-border-style "fg=brightblack"
    tmux set -g pane-active-border-style "fg=$blue"
    tmux set -g message-style "bg=default,fg=$blue"
    tmux set -g message-command-style "bg=default,fg=$blue"
    tmux set -g mode-style "bg=$blue,fg=$on_blue"
    tmux set -g clock-mode-colour "$blue" || true
  '';
in
{
  myuser.hm.xdg.configFile."tmux/apply-theme".source = applyTheme;
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

      # Status bar
      set -g status-position top
      set -g status-interval 5
      set -g status-left-length 30
      set -g status-right-length 50
      set -g window-status-separator ""
      set -gw automatic-rename on
      set -gw automatic-rename-format '#{b:pane_current_path}'
      set -g set-titles on
      set -g set-titles-string '#h:#W'

      # Named theme colours do not follow `theme light`: tmux only uses the
      # light palette when the client reports a light background, which WezTerm
      # does not. Apply explicit Catppuccin hex instead.
      run-shell ${applyTheme}
    '';
  };
}
