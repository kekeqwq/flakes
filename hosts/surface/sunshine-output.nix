{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.services.sunshine;
  baseConfig = (pkgs.formats.keyValue { }).generate "surface-sunshine-base.conf" cfg.settings;
  sunshine =
    if cfg.capSysAdmin then "${config.security.wrapperDir}/sunshine" else lib.getExe cfg.package;
in
{
  assertions = [
    {
      assertion = !(cfg.settings ? output_name);
      message = "Surface Sunshine resolves output_name from the active Niri session.";
    }
  ];
  systemd.user.services.sunshine = {
    wants = [ "xdg-desktop-portal.service" ];
    after = [ "xdg-desktop-portal.service" ];
    serviceConfig = {
      RuntimeDirectory = "surface-sunshine";
      RuntimeDirectoryMode = "0700";
      ExecStart = lib.mkForce (
        utils.escapeSystemdExecArgs [
          (lib.getExe pkgs.python3)
          "${./sunshine-output.py}"
          "${config.programs.niri.package}/bin/niri"
          "${baseConfig}"
          sunshine
        ]
      );
    };
  };
}
