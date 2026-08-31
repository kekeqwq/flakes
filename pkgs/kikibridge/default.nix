{
  stdenv,
  fetchFromGitHub,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "kikibridge-rx";
  version = "1.1.3";

  src = fetchFromGitHub {
    owner = "kekeqwq";
    repo = "kikibridge";
    rev = "e4d97837c41b949df5d1f001b1d6728868d66bc9";
    hash = "sha256-biQLWZi4WDJ0nlPqjZ45935gPE84jIliOKbkzJkezAQ=";
  };

  sourceRoot = "${src.name}/receiver-linux";
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra -o kikibridge-rx receiver.c
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 kikibridge-rx $out/bin/kikibridge-rx
    runHook postInstall
  '';

  meta = {
    description = "KikiBridge UDP input receiver";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "kikibridge-rx";
  };
}
