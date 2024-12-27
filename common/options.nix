{
  config,
  options,
  lib,
  ...
}:

with lib;
{
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
