{ config, pkgs, lib, ... }: {

  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "wayfire";
        user = config.myuser.name;
      };
      default_session = initial_session;
    };
  };

  programs.wayfire = {
    enable = true;
    plugins = with pkgs.wayfirePlugins; [ wcm wf-shell wayfire-plugins-extra ];
  };

  myuser.hm.programs.foot = {
    enable = true;
    settings = {
      main.term = "xterm-256color";
      main.font = "MonoLisa Nasy:size=11";
      colors.alpha = .92;
      main.initial-window-size-pixels= "1000x900";
      cursor = {
        style = "beam";
        blink = "yes";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    wf-recorder
    swaybg
    waybar
    wl-clipboard
    grim
    slurp
    pavucontrol
    imv
    wofi
  ];

  # Aduio
  hardware.pulseaudio.enable = lib.mkDefault false;
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
  };

}
