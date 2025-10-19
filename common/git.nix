{ config, ... }:

{
  myuser.hm.programs.git = {
    enable = true;
    settings = {
      user.name = "keke";
      user.email = "zrignshw@duck.com";
      credential.helper = "store";
    };
  };
}
