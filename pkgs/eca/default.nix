{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
let
  version = "0.171.1";
  releases = {
    aarch64-darwin = {
      archive = "eca-native-macos-aarch64.zip";
      sha256 = "fd6c7fae0f3c267452799572acbd443ad474d2e874919e08fd62eb106dbce0cd";
    };
    x86_64-linux = {
      archive = "eca-native-static-linux-amd64.zip";
      sha256 = "3a897cb46bc13d5cab16d43542ecc13035bb77a703e084435c2c650c7c501cfd";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "eca";
  inherit version;
  src = fetchurl {
    url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/${release.archive}";
    inherit (release) sha256;
  };
  nativeBuildInputs = [ unzip ];
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
