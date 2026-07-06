{ pkgs, ... }:

{

  # Temp
  documentation.enable = false;
  system.tools.darwin-uninstaller.enable = false;
  #github.com/nix-darwin/nix-darwin/issues/1817
  
  myuser.name = "keke";
  myuser.users.home = /Users/keke;
  myuser.hm.home.stateVersion = "25.11";
  networking.hostName = "mba";
  system.stateVersion = 6;
  system.primaryUser = "keke";
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
  environment.systemPackages = with pkgs; [
    obsidian
    mihomo
    typst
    git
    stylua
    clang
    scrcpy
    cinny-desktop
    localsend
    telegram-desktop
    ffmpeg
    wezterm
    mpv
    moonlight-qt
    emacs
    sing-box
  ];
}
