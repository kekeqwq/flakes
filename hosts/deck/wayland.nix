{ pkgs, lib, ... }: {

  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];
    displayManager.sddm.enable = true;
    displayManager.sddm.settings = {
      General.InputMethod = "qtvirtualkeyboard";
      Theme.Current = "maldives";
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
    pavucontrol
    libsForQt5.qt5.qtvirtualkeyboard
    wvkbd
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
