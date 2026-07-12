{ config, pkgs, ... }:

{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."usb-wifi-proxy" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 8181;
        }
      ];
      locations."/" = {
        proxyPass = "http://192.168.0.1";
        extraConfig = ''
          proxy_set_header Host "192.168.0.1";
          proxy_set_header Referer "http://192.168.0.1/";
          proxy_cookie_domain 192.168.0.1 $host;
          proxy_cookie_path / /;
          proxy_buffering off;
          add_header Cache-Control "no-cache, no-store, must-revalidate";
        '';
      };
    };
    virtualHosts."sunshine-proxy" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 8282;
        }
      ];
      locations."/" = {
        proxyPass = "https://127.0.0.1:47990";
        extraConfig = ''
          proxy_set_header Host "127.0.0.1:47990";
          proxy_set_header Origin "https://127.0.0.1:47990";
          proxy_set_header Referer "https://127.0.0.1:47990/";
          proxy_set_header X-Real-IP "127.0.0.1";
          proxy_set_header X-Forwarded-For "127.0.0.1";
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };
    };
    virtualHosts."deck-center" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];
      root = "/kk/center";
      locations."/" = {
        index = "index.html";
      };
    };
  };

  networking.networkmanager = {
    settings = {
      "connection-usb-wifi-metric" = {
        "match-device" = "interface-name:enp4s0f3u1";
        "ipv4.route-metric" = "5000";
        "ipv6.route-metric" = "5000";
      };
    };
  };
}
