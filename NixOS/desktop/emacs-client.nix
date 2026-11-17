{ config, pkgs, ... }:
let
  client = "${config.home-manager.users.${config.myuser.name}.programs.emacs.finalPackage}/bin/emacsclient";
in
{
  # Shadow the upstream standalone launcher at the standard desktop ID so
  # Niri's app launcher, file associations and `gtk-launch emacs` use clients.
  myuser.hm.xdg.desktopEntries.emacs = {
    name = "Emacs";
    genericName = "Text Editor";
    exec = "${client} --create-frame --no-wait --alternate-editor=false %F";
    icon = "emacs";
    terminal = false;
    categories = [ "Development" "TextEditor" ];
    mimeType = [ "text/plain" "text/x-python" "text/x-shellscript" ];
    settings.StartupWMClass = "Emacsd";
  };
  myuser.hm.systemd.user.services.emacs.Service = {
    TimeoutStartSec = 300;
    RestartSec = 5;
  };
}
