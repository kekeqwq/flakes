{ pkgs, ... }:
{
  programs.weylus = {
    enable = true;
    users = [ "keke" ];
  };

  services.udev.packages = [ pkgs.via ];

  environment.systemPackages = with pkgs; [
    localsend
    discord
    prismlauncher
    telegram-desktop
    (google-chrome.override {
      commandLineArgs = "--password-store=basic";
    })
  ];
}
