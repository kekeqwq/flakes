{
  lib,
  runCommand,
  python3,
  lxgw-wenkai,
}:
runCommand "wenkai-mono-terminal-${lxgw-wenkai.version}"
  {
    nativeBuildInputs = [ (python3.withPackages (ps: [ ps.fonttools ])) ];
    meta = {
      description = "Unmodified WenKai Mono Medium outlines in a dedicated regular-slot CJK family";
      license = lib.licenses.ofl;
    };
  }
  ''
    mkdir -p "$out/share/fonts/truetype"
    python3 ${./prepare.py} \
      ${lxgw-wenkai}/share/fonts/truetype/LXGWWenKaiMono-Medium.ttf \
      "$out/share/fonts/truetype/KekeCJKTerminal-Regular.ttf"
    python3 ${./prepare.py} \
      ${lxgw-wenkai}/share/fonts/truetype/LXGWWenKaiMono-Medium.ttf \
      "$TMPDIR/repro.ttf"
    cmp "$out/share/fonts/truetype/KekeCJKTerminal-Regular.ttf" "$TMPDIR/repro.ttf"
  ''
