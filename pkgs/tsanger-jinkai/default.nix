{ lib, tsangertypePackages, ... }:
let
  upstream = tsangertypePackages.tsangerjinkai;
  # Use the existing 05 design. Keep vendor bytes/names intact; no home-font
  # dependency, outline changes, renaming or redistribution through public caches.
  wanted = [
    "TsangerJinKai05-W03.ttf"
    "TsangerJinKai05-W05.ttf"
  ];
  sources = builtins.filter (src: builtins.elem src.name wanted) upstream.srcs;
in
assert builtins.length sources == builtins.length wanted;
upstream.overrideAttrs (_: {
  pname = "tsanger-jinkai-05";
  srcs = sources;
  installPhase = ''
    runHook preInstall
    ${lib.concatMapStringsSep "\n" (src: ''
      install -Dm444 ${src} "$out/share/fonts/truetype/${src.name}"
    '') sources}
    runHook postInstall
  '';
})
