{ config, ... }:

{
  myuser.hm.home.file = {
    ".completion.zsh".source = ./.config/zsh/completion.zsh;
    ".p10k.zsh".source = ./.config/zsh/.p10k.zsh;
  };
}
