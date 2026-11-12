{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.qbittorrent;
  policy = pkgs.writeText "qbittorrent-policy.json" (
    builtins.toJSON {
      BitTorrent = {
        "Session\\AddTrackersFromURLEnabled" = "true";
        "Session\\AdditionalTrackersURL" =
          "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt";
        "Session\\DefaultSavePath" = config.my.qbittorrent.downloadDirectory;
      };
      Preferences = {
        "WebUI\\Address" = "*";
        "WebUI\\LocalHostAuth" = "true";
        "WebUI\\AuthSubnetWhitelistEnabled" = "false";
        "WebUI\\CSRFProtection" = "true";
        "WebUI\\ClickjackingProtection" = "true";
        "WebUI\\HostHeaderValidation" = "true";
      };
    }
  );
in
{
  options.my.qbittorrent.downloadDirectory = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/qBittorrent/downloads";
    description = "Instance-owned absolute download directory; provision disk permissions separately.";
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.serverConfig == { } && cfg.configFile == null;
        message = "qBittorrent uses a non-secret managed policy merge; do not also replace its private config.";
      }
    ];
    services.qbittorrent = {
      package = lib.mkDefault pkgs.qbittorrent-enhanced-nox;
      webuiPort = lib.mkDefault 8080;
      extraArgs = [ "--confirm-legal-notice" ];
    };
    # The upstream module owns profileDir/qBittorrent, not necessarily
    # profileDir itself. Provision the sibling download directory explicitly
    # before the unprivileged service attempts to use it.
    systemd.tmpfiles.settings.qbittorrent-downloads = {
      "${config.my.qbittorrent.downloadDirectory}"."d" = {
        mode = "0750";
        user = cfg.user;
        group = cfg.group;
      };
    };
    # Merge only the public policy. In particular never overwrite a WebUI
    # password created by the user with a public-store configuration file.
    systemd.services.qbittorrent.serviceConfig.ExecStartPre = lib.mkForce (
      pkgs.writeShellScript "qbittorrent-public-policy" ''
        ${pkgs.python3}/bin/python3 ${./qbittorrent-policy.py} \
          ${policy} ${lib.escapeShellArg "${cfg.profileDir}/qBittorrent/config/qBittorrent.conf"} \
          ${lib.escapeShellArg config.my.qbittorrent.downloadDirectory}
      ''
    );
  };
}
