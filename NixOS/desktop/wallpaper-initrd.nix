{ pkgs }:
pkgs.writeShellApplication {
  name = "wallpaper-pack-initrd";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.cpio
  ];
  text = ''
    [ "$#" -eq 2 ] || exit 2
    work=$(mktemp -d)
    output=
    trap 'rm -rf -- "$work"; if [ -n "$output" ]; then rm -f -- "$output"; fi' EXIT
    output=$(mktemp "$2.XXXXXXXX")
    install -Dm644 "$1" "$work/var/lib/keke-plymouth/wallpaper.png"
    (cd "$work"; printf '%s\n' var var/lib var/lib/keke-plymouth var/lib/keke-plymouth/wallpaper.png \
      | cpio --quiet -o -H newc --owner=0:0 > "$output")
    # The ESP may be VFAT; its mount options determine permissions.
    mv -fT -- "$output" "$2"
  '';
}
