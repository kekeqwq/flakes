{
  config,
  pkgs,
  lib,
  ...
}:
{

  security.polkit.enable = true;

  programs.niri.enable = true;

  programs.wayfire = {
    enable = false;
    plugins = with pkgs.wayfirePlugins; [
      wcm
      wf-shell
      wayfire-plugins-extra
    ];
  };

  environment.systemPackages = with pkgs; [
    # Niri need statllite
    xwayland-satellite
    wev
    wlr-randr
    # wf-recorder
    swaybg
    waybar
    wl-clipboard
    grim
    slurp
    pavucontrol
    imv
    rofi
  ];

  #hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
  };
}
