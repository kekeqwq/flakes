{ pkgs, ... }:

{
  myuser.name = "keke";
  myuser.users.home = /Users/keke;
  myuser.hm.home.stateVersion = "25.11";
  system.stateVersion = 6;
}
