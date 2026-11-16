{ pkgs }:
let
  upstream = pkgs.niri;
in
pkgs.symlinkJoin {
  name = "niri-${upstream.version}-explicit-session-env";
  inherit (upstream) version;
  paths = [ upstream ];
  nativeBuildInputs = [ pkgs.python3 ];
  # Keep the cached compositor binary/units; do not rebuild Rust for a shell fix.
  postBuild = ''
    rm "$out/bin/niri-session"
    python3 ${./patch-session.py} ${upstream}/bin/niri-session "$out/bin/niri-session" ${pkgs.bash}/bin/bash
    chmod 755 "$out/bin/niri-session"
  '';
  passthru = (upstream.passthru or { }) // {
    explicitSessionEnvironment = true;
  };
  meta = upstream.meta // {
    outputsToInstall = [ "out" ];
  };
}
