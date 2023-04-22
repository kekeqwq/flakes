{ config, pkgs, lib, ... }: {
  
  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "Hyprland";
        # command = "steam-session";
        user = config.myuser.name;
      };
      default_session = initial_session;
    };
  };

  programs.hyprland.enable = true;

  myuser.hm.programs.foot = {
    enable = true;
    settings = {
      main.font = "MonoLisa Nasy:size=11";
      colors.alpha = .92;
    };
  };
  
  environment.systemPackages = with pkgs; [
    swaybg
    waybar
    wofi
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
