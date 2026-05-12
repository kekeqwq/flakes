{ config, pkgs, ... }:
{
  myuser.hm.home.packages = [ pkgs.starship ];
  myuser.hm.programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      starship init fish | source
      alias ls="exa"
      alias sc="screen /dev/cu.usbmodem5B162124901 9600"
    '';
  };
}
