# Opt-in diagnostic, deliberately not imported by the Darwin configuration.
{ pkgs }:
let
  observer = import ./observer.nix { inherit pkgs; };
in
pkgs.writeShellScriptBin "flakes-observe-lockscreen" ''
  set -euo pipefail
  export PATH=/usr/bin:/bin:/usr/sbin:/sbin
  test "$(id -u)" = 0 || { echo 'Run locally with sudo.' >&2; exit 1; }
  names='screensaver screensaver_aks screensaver_ctk screensaver_la screensaver_new screensaver_new_aks screensaver_new_ctk screensaver_new_la'
  expiry=/var/run/flakes-lockscreen-observer.expiry
  base=/var/root/flakes-lockscreen-observer
  module=${observer}/lib/security/observer.so
  hash() { shasum -a 256 "$1" | awk '{print $1}'; }
  restore() {
    trap - EXIT
    case "''${pending:-}" in /etc/pam.d/.flakes-observe.*) rm -f "$pending" ;; esac
    local name target current original changed tmp saved status=0
    for name in $names; do
      target="/etc/pam.d/$name"
      if ! test -f "$backup/$name" || ! test -f "$backup/$name.original" || ! test -f "$backup/$name.changed"; then
        echo "Missing recovery snapshot for $name; review $backup" >&2
        status=1; continue
      fi
      original=$(<"$backup/$name.original")
      if [ "$(hash "$backup/$name")" != "$original" ]; then
        echo "Recovery snapshot changed for $name; refusing restore" >&2
        status=1; continue
      fi
      if ! current=$(hash "$target"); then status=1; continue; fi
      changed=$(<"$backup/$name.changed")
      if [ "$current" = "$original" ] && [ "$(stat -f '%u:%g:%Lp' "$target")" = '0:0:644' ]; then continue; fi
      if [ "$current" != "$changed" ] && [ "$current" != "$original" ]; then
        echo "Not overwriting independently changed $target; review $backup" >&2
        status=1; continue
      fi
      tmp=$(mktemp /etc/pam.d/.flakes-restore.XXXXXX) || { status=1; continue; }
      if install -o root -g wheel -m 644 "$backup/$name" "$tmp" && mv -f "$tmp" "$target" && cmp -s "$target" "$backup/$name"; then
        :
      else
        rm -f "$tmp"; status=1
      fi
    done
    if test -f "$backup/expiry" && cmp -s "$expiry" "$backup/expiry"; then rm -f "$expiry"; fi
    if [ "$status" = 0 ]; then
      if test -f "$backup/gcroot-path"; then
        saved=$(<"$backup/gcroot-path")
        case "$saved" in
          /nix/var/nix/gcroots/flakes-lockscreen-observer-*)
            if test -L "$saved" && [ "$(readlink "$saved")" = '${observer}' ]; then rm -f "$saved"; fi
            ;;
        esac
      fi
      echo "Original PAM contents restored. Backup retained: $backup"
    else
      echo "Restoration needs local review. Observer expires and never grants authentication: $backup" >&2
    fi
    return "$status"
  }
  case "''${1:-}" in
    --restore)
      backup=$(${pkgs.coreutils}/bin/realpath "''${2:?backup directory required}")
      case "$backup" in "$base"/*) ;; *) exit 2 ;; esac
      test "$(stat -f '%u:%Lp' "$backup")" = '0:700'
      restore
      exit
      ;;
    --observe) ;;
    *) echo 'Usage: --observe | --restore /var/root/flakes-lockscreen-observer/RUN' >&2; exit 2 ;;
  esac
  test -t 0 || { echo 'Use a local visible administrator terminal.' >&2; exit 1; }
  test ! -e "$expiry" || { echo 'An observer state exists; review/restore it first.' >&2; exit 1; }
  /usr/bin/codesign --verify --strict "$module"
  umask 077
  install -d -o root -g wheel -m 700 "$base"
  backup=$(mktemp -d "$base/run.XXXXXX")
  chmod 700 "$backup"
  # Snapshot every policy before changing any of them. Never touch sudo/authorizationdb.
  for name in $names; do
    target="/etc/pam.d/$name"
    test -f "$target"
    test "$(stat -f '%u:%g:%Lp' "$target")" = '0:0:644'
    ! grep -Fq 'macos-lockscreen-pam-observer/lib/security/observer.so' "$target"
    cp -pL "$target" "$backup/$name"
    hash "$backup/$name" > "$backup/$name.original"
    { printf 'auth       optional       %s\n' "$module"; cat "$backup/$name"; } > "$backup/$name.probe"
    hash "$backup/$name.probe" > "$backup/$name.changed"
  done
  gcroot="/nix/var/nix/gcroots/flakes-lockscreen-observer-$(date +%s)-$$"
  ln -s ${observer} "$gcroot"
  printf '%s\n' "$gcroot" > "$backup/gcroot-path"
  trap restore EXIT
  trap 'exit 130' HUP INT TERM
  printf '%s\n' "$(( $(date +%s) + 120 ))" > "$backup/expiry"
  install -o root -g wheel -m 644 "$backup/expiry" "$expiry"
  for name in $names; do
    target="/etc/pam.d/$name"
    cmp -s "$target" "$backup/$name" || { echo 'Policy changed concurrently; restoring.' >&2; exit 1; }
    pending=$(mktemp /etc/pam.d/.flakes-observe.XXXXXX)
    install -o root -g wheel -m 644 "$backup/$name.probe" "$pending"
    mv -f "$pending" "$target"
    pending=""
  done
  echo "Observer active for two minutes. Backup: $backup"
  echo 'This does NOT enable Key unlock. Lock manually with Ctrl-Cmd-Q, wait briefly, then unlock with your ORIGINAL Touch ID/password.'
  echo 'Do not type any password into this terminal or touch the Key expecting lock-screen authentication.'
  echo 'Original auth rules remain required; observer always returns PAM_IGNORE. Ctrl-C also restores.'
  sleep 120
  restore
  /usr/bin/log show --last 3m --style compact \
    --predicate 'subsystem == "com.keke.flakes.lock-observer"'
''
