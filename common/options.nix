{ config, options, lib, ... }:

with lib; {
  options.myuser = {
    name = mkOption {
      description = "My Current user 'username'";
      type = types.str;
      default = { };
    };

    hm = mkOption { type = options.home-manager.users.type.functor.wrapped; };

    users = mkOption { type = options.users.users.type.functor.wrapped; };
  };

  config = {
    home-manager.users.${config.myuser.name} =
      mkAliasDefinitions options.myuser.hm;
    users.users.${config.myuser.name} = mkAliasDefinitions options.myuser.users;
  };

}
