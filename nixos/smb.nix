_: {
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        security = "user";
        workgroup = "WORKGROUP";
        "server string" = "keke's library";
        "max log size" = "50";
        "dns proxy" = false;
        "syslog only" = true;
      };
      public = {
        comment = "keke's library";
        path = "/home/keke/Downloads/";
        "force user" = "keke";
        public = "yes";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "2777";
        writable = "yes";
        browseable = "yes";
        printable = "no";
        "valid users" = "keke";
      };
    };
  };
}
