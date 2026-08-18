{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  python3Packages,
  makeWrapper,
}:

let
  pythonPath = python3Packages.makePythonPath [
    python3Packages.evdev
  ];
in

stdenv.mkDerivation rec {
  pname = "obs-input-bridge";
  version = "unstable-2026-08-17-ver2";
  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "obs-input-bridge";
    rev = "af9f0220cb96dfc99239b95b9e71852f8a823bb5";
    hash = "sha256-gg1svpFW0Y7V2KTyuPI2Cqs32VSzGxXBkph7TV6NX08=";
  };
  nativeBuildInputs = [
    makeWrapper
    python3
  ];
  installPhase = ''
    install -Dm755 receiver.py \
      $out/bin/obs-input-bridge
    patchShebangs $out/bin/obs-input-bridge
    wrapProgram $out/bin/obs-input-bridge \
      --prefix PYTHONPATH : "${pythonPath}"
  '';
  meta = {
    description = "OBS input bridge receiver";
    homepage = "https://github.com/kekeqwq/obs-input-bridge";
    platforms = lib.platforms.linux;
    mainProgram = "obs-input-bridge";
  };
}
