{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "monolisa-nasy";
  version = "local";
  src = ./fonts;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 MonoLisaNasyNormal.ttf "$out/share/fonts/truetype/MonoLisaNasyNormal.ttf"
    install -Dm644 MonoLisaNasyItalic.ttf "$out/share/fonts/truetype/MonoLisaNasyItalic.ttf"
    runHook postInstall
  '';
  meta = {
    description = "User-supplied MonoLisa Nasy normal and italic fonts";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
