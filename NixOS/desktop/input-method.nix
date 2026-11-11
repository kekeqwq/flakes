{ pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      # Never ignore the user directory: each instance keeps its own training.
      ignoreUserConfig = false;
      addons = with pkgs; [
        catppuccin-fcitx5
        (fcitx5-rime.override { rimeDataPkgs = [ rime-ice ]; })
      ];
    };
  };

  # Manage individual static files, not the whole Rime directory. userdb,
  # installation.yaml, user.yaml and build caches remain local to the instance.
  myuser.hm = {
    xdg.configFile = {
      "fcitx5/profile" = {
        force = true;
        text = ''
          [Groups/0]
          Name=Default
          Default Layout=us
          DefaultIM=rime

          [Groups/0/Items/0]
          Name=keyboard-us
          Layout=

          [Groups/0/Items/1]
          Name=rime
          Layout=

          [GroupOrder]
          0=Default
        '';
      };
      "fcitx5/config" = {
        force = true;
        text = ''
          [Hotkey/TriggerKeys]
          0=Control+Shift+space

          [Behavior]
          ActiveByDefault=False
          ShareInputState=No
          PreeditEnabledByDefault=True
        '';
      };
      "fcitx5/conf/classicui.conf" = {
        force = true;
        text = ''
          Theme=catppuccin-mocha-mauve
          DarkTheme=catppuccin-mocha-mauve
          UseDarkTheme=True
        '';
      };
    };
    xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
      force = true;
      text = ''
        patch:
          __include: rime_ice_suggestion:/
          schema_list:
            - schema: double_pinyin_flypy
      '';
    };
  };
}
