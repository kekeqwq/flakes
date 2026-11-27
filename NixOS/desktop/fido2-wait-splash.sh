# Observe native cryptsetup; never open the device or consume a password request.
export LC_ALL=C
unit=$(systemd-escape --template=systemd-cryptsetup@.service -- "$1")
wait_ms=$(( $2 * 1000 ))
shown=
clear_message() {
  if [[ -n $shown ]]; then
    plymouth hide-message --text="$shown" >/dev/null 2>&1 || true
    shown=
  fi
}
trap clear_message EXIT
trap 'exit 0' TERM INT

stamp='^\[[[:space:]]*([0-9]+)\.([0-9]{3})[0-9]+\]'
while :; do
  started=
  authenticating=0
  while IFS= read -r line; do
    case "$line" in
      *'Asking FIDO2 token for authentication.'*|*'Timed out waiting for security device,'*|*'Finished Cryptography Setup'*|*'Failed to start Cryptography Setup'*)
        authenticating=1 ;;
      *'Security token not present for unlocking volume '*)
        if [[ $line =~ $stamp ]]; then
          started=$((10#${BASH_REMATCH[1]} * 1000 + 10#${BASH_REMATCH[2]}))
        fi ;;
    esac
  done < <(journalctl -b -u "$unit" --no-pager -o short-monotonic 2>/dev/null)
  (( ! authenticating )) || exit 0
  if [[ -n $started ]]; then
    IFS='. ' read -r sec cs _ </proc/uptime
    elapsed_ms=$((10#$sec * 1000 + 10#$cs * 10 - started))
    left_ms=$((wait_ms - elapsed_ms))
    (( left_ms > 0 )) || exit 0
    # Avoid a countdown flash while the already plugged-in USB device is
    # enumerating. The native discovery deadline and touch prompt don't move.
    if (( elapsed_ms < 750 )); then
      sleep 0.2
      continue
    fi
    msg="Waiting for key… $(((left_ms + 999) / 1000)) s"
    if [[ $msg != "$shown" ]]; then
      clear_message
      if plymouth display-message --text="$msg" >/dev/null 2>&1; then
        shown=$msg
      fi
    fi
  fi
  sleep 0.2
done
