# Bar label: wired shows wired, wireless shows a live signal-strength icon.
export LC_ALL=C
NMCLI=@NMCLI@
IW=@IW@
AWK=@AWK@

wired=$($NMCLI -t -f DEVICE,TYPE,STATE device status |
	$AWK -F: '$2=="ethernet" && $3=="connected" {print $1; exit}')
if [ -n "$wired" ]; then
	printf '󰈀\n'
	exit 0
fi

wifi=$($NMCLI -t -f DEVICE,TYPE,STATE device status |
	$AWK -F: '$2=="wifi" && $3=="connected" {print $1; exit}')
if [ -n "$wifi" ]; then
	# Query the associated station, not the scan result cached by NetworkManager.
	dbm=$($IW dev "$wifi" link 2>/dev/null |
		$AWK '$1=="signal:" && $2 ~ /^-[0-9]+$/ {print $2; exit}')
	if [ -n "$dbm" ]; then
		if [ "$dbm" -ge -45 ]; then
			icon=󰤨
		elif [ "$dbm" -ge -60 ]; then
			icon=󰤥
		elif [ "$dbm" -ge -72 ]; then
			icon=󰤢
		else icon=󰤟; fi
	else
		# Keep working on drivers that don't report station RSSI to this user.
		signal=$($NMCLI -t -f IN-USE,SIGNAL device wifi list ifname "$wifi" --rescan no |
			$AWK -F: '$1=="*" && $2 ~ /^[0-9]+$/ {print $2; exit}')
		if [ -z "$signal" ]; then
			icon=󰤠
		elif [ "$signal" -ge 85 ]; then
			icon=󰤨
		elif [ "$signal" -ge 65 ]; then
			icon=󰤥
		elif [ "$signal" -ge 45 ]; then
			icon=󰤢
		else icon=󰤟; fi
	fi
	printf '%s\n' "$icon"
	exit 0
fi

printf '󰖪\n'
