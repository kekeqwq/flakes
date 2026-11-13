{
  lib,
  python3,
  stdenv,
  makeWrapper,
  wrapGAppsHook3,
  gobject-introspection,
  gtk3,
  brightnessctl,
  pulseaudio,
  networkmanager,
  bluez,
  iproute2,
}:

let
  # Wrapped interpreter: `gi` must be importable at runtime.
  python = python3.withPackages (ps: [ ps.pygobject3 ]);
in
stdenv.mkDerivation {
  pname = "keke-waybar-panel";
  version = "1";

  dontUnpack = true;
  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook3
    gobject-introspection
  ];
  buildInputs = [ gtk3 ];
  dontWrapGApps = false;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/keke-waybar-panel"
    cp ${./panel.py} "$out/share/keke-waybar-panel/panel.py"
    cp ${./panel.css} "$out/share/keke-waybar-panel/panel.css"
    makeWrapper ${python}/bin/python3 "$out/bin/keke-waybar-panel" \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "$out/share/keke-waybar-panel/panel.py" \
      --prefix PATH : ${
        lib.makeBinPath [
          brightnessctl
          pulseaudio
          networkmanager
          bluez
          iproute2
        ]
      } \
      --set KEKE_PANEL_CSS "$out/share/keke-waybar-panel/panel.css" \
      --prefix GI_TYPELIB_PATH : "$GI_TYPELIB_PATH"
    runHook postInstall
  '';

  meta.mainProgram = "keke-waybar-panel";
}
