{ pkgs }:
let
  fonts = import ../System/Common/desktop/font-policy.nix;
  cjk = pkgs.callPackage ../pkgs/tsanger-jinkai { };
  latin = pkgs.callPackage ../pkgs/monolisa-nasy { };
  emoji = pkgs.noto-fonts-color-emoji;
  rules = (import ../System/Common/desktop/fontconfig-policy.nix { inherit (pkgs) lib; }).rules;
  moduleConf = (import ../NixOS/desktop/fonts.nix { inherit pkgs; inherit (pkgs) lib; }).fonts.fontconfig.localConf;
  conf = pkgs.writeText "desktop-font-regression.conf" ''
    <?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>
    <dir>${latin}/share/fonts/truetype</dir>
    <dir>${cjk}/share/fonts/truetype</dir>
    <dir>${emoji}/share/fonts</dir>
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
    export MODULE_FC_CONF=${pkgs.writeText "module-fc-local.conf" moduleConf}
    python3 - ${cjk} ${latin} <<'PY'
    import base64, hashlib, os, pathlib, subprocess, sys
    from xml.dom import minidom
    from fontTools.ttLib import TTFont
    # The NixOS module writes localConf verbatim: it must be one well-formed
    # document, or fontconfig silently drops every rule after the first root.
    doc = minidom.parse(os.environ['MODULE_FC_CONF'])
    assert doc.documentElement.tagName == 'fontconfig'
    assert len([n for n in doc.documentElement.childNodes if n.nodeType == n.ELEMENT_NODE]) >= 4
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
    for spec in [':charset=20e3', ':charset=1f600', 'sans:charset=1f004', 'mono:charset=1f21a']:
      file, ps = match(spec)
      assert 'NotoColorEmoji' in file, (spec, file, ps)
    print('PASS: vendor bytes unchanged; CJK regular/bold + simplified/traditional + Latin + color-emoji matching.')
    PY
    touch "$out"
  ''
