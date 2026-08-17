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
  version = "unstable-2026-08-17";
  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "obs-input-bridge";
    rev = "ca97270bc60d5a0eaef27f0b0b59ac8374f7f7da";
    hash = "sha256-ilDLlXU8+S9vpVt+mkf/PLaX6CHcECkdS9sJ/EIMil0=";
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
