{ config, pkgs, lib, ... }: {
  
  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "sway";
        user = config.myuser.name;
      };
      default_session = initial_session;
    };
  };

  programs.sway.enable = true;

  myuser.hm.programs.foot = {
    enable = true;
    settings = {
      main.term = "xterm-256color";
      main.font = "MonoLisa Nasy:size=11";
      colors.alpha = .92;
    };
  };
  
  environment.systemPackages = with pkgs; [
    grim
    slurp
    swaybg
    dmenu
    pavucontrol
    imv
  ];

  # Aduio
  hardware.pulseaudio.enable = lib.mkDefault false;
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
  };

}
