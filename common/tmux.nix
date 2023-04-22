{ pkgs, ... }:

{

  programs.tmux = {
    enable = true;
    extraConfig = ''
      set -g mouse on
      set-option -g default-terminal "xterm-256color"
      set -g status-bg default
      set -g status-fg white
      set -g status-style fg=white,bg=default
      set -g status-left ""
      set -g status-right ""
      set -g status-justify centre
      set -g status-position bottom
      set -g pane-active-border-style bg=default,fg=default
      set -g pane-border-style fg=cyan
      set -g window-status-current-format "#[fg=cyan]#[fg=black]#[bg=cyan] #I #[bg=brightblack]#[fg=white] #W#[fg=brightblack]#[bg=default] #[bg=default] #[fg=magenta] #[fg=black]#[bg=magenta] λ #[fg=white]#[bg=brightblack] %R#[fg=brightblack]#[bg=default] "
      set -g window-status-format "#[fg=magenta]#[fg=black]#[bg=magenta]#I #[bg=brightblack]#[fg=white] #W#[fg=brightblack]#[bg=default] "
    '';
  };
}
# set -g window-status-current-format "#[fg=cyan]#[fg=black]#[bg=cyan]#I #[bg=brightblack]#[fg=white] #W#[fg=brightblack]#[bg=default] #[bg=default] #[fg=magenta]#[fg=black]#[bg=magenta]λ #[fg=white]#[bg=brightblack] %a %d %b #[fg=magenta]%R#[fg=brightblack]#[bg=default]"
# set -g window-status-format "#[fg=magenta]#[fg=black]#[bg=magenta]#I #[bg=brightblack]#[fg=white] #W#[fg=brightblack]#[bg=default] "
