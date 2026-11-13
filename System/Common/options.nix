{
  config,
  options,
  lib,
  ...
}:

with lib;
{
  options.my.desktop.enable = mkEnableOption "the shared graphical desktop (in addition to the terminal environment)";

  # Empty when the platform has no switcher; WezTerm then leaves Ctrl+B alone.
  options.my.inputMethod.prefixCommand = mkOption {
    type = types.str;
    default = "";
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
