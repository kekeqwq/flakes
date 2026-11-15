{
  runCommand,
  python3,
  nixos-icons,
  wallpaper,
}:
runCommand "keke-plymouth-theme"
  { nativeBuildInputs = [ (python3.withPackages (p: [ p.pillow ])) ]; }
  ''
    theme="$out/share/plymouth/themes/keke"
    mkdir -p "$theme"
    cp ${./keke.script} "$theme/keke.script"
    cp ${wallpaper} "$theme/background.png"
    cp ${nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake-white.png "$theme/logo.png"
    chmod u+w "$theme"/*.png
    python3 ${./assets.py} "$theme"
    cat > "$theme/keke.plymouth" <<EOF
    [Plymouth Theme]
    Name=Keke
    Description=Quiet desktop boot and native disk-key prompt
    ModuleName=script

    [script]
    ImageDir=$theme
    ScriptFile=$theme/keke.script
    EOF
  ''
