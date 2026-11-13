# Idle, powered-off, or the number of connected devices.
BLUETOOTHCTL=@BLUETOOTHCTL@
AWK=@AWK@

state=$($BLUETOOTHCTL show 2>/dev/null | $AWK -F': ' '/Powered/ {print $2}')
if [ "$state" != "yes" ]; then
  printf '󰂲\n'
  exit 0
fi
count=$($BLUETOOTHCTL devices Connected 2>/dev/null | $AWK '/^Device/ {n++} END {print n+0}')
if [ "$count" -gt 0 ]; then
  printf '󰂱 %s\n' "$count"
else
  printf '󰂯\n'
fi
