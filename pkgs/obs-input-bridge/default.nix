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
  version = "unstable-2026-08-14";
  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "obs-input-bridge";
    rev = "8addb56d270e177c4e8e822d66a0294ac2f5be82";
    hash = "sha256-4OFR1Am2lIPgdgzWScHVF2UA8Dazcm8nJjcFhxDSqx0=";
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
