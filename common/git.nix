{ config, ... }:

{
  myuser.hm.programs.git = {
    enable = true;
    userName = "keke";
    userEmail = "zrignshw@duck.com";
    extraConfig = {
      credential.helper = "store";
    };
  };
}
