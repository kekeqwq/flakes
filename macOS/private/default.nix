_: {
  imports = [
    ../../System/Common
    ./system.nix
    ./tailscale-routes.nix
    ./security.nix
    ./fonts.nix
    ./ghostty.nix
    ./input-method.nix
    ./emacs-rime.nix
    ./emacs-client.nix
    ./rime-squirrel.nix
    ./shell.nix
    ./opensctoken.nix
    ./yazi.nix
  ];
  # MarginNote is a macOS workflow; keep the shared Pi setup platform-neutral.
  myuser.hm.home.file.".pi/agent/skills/mn-bridge/SKILL.md".source =
    ./pi-skills/mn-bridge/SKILL.md;

  my.desktop.enable = true;
  my.opensctoken.enable = true;
}
