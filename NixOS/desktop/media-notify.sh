# Called by Niri; ordinary applications can use the same notification service.
export LC_ALL=C
umask 077
runtime=${XDG_RUNTIME_DIR:?no desktop runtime directory}
exec 9>"$runtime/keke-media-notify.lock"
flock 9

case "${1:-}:${2:-}" in
  volume:up) wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
  volume:down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
  volume:mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
  mic:mute) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
  brightness:up) brightnessctl -q -c backlight set +5% ;;
  brightness:down) brightnessctl -q -c backlight --min-value=1 set 5%- ;;
  volume:show|brightness:show|mic:show) ;;
  *) exit 2 ;;
esac

case "$1" in
  brightness)
    level=$(brightnessctl -c backlight -m | awk -F, 'NR == 1 && $4 ~ /^[0-9]+%$/ {sub(/%$/, "", $4); print $4}')
    label=Brightness
    icon=display-brightness-symbolic
    ;;
  volume|mic)
    if [[ $1 == volume ]]; then
      node=@DEFAULT_AUDIO_SINK@
      label=Volume
      icon=audio-volume-high-symbolic
    else
      node=@DEFAULT_AUDIO_SOURCE@
      label=Microphone
      icon=audio-input-microphone-symbolic
    fi
    state=$(wpctl get-volume "$node")
    level=$(awk '$1 == "Volume:" && $2 ~ /^[0-9]+([.][0-9]+)?$/ {printf "%.0f", 100 * $2}' <<< "$state")
    if [[ $state == *'[MUTED]'* ]]; then
      label+=" muted"
      level=0
      if [[ $1 == volume ]]; then icon=audio-volume-muted-symbolic; fi
    fi
    ;;
esac
[[ $level =~ ^[0-9]+$ ]] || exit 0
progress=$((level > 100 ? 100 : level))

# Never reuse an ID from a previous notification daemon instance; it could
# belong to a different application's notification after a daemon restart.
notification_owner() {
  busctl --user --auto-start=no call org.freedesktop.DBus /org/freedesktop/DBus \
    org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications 2>/dev/null |
    awk -F '"' '$2 ~ /^:[0-9.]+$/ {print $2}'
}
slot="$runtime/keke-media-notify.id"
owner=$(notification_owner || true)
replace=0
if [[ -n $owner && -r $slot ]] && read -r previous previous_id < "$slot" &&
   [[ $previous == "$owner" && $previous_id =~ ^[0-9]+$ ]]; then
  replace=$previous_id
fi
if [[ $label == *' muted' ]]; then
  title=$label
else
  title="$label · $level%"
fi
if id=$(notify-send --app-name=keke-media --icon="$icon" --transient \
       --expire-time=1350 --hint="int:value:$progress" --replace-id="$replace" --print-id "$title"); then
  current=$(notification_owner || true)
  if [[ -n $current && ( -z $owner || $owner == "$current" ) && $id =~ ^[0-9]+$ ]]; then
    printf '%s %s\n' "$current" "$id" > "$slot"
  fi
fi
