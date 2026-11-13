# Capacity and charging state from sysfs; Waybar adds warning classes.
SYS=/sys/class/power_supply
if [ -r "$SYS/BAT0/capacity" ]; then
  bat="$SYS/BAT0"
elif [ -r "$SYS/BAT1/capacity" ]; then
  bat="$SYS/BAT1"
else
  exit 0
fi
level=$(cat "$bat/capacity")
status=$(cat "$bat/status" 2>/dev/null || echo Unknown)
if [ "$status" = "Charging" ]; then icon=󰂄
elif [ "$level" -ge 90 ]; then icon=󱊣
elif [ "$level" -ge 60 ]; then icon=󱊢
elif [ "$level" -ge 30 ]; then icon=󱊡
else icon=󰁺
fi
printf '%s %s%%\n' "$icon" "$level"
