{ pkgs, config, ... }:
let
  mapper = pkgs.xremap.niri;
  configuration = pkgs.writeText "emacs-rime-shift.json" (
    builtins.toJSON {
      modmap = [
        {
          name = "Emacs Rime Shift tap only";
          application.only = [
            "emacs"
            "Emacs"
            "org.gnu.Emacs"
          ];
          remap.LEFTSHIFT = {
            tap = "F13";
            hold = "LEFTSHIFT";
            hold_threshold_millis = 0;
            tap_timeout_millis = 500;
          };
        }
      ];
    }
  );
in
{
  # Xremap must read physical keyboards and create a virtual one.  The
  # application filter leaves all non-Emacs keys unchanged.
  hardware.uinput.enable = true;
  users.users.${config.myuser.name}.extraGroups = [
    "input"
    "uinput"
  ];
  environment.systemPackages = [
    mapper
    pkgs.fcitx5
  ];
  myuser.hm.systemd.user.services.emacs-rime-shift = {
    Unit = {
      Description = "Emacs-only left Shift tap bridge (Niri)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "NIRI_SOCKET";
    };
    Service = {
      ExecStart = "${mapper}/bin/xremap --watch=device --desktop niri --no-window-logging ${configuration}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
