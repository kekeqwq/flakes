{ pkgs, ... }:

{
  myuser.hm.home.stateVersion = "25.11";

  system.stateVersion = 4;
  services.nix-daemon.enable = true;
  myuser.name = "keke";
  environment.systemPackages = with pkgs; [ fastfetch ];
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
}
