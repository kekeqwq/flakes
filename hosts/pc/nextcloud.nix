{ pkgs, ... }:
{
  services.nextcloud = {
    enable = true;
    home = "/nix/persist/var/lib/nextcloud";
    hostName = "localhost";
    config = {
      dbtype = "pgsql";
      dbuser = "nextcloud";
      dbhost = "/run/postgresql"; # nextcloud will add /.s.PGSQL.5432 by itself
      dbname = "nextcloud";
      adminpassFile = "/nix/persist/nextcloud.key";
      adminuser = "root";
      extraTrustedDomains = [
        "127.0.0.1"
        "192.168.1.101"
        "192.168.1.102"
        "100.120.160.34"
      ];
    };
  };

  # trace: warning: You're using PHP's openssl extension built against OpenSSL 1.1 for Nextcloud.
  # This is only necessary if you're using Nextcloud's server-side encryption.
  # Please keep in mind that it's using the broken RC4 cipher.

  # If you don't use that feature, you can switch to OpenSSL 3 and get
  # rid of this warning by declaring

  #   services.nextcloud.enableBrokenCiphersForSSE = false;

  # If you need to use server-side encryption you can ignore this waring.
  # Otherwise you'd have to disable server-side encryption first in order
  # to be able to safely disable this option and get rid of this warning.
  # See <https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/encryption_configuration.html#disabling-encryption> on how to achieve this.

  # For more context, here is the implementing pull request: https://github.com/NixOS/nixpkgs/pull/198470
  services.nextcloud.enableBrokenCiphersForSSE = false;

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
      {
        name = "nextcloud";
        ensurePermissions."DATABASE nextcloud" = "ALL PRIVILEGES";
      }
    ];
  };

  # ensure that postgres is running *before* running the setup
  systemd.services."nextcloud-setup" = {
    requires = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
  };

  services.nextcloud.package = pkgs.nextcloud27;
}
