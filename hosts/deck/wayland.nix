{ config, pkgs, lib, ... }: {

  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "${config.myuser.name}";
    desktopSession = "sway";
  };

  programs.sway.enable = true;
  environment.systemPackages = with pkgs; [
    squeekboard
    pavucontrol
  ];

  # Aduio
  hardware.pulseaudio.enable = lib.mkDefault false;
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
  };
  environment.pathsToLink = [ "/share/alsa/ucm2" ];
}
