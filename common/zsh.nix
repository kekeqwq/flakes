{ config, pkgs, ... }:

{
  users.defaultUserShell = pkgs.zsh;
  environment.shellAliases.ls = "exa -l";
  environment.shellAliases.e = "emacsclient -t -nw";
  programs.zsh = { enable = true; };
  myuser.hm.programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    initExtra = ''
      source ~/.completion.zsh
      source ~/.p10k.zsh
      # opam configuration
      [[ ! -r /home/me/.opam/opam-init/init.zsh ]] || source /home/me/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null
    '';
    envExtra = ''
      export PATH=$PATH:$HOME/.local/share/bin
    '';
    plugins = [{
      name = "powerlevel10k";
      src = pkgs.zsh-powerlevel10k;
      file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    }
    # {
    #   name = "wakatime";
    #   src = pkgs.fetchFromGitHub {
    #     owner = "sobolevn";
    #     repo = "wakatime-zsh-plugin";
    #     rev = "69c6028b0c8f72e2afcfa5135b1af29afb49764a";
    #     sha256 = "sha256-pA1VOkzbHQjmcI2skzB/OP5pXn8CFUz5Ok/GLC6KKXQ=";
    #   };
    #   file = "wakatime.plugin.zsh";
    # }
      ];
  };
}
