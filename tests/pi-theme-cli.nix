{
  pkgs,
  pi,
  themes,
}:
pkgs.runCommand "pi-theme-bundled-cli" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 ${./pi-theme-cli.py} ${pi}/bin/pi ${themes}
  touch "$out"
''
