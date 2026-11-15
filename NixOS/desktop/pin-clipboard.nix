{ pkgs }:
pkgs.writeShellApplication {
  name = "pin-clipboard";
  runtimeInputs = [
    pkgs.python3
    pkgs.wl-clipboard
    pkgs.xclip
    pkgs.snipaste
  ];
  text = ''
    exec python3 ${./pin-clipboard.py}
  '';
}
