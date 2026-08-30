{ pkgs, ... }:

{
  myuser.name = "keke";
  myuser.users.home = /Users/keke;
  myuser.hm.home.stateVersion = "25.11";
  networking.hostName = "mba";
  system.stateVersion = 6;
  system.primaryUser = "keke";

  # launchd.user.agents.obs-input-bridge = {
  #   serviceConfig = {
  #     ProgramArguments = [
  #       "${pkgs.obs-input-bridge-macos}/bin/obs-input-bridge-macos"
  #     ];
  #     RunAtLoad = true;
  #     KeepAlive = true;
  #     StandardOutPath = "/tmp/obs-input-bridge.log";
  #     StandardErrorPath = "/tmp/obs-input-bridge.error.log";
  #   };
  # };

  system.defaults = {
    screencapture = {
      location = "/tmp";
    };
    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
    };
    NSGlobalDomain = {
      _HIHideMenuBar = false;
      AppleTemperatureUnit = "Celsius";
      NSAutomaticSpellingCorrectionEnabled = false;
      InitialKeyRepeat = 11;
      KeyRepeat = 1;
    };
  };
  fonts.packages = with pkgs; [
    nerd-fonts.symbols-only
  ];
  programs.tmux.enable = pkgs.lib.mkForce false;
  environment.systemPackages = with pkgs; [
    kikieye
    iina
    mihomo
    typst
    git
    clang
    scrcpy
    cinny-desktop
    telegram-desktop
    ffmpeg
    wezterm
    mpv
    moonlight-qt
    emacs
  ];
}
