{ pkgs, ... }:
{
  # Cross-platform directory jumper. The login shell is fish on every instance,
  # so only the fish adapter is enabled: it registers z/zi as fish functions and
  # scores directories from the native PWD event, with no prompt hook and no
  # `cd` alias (which zoxide itself warns would loop). `zi` and the interactive
  # completion of `z` call fzf, so ship it alongside.
  myuser.hm = {
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
    home.packages = [ pkgs.fzf ];
  };
}
