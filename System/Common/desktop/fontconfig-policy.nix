{ lib }:
let
  fonts = import ./font-policy.nix;
  defaults = [
    fonts.latin
    fonts.cjk
  ];
in
{
  defaultFonts = {
    sansSerif = defaults;
    serif = defaults;
    monospace = defaults;
  };
  # Strong bindings prevent retained legacy fonts' wider lang coverage from
  # overriding Chinese selection. Fontconfig also normalizes sans-serif to sans.
  rules = ''
    <match target="scan">
      <test name="postscriptname" compare="eq"><string>${fonts.cjkBoldPostscript}</string></test>
      <edit name="weight" mode="assign"><const>bold</const></edit>
    </match>
  ''
  +
    lib.concatMapStringsSep "\n"
      (generic: ''
        <alias binding="strong"><family>${generic}</family><prefer>
          <family>${fonts.latin}</family><family>${fonts.cjk}</family>
        </prefer></alias>
      '')
      [
        "sans"
        "sans-serif"
        "serif"
        "monospace"
      ]
  + ''
    <!-- Color emoji first: face order would otherwise let symbols fonts win
         monochrome glyphs for emoji codepoints and keycap components. -->
    <match target="pattern">
      <test name="charset" compare="contains"><range><int>0x20e3</int><int>0x20e3</int></range></test>
      <edit name="family" mode="prepend"><string>Noto Color Emoji</string></edit>
    </match>
    <match target="pattern">
      <test name="charset" compare="contains"><range><int>0x1f000</int><int>0x1faff</int></range></test>
      <edit name="family" mode="prepend"><string>Noto Color Emoji</string></edit>
    </match>
  '';
}
