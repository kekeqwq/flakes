{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  autoPatchelfHook,
  zlib,
}:
let
  version = "0.171.1";
  releases = {
    aarch64-darwin = {
      archive = "eca-native-macos-aarch64.zip";
      sha256 = "fd6c7fae0f3c267452799572acbd443ad474d2e874919e08fd62eb106dbce0cd";
    };
    aarch64-linux = {
      archive = "eca-native-linux-aarch64.zip";
      sha256 = "4c1418a8a0d865458a7990e13118c8e95584ad9653531afb0aaa61e17e627ca3";
    };
    x86_64-linux = {
      archive = "eca-native-static-linux-amd64.zip";
      sha256 = "3a897cb46bc13d5cab16d43542ecc13035bb77a703e084435c2c650c7c501cfd";
    };
  };
  inherit (stdenvNoCC.hostPlatform) system;
  release = releases.${system};
  dynamicArmLinux = system == "aarch64-linux";
in
stdenvNoCC.mkDerivation {
  pname = "eca";
  inherit version;
  src = fetchurl {
    url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/${release.archive}";
    inherit (release) sha256;
  };
  # The official ARM64 Linux build is dynamic, unlike the x86_64 static zip.
  nativeBuildInputs = [ unzip ] ++ lib.optional dynamicArmLinux autoPatchelfHook;
  buildInputs = lib.optional dynamicArmLinux zlib;
  dontUnpack = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    unzip "$src" -d unpacked
    install -Dm755 unpacked/eca "$out/bin/eca"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/eca" --version | grep -F '${version}'
    runHook postInstallCheck
  '';
  meta = {
    description = "Editor Code Assistant server (pinned official native release)";
    homepage = "https://eca.dev";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames releases;
    mainProgram = "eca";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
