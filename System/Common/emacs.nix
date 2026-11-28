{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Headless systems get terminal Emacs. The shared desktop layer selects the
  # graphical backend without duplicating the editor's configuration per OS.
  # Home Manager maps this service to launchd (macOS) or systemd --user
  # (Linux), always using programs.emacs.finalPackage, including Ghostel.
  myuser.hm.services.emacs = {
    enable = true;
    startWithUserSession = true;
    client = {
      enable = config.my.desktop.enable;
      arguments = [
        "--create-frame"
        "--no-wait"
        "--alternate-editor=false"
      ];
    };
  };

  myuser.hm.programs.emacs = {
    enable = true;
    package = lib.mkDefault pkgs.emacs-head-nox;
  };
}
