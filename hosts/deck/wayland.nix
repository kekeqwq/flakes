{ config, pkgs, lib, ... }: {

  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "${config.myuser.name}";
    desktopSession = "none+i3";
  };

  services.xserver = {
    enable = true;
    desktopManager = { xterm.enable = false; };
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [ dmenu i3status onboard pavucontrol alacritty];
    };
  };

  # Aduio
  hardware.pulseaudio.enable = lib.mkDefault false;
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
  };
  environment.pathsToLink = [ "/share/alsa/ucm2" ];
}
