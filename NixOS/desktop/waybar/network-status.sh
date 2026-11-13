# Bar label: wired shows wired, wireless shows a live signal-strength icon.
NMCLI=@NMCLI@
AWK=@AWK@

wired=$($NMCLI -t -f DEVICE,TYPE,STATE device status |
  $AWK -F: '$2=="ethernet" && $3=="connected" {print $1; exit}')
if [ -n "$wired" ]; then
  printf '󰈀 %s\n' "$wired"
  exit 0
fi

wifi=$($NMCLI -t -f DEVICE,TYPE,STATE device status |
  $AWK -F: '$2=="wifi" && $3=="connected" {print $1; exit}')
if [ -n "$wifi" ]; then
  signal=$($NMCLI -t -f IN-USE,SIGNAL device wifi |
    $AWK -F: '$1=="*" {print $2; exit}')
  [ -z "$signal" ] && signal=0
  if [ "$signal" -ge 75 ]; then icon=󰤨
  elif [ "$signal" -ge 50 ]; then icon=󰤥
  elif [ "$signal" -ge 25 ]; then icon=󰤢
  else icon=󰤟
  fi
  printf '%s %s%%\n' "$icon" "$signal"
  exit 0
fi

printf '󰖪\n'
