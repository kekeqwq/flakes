{
  config,
  pkgs,
  lib,
  ...
}:
{

  security.polkit.enable = true;

  programs.wayfire = {
    enable = true;
    plugins = with pkgs.wayfirePlugins; [
      wcm
      wf-shell
      wayfire-plugins-extra
    ];
  };

  environment.systemPackages = with pkgs; [
    wf-recorder
    swaybg
    waybar
    wl-clipboard
    grim
    slurp
    pavucontrol
    imv
    wofi
  ];

  hardware.pulseaudio.enable = lib.mkDefault false;
  services.pipewire = {
    enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
  };
}
