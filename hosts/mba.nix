{ pkgs, ... }:

{
  myuser.name = "keke";
  users.users.keke.home = /Users/keke;
  myuser.hm.home.stateVersion = "25.11";
  system.stateVersion = 6;
}
