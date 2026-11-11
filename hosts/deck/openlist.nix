{ config, pkgs, ... }:
{
  # Instance-specific mounts/accounts belong to this Deck, not the server base.
  # Preserve the current working directory and data ownership. Back up the
  # private data/ directory separately; never put its config/database in store.
  environment.systemPackages = [ pkgs.openlist ];
  systemd.services.openlist = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.openlist}/bin/OpenList server";
      WorkingDirectory = config.users.users.${config.myuser.name}.home;
      Restart = "on-failure";
    };
  };
}
