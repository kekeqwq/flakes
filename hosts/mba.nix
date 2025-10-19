{ pkgs, ... }:

{
  system.stateVersion = 6;
  environment.systemPackages = with pkgs; [
    fastfetch
    git
  ];
}
