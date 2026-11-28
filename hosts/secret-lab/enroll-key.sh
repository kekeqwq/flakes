#!/usr/bin/env bash
# Private per-volume enrollment in the fresh QEMU guest, never at rebuild time.
# The selected hidraw device must already be physically approved by the owner.
set +x
set -euo pipefail
umask 077
if [[ $# != 4 || $1 != --fido2-device || ! $2 =~ ^/dev/hidraw[0-9]+$ || $3 != --label || ! $4 =~ ^[a-zA-Z0-9_-]+$ ]]; then
	echo 'Usage: enroll-key.sh --fido2-device /dev/hidrawN --label primary|secondary' >&2
	exit 2
fi
hidraw=$2
label=$4
device=/dev/disk/by-partlabel/secret-lab-cryptroot
[[ $(id -u) == 0 ]]
case $(systemd-detect-virt --vm) in qemu | kvm) ;; *) exit 1 ;; esac
[[ $(</sys/class/dmi/id/sys_vendor) == QEMU ]]
[[ -c $hidraw ]]
cryptsetup isLuks --type luks2 "$device"
# Password slot 0 is deliberately retained by the fresh-volume installer.
# Test it independently before any token changes. Never accept insertion as proof.
cryptsetup open --test-passphrase --key-slot 0 "$device"
if mountpoint -q /mnt; then
	[[ $(findmnt -nro FSTYPE /mnt) == btrfs ]]
	backup_root=/mnt/var/backups/flakes-luks
else
	[[ $(findmnt -nro FSTYPE /) == btrfs ]]
	backup_root=/var/backups/flakes-luks
fi
mkdir -p "$backup_root"
chmod 0700 "$backup_root"
uuid=$(cryptsetup luksUUID "$device")
backup=$(mktemp -d "$backup_root/$uuid-$label-XXXXXXXX")
cryptsetup luksHeaderBackup "$device" --header-backup-file "$backup/before.header"
chmod 0600 "$backup/before.header"
cryptsetup luksDump --dump-json-metadata "$device" | python3 -c '
import json,sys
m=json.load(sys.stdin)
assert "0" in m["keyslots"]
assert not any("0" in t.get("keyslots",[]) for t in m.get("tokens",{}).values())
json.dump(sorted(m["keyslots"]),sys.stdout)
' >"$backup/before-slots.json"
printf '%s\n' "Ready to enroll the owner-designated $label Key. Touch ONLY when its LED flashes; a second touch may be requested during enrollment."
# No PIN reset/guess, OTP/PIV/OpenPGP change, or removal of existing slots.
# Native local password input is not logged, placed in argv or put in the store.
systemd-cryptenroll "$device" --fido2-device="$hidraw" \
	--fido2-with-client-pin=no --fido2-with-user-presence=yes \
	--fido2-with-user-verification=no
cryptsetup luksDump --dump-json-metadata "$device" | python3 -c '
import json,sys
from pathlib import Path
backup,label,uuid=sys.argv[1:]
m=json.load(sys.stdin)
before=set(json.loads((Path(backup)/"before-slots.json").read_text()))
after=set(m["keyslots"])
assert before <= after and "0" in after, "An existing slot disappeared"
new=after-before
assert len(new)==1, "Expected exactly one new slot; inspect privately"
tokens={i:t for i,t in m.get("tokens",{}).items() if new.intersection(t.get("keyslots",[]))}
assert len(tokens)==1
for t in tokens.values():
 assert t["type"]=="systemd-fido2"
 assert t["fido2-clientPin-required"] is False
 assert t["fido2-up-required"] is True
 assert t["fido2-uv-required"] is False
json.dump({"volume":uuid,"label":label,"added_slots":sorted(new),"token_ids":list(tokens)},sys.stdout,indent=2)
' "$backup" "$label" "$uuid" >"$backup/inventory.json"
cryptsetup luksHeaderBackup "$device" --header-backup-file "$backup/after.header"
chmod 0600 "$backup/after.header"
printf '%s\n' "Enrollment recorded privately in $backup. Export these backups privately OFF this virtual disk."
printf '%s\n' 'Enrollment is not a cold-boot acceptance test. Next verify touch-only unlock and password fallback separately.'
