{
  lib,
  python3Packages,
  wrapGAppsHook3,
  gobject-introspection,
  gtk3,
  brightnessctl,
  pulseaudio,
  networkmanager,
  bluez,
  procps,
}:

python3Packages.buildPythonApplication {
  pname = "keke-waybar-panel";
  version = "1";

  format = "other";
  dontUnpack = true;

  nativeBuildInputs = [
    wrapGAppsHook3
    gobject-introspection
  ];
  buildInputs = [ gtk3 ];

  propagatedBuildInputs = with python3Packages; [ pygobject3 ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/keke-waybar-panel"
    cp ${./panel.py} "$out/share/keke-waybar-panel/panel.py"
    cp ${./panel.css} "$out/share/keke-waybar-panel/panel.css"
    makeWrapper ${python3Packages.python.interpreter} "$out/bin/keke-waybar-panel" \
      --add-flags "$out/share/keke-waybar-panel/panel.py" \
      --prefix PATH : ${
        lib.makeBinPath [
          brightnessctl
          pulseaudio
          networkmanager
          bluez
          procps
        ]
      } \
      --set KEKE_PANEL_CSS "$out/share/keke-waybar-panel/panel.css"
    runHook postInstall
  '';

  meta.mainProgram = "keke-waybar-panel";
}
