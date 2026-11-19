# Shared control-center actions. Kept as a pure value so eval-only checks can
# inspect it without realizing a derivation.
{ pkgs, wallpaper }:
[
  {
    id = "lock";
    label = "Lock screen";
    icon = "󰌾";
    argv = [ "screen-lock" ];
    confirm = false;
  }
  {
    id = "wallpaper-random";
    label = "Random Switch";
    icon = "󰋩";
    argv = [
      "${wallpaper.ctl}/bin/wallpaper-ctl"
      "random"
    ];
    auth = "sudo";
    confirm = false;
  }
  {
    id = "wallpaper-default";
    label = "Default Wallpaper";
    icon = "󰸈";
    argv = [
      "${wallpaper.ctl}/bin/wallpaper-ctl"
      "default"
    ];
    auth = "sudo";
    confirm = false;
  }
  {
    id = "wallpaper-delete";
    label = "Delete Wallpaper";
    icon = "󰩺";
    argv = [
      "${wallpaper.ctl}/bin/wallpaper-ctl"
      "delete"
    ];
    auth = "sudo";
    confirm = true;
    confirm_message = "Switch to another wallpaper and permanently delete this source file?";
    requires_nonempty_file = wallpaper.sourceState;
  }
  {
    id = "reboot";
    label = "Restart";
    icon = "󰜉";
    argv = [
      "${pkgs.systemd}/bin/systemctl"
      "reboot"
    ];
    confirm = true;
  }
  {
    id = "poweroff";
    label = "Power off";
    icon = "󰐥";
    argv = [
      "${pkgs.systemd}/bin/systemctl"
      "poweroff"
    ];
    confirm = true;
  }
]
