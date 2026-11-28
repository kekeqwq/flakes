{
  config,
  options,
  lib,
  ...
}:

with lib;
{
  options.my.desktop.enable = mkEnableOption "the shared graphical desktop (in addition to the terminal environment)";

  options.my.pythonExtraPackages = mkOption {
    type = types.listOf types.package;
    default = [ ];
    internal = true;
    description = "Extra packages for the shared system Python environment.";
  };

  options.myuser = {
    name = mkOption { type = types.str; };
    hm = mkOption { type = types.str; };
    users = mkOption { type = types.str; };
  };

  config = {
    home-manager.users.${config.myuser.name} = mkAliasDefinitions options.myuser.hm;
    users.users.${config.myuser.name} = mkAliasDefinitions options.myuser.users;
  };

}
