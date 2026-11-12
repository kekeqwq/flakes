{
  config,
  lib,
  ...
}:
let
  cfg = config.my.sunshine;
  webPort = toString (config.services.sunshine.settings.port + 1);
in
{
  options.my.sunshine = {
    enable = lib.mkEnableOption "Sunshine on this host";
    capture = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "DP-1";
      description = "Display output to capture. Encoder, GPU device and capture backend stay in settings.";
    };
    proxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose the authenticated web UI on TCP 8282. The first visit creates the account; credentials are not configured here.";
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Instance-specific Sunshine settings, such as the capture backend and GPU. Do not put passwords or client certificates here.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.my.desktop.enable;
          message = "my.sunshine.enable requires my.desktop.enable; a headless host has no session to stream.";
        }
      ];
    }
    (lib.mkIf (config.my.desktop.enable && cfg.enable) {
      services.sunshine = {
        enable = true;
        autoStart = lib.mkDefault true;
        capSysAdmin = lib.mkDefault true;
        openFirewall = lib.mkDefault true;
        settings = {
          origin_web_ui_allowed = "lan";
          upnp = "disabled";
        }
        // lib.optionalAttrs (cfg.capture != null) { output_name = cfg.capture; }
        // cfg.settings;
      };

      services.nginx = lib.mkIf cfg.proxy {
        enable = true;
        virtualHosts.sunshine-proxy = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 8282;
            }
          ];
          locations."/" = {
            proxyPass = "https://127.0.0.1:${webPort}";
            extraConfig = ''
              proxy_set_header Host "127.0.0.1:${webPort}";
              proxy_set_header Origin "https://127.0.0.1:${webPort}";
              proxy_set_header Referer "https://127.0.0.1:${webPort}/";
              proxy_set_header X-Real-IP "127.0.0.1";
              proxy_set_header X-Forwarded-For "127.0.0.1";
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
            '';
          };
        };
      };
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.proxy [ 8282 ];
    })
  ];
}
