{ pkgs }:
let
  version = "0.69.3";
  src = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@narumitw/pi-usage/-/pi-usage-${version}.tgz";
    hash = "sha256-2SZABzSm51X+Tdr+4KDdrxXmy/jUpynbqXRg3jsjJoI=";
  };
  manifest = pkgs.runCommand "pi-usage-runtime-manifest" { } ''
    mkdir -p "$out"
    cp ${./package.json} "$out/package.json"
    cp ${./package-lock.json} "$out/package-lock.json"
  '';
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "pi-codex-usage";
  inherit version src;
  nativeBuildInputs = [
    pkgs.nodejs
    pkgs.npmHooks.npmConfigHook
  ];
  npmDeps = pkgs.fetchNpmDeps {
    src = manifest;
    hash = "sha256-MQnUPpSuBRuRoH1OSv6q9zYYN/HN4Rwq0xf6MZ/9vbs=";
  };
  npmFlags = [
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];
  # Pi supplies its own SDK modules; do not install a second copy as peers.
  postPatch = ''
    cp ${manifest}/package.json package.json
    cp ${manifest}/package-lock.json package-lock.json
    # Scope account probes and the /usage picker to Codex only. Fail the
    # build if upstream changes the adapter registry when the pin is bumped.
    substituteInPlace dist/chunks/chunk-2DO7FSTM.ts \
      --replace-fail 'return [...SUPPORTED_ADAPTERS, XAI_ADAPTER];' \
                     'return SUPPORTED_ADAPTERS.filter((adapter) => adapter.id === "openai-codex");'
  '';
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a dist node_modules package.json "$out/"
    printf '%s\n' 'export { default } from "./dist/index.ts";' > "$out/index.ts"
    runHook postInstall
  '';
}
