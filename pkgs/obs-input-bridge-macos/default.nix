{
  lib,
  stdenv,
  fetchFromGitHub,
  swift,
}:
stdenv.mkDerivation rec {
  pname = "obs-input-bridge-macos";
  version = "unstable-2026-08-13";
  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "obs-input-bridge-macos";
    rev = "719a198880b228108202f353bdcc1e77886a2ab2";
    hash = "sha256-lwmGpjCQG1n3YwxIv6GyYunYUpUbfnT8TdInLEDijWU=";
  };
  nativeBuildInputs = [
    swift
  ];
  buildPhase = ''
    swiftc \
      -O \
      main.swift \
      -o obs-input-bridge-macos
  '';
  installPhase = ''
    install -Dm755 obs-input-bridge-macos $out/bin/obs-input-bridge-macos
  '';
  meta = {
    description = "macOS OBS keyboard bridge";
    homepage = "https://github.com/kekeqwq/obs-input-bridge-macos";
    platforms = lib.platforms.darwin;
    mainProgram = "obs-input-bridge-macos";
  };
}
