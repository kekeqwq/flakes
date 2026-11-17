# Build explicitly; not included in system packages, avoiding a system cycle.
{ pkgs, darwin }:
let
  lib = pkgs.lib;
  cfg = darwin.config;
  source = cfg.environment.etc."pam.d/sudo_local".source;
  known = lib.concatStringsSep " " cfg.environment.etc."pam.d/sudo_local".knownSha256Hashes;
  module = import ./pam-u2f.nix { inherit pkgs; };
in
pkgs.writeShellScriptBin "flakes-install-sudo-keys" ''
  set -euo pipefail
  export PATH=/usr/bin:/bin:/usr/sbin:/sbin
  if [ "$(id -u)" != 0 ]; then
    echo 'Run this immutable installer with sudo from your own local terminal.' >&2
    exit 1
  fi
  target=/etc/pam.d/sudo_local
  source=${source}
  test -f "$target"
  grep -Eq '^auth[[:space:]]+include[[:space:]]+sudo_local([[:space:]]|$)' /etc/pam.d/sudo
  grep -Eq '^auth[[:space:]]+required[[:space:]]+pam_opendirectory\.so([[:space:]]|$)' /etc/pam.d/sudo
  old=$(shasum -a 256 "$target" | awk '{print $1}')
  case ' ${known} ' in
    *" $old "*) ;;
    *) echo 'Unrecognized sudo_local: stop and review; no file overwritten.' >&2; exit 1 ;;
  esac
  /usr/bin/codesign --verify --strict ${module}/lib/security/pam_u2f.so
  if cmp -s "$target" "$source"; then
    echo 'This exact sudo policy is already installed.'
    exit 0
  fi
  stamp=$(date +%Y%m%d-%H%M%S)-$$
  backup="/var/root/flakes-pam-backups/$stamp-sudo-keys"
  umask 077
  mkdir -p "$backup"
  chmod 700 "$backup"
  cp -pP "$target" "$backup/sudo_local.original"
  cp -pL "$target" "$backup/sudo_local.content"
  cp -p /etc/pam.d/sudo "$backup/apple-sudo.reference"
  printf '%s\n' "$old" > "$backup/sudo_local.sha256"
  main_before=$(shasum -a 256 /etc/pam.d/sudo | awk '{print $1}')
  # Retain every deployment, and leave the previous Touch-ID GC root intact.
  mkdir -p /nix/var/nix/gcroots
  ln -s ${darwin.system} "/nix/var/nix/gcroots/flakes-macos-sudo-keys-$stamp"
  temporary=$(mktemp /etc/pam.d/.sudo_local-flakes.XXXXXX)
  trap 'rm -f "$temporary"' EXIT
  install -o root -g wheel -m 644 "$source" "$temporary"
  mv -f "$temporary" "$target"
  cmp -s "$target" "$source"
  test "$(stat -f '%u:%g:%Lp' "$target")" = '0:0:644'
  test "$(shasum -a 256 /etc/pam.d/sudo | awk '{print $1}')" = "$main_before"
  printf 'Installed only sudo_local. Backup: %s\n' "$backup"
  echo 'Keep an authenticated administrator terminal open until Key, Touch ID and password fallback tests finish.'
  echo 'No lock-screen policy, account password, Key credential or full Darwin activation changed.'
''
