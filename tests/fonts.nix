{ pkgs }:
let
  fonts = import ../System/Common/desktop/font-policy.nix;
  cjk = pkgs.callPackage ../pkgs/tsanger-jinkai { };
  latin = pkgs.callPackage ../pkgs/monolisa-nasy { };
  rules = (import ../System/Common/desktop/fontconfig-policy.nix { inherit (pkgs) lib; }).rules;
  conf = pkgs.writeText "desktop-font-regression.conf" ''
    <?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>
    <dir>${latin}/share/fonts/truetype</dir>
    <dir>${cjk}/share/fonts/truetype</dir>
    <!-- Retained legacy bodies must not win configured CJK matching. -->
    <dir>${pkgs.lxgw-wenkai}/share/fonts/truetype</dir>
    ${rules}
    </fontconfig>
  '';
in
pkgs.runCommand "desktop-font-policy-check"
  { nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.fonttools ])) ]; }
  ''
    export FONTCONFIG_FILE=${conf}
    export XDG_CACHE_HOME="$TMPDIR/font-cache"
    export FC_MATCH=${pkgs.fontconfig.bin}/bin/fc-match
    python3 - ${cjk} ${latin} <<'PY'
    import base64, hashlib, os, pathlib, subprocess, sys
    from fontTools.ttLib import TTFont
    cjk, latin = map(pathlib.Path, sys.argv[1:])
    expected = {
      'TsangerJinKai05-W03.ttf': 'CB5iJFQ3qVm17zG9iZpdVaFyrrM/ks1cicPY4VWtfIk=',
      'TsangerJinKai05-W05.ttf': 'VYDqYXg30VXcJOv/EKhdATWs4OsT5QcMUzMNshkbP2Q=',
    }
    files = sorted((cjk/'share/fonts/truetype').glob('*.ttf'))
    assert {f.name for f in files} == set(expected)
    for file in files:
      assert base64.b64encode(hashlib.sha256(file.read_bytes()).digest()).decode() == expected[file.name], file
      font = TTFont(file)
      cmap = font.getBestCmap()
      assert all(ord(c) in cmap for c in '中文简体繁體漢字龍後發臺灣'), file
      assert 0x1f004 not in cmap and 0x1f21a not in cmap, 'Do not steal Squirrel color emoji'
      names = {n.toUnicode() for n in font['name'].names if n.nameID == 16}
      assert '${fonts.cjk}' in names
    def match(pattern):
      return subprocess.check_output([os.environ['FC_MATCH'], '--format', '%{file}\n%{postscriptname}', pattern], text=True).splitlines()
    for generic in ['sans', 'sans-serif', 'serif', 'monospace']:
      file, ps = match(generic + ':charset=0041')
      assert str(latin) in file, (generic, file, ps)
      for language, char in [('zh-cn','4e2d'), ('zh-tw','9ad4')]:
        file, ps = match(generic + ':lang=' + language + ':charset=' + char)
        assert str(cjk) in file and ps == '${fonts.cjkRegularPostscript}', (generic, file, ps)
      file, ps = match(generic + ':weight=bold:charset=4e2d')
      assert str(cjk) in file and ps == '${fonts.cjkBoldPostscript}', (file, ps)
    print('PASS: vendor bytes unchanged; CJK regular/bold + simplified/traditional + Latin matching, with legacy fonts retained.')
    PY
    touch "$out"
  ''
