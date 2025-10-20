{ config, pkgs, ... }:
{
  myuser.hm.programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';
  };
}
