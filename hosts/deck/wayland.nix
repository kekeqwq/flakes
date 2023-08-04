{ pkgs, lib, ... }: {
  myuser.hm.programs.emacs = {
    enable = true;
    package = pkgs.emacs29;
  };
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
    feh
    sxiv
    alacritty
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
