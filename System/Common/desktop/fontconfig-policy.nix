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
          <family>${fonts.latin}</family><family>${fonts.cjk}</family><family>Noto Color Emoji</family>
        </prefer></alias>
      '')
      [
        "sans"
        "sans-serif"
        "serif"
        "monospace"
      ]
  + ''
    <!-- Color emoji: append to the prefer chain so any glyph fallback keeps
         the color face ahead of monochrome symbol fonts. The contains test has
         subset semantics, so family-less queries need single-codepoint rules. -->
    <match target="pattern">
      <test name="charset" compare="contains"><charset><int>0x20e3</int></charset></test>
      <edit name="family" mode="prepend" binding="strong"><string>Noto Color Emoji</string></edit>
    </match>
    <match target="pattern">
      <test name="charset" compare="contains"><charset><int>0xfe0f</int></charset></test>
      <edit name="family" mode="prepend" binding="strong"><string>Noto Color Emoji</string></edit>
    </match>
    <match target="pattern">
      <test name="charset" compare="contains"><charset><int>0x1f004</int></charset></test>
      <edit name="family" mode="prepend" binding="strong"><string>Noto Color Emoji</string></edit>
    </match>
    <match target="pattern">
      <test name="charset" compare="contains"><charset><int>0x1f21a</int></charset></test>
      <edit name="family" mode="prepend" binding="strong"><string>Noto Color Emoji</string></edit>
    </match>
  '';
}
