_: {
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
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
      k = {
        comment = "kkk";
        path = "/k";
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
