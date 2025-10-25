{
  config,
  pkgs,
  lib,
  ...
}:
{

  security.polkit.enable = true;

  programs.niri.enable = true;
  programs.xwayland.enable = true;

  programs.wayfire = {
    enable = true;
    plugins = with pkgs.wayfirePlugins; [
      wcm
      wf-shell
      wayfire-plugins-extra
    ];
  };

  environment.systemPackages = with pkgs; [
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
