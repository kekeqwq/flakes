{ pkgs, ... }:
{
  programs.weylus = {
    enable = true;
    users = [ "keke" ];
  };

  services.udev.packages = [ pkgs.via ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      catppuccin-fcitx5
      (fcitx5-rime.override {
        rimeDataPkgs = with pkgs; [ rime-ice ];
      })
    ];
  };

  environment.systemPackages = with pkgs; [
    localsend
    qbittorrent
    discord
    prismlauncher
    telegram-desktop
    (google-chrome.override {
      commandLineArgs = "--password-store=basic";
    })
  ];
}
