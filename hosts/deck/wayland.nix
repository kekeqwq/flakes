{ pkgs, lib, ... }: {

  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];
    windowManager.i3.enable = true;
    displayManager.sddm.enable = true;
    displayManager.sddm.settings = {
      General.InputMethod = "qtvirtualkeyboard";
      Theme.Current = "maldives";
    };
  };
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "i3";

  environment.systemPackages = with pkgs; [
    pavucontrol
    libsForQt5.qt5.qtvirtualkeyboard
    onboard
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
