#!/usr/bin/env bash
# DESTRUCTIVE: opt-in, completely blank /dev/vda in a NEW QEMU guest only.
# Never imported by a rebuild. Secrets stay on a private FD or local terminal.
set +x
set -euo pipefail
umask 077
if [[ ${1:-} != --erase-fresh-qemu-vda ]]; then
  echo 'Usage: partition-and-mount.sh --erase-fresh-qemu-vda [--key-fd N]' >&2
  exit 2
fi
shift
key_fd=
if [[ $# == 2 && $1 == --key-fd && $2 =~ ^[0-9]+$ ]]; then
  key_fd=$2
elif [[ $# != 0 ]]; then
  echo 'Unexpected arguments; refusing to touch any disk' >&2
  exit 2
fi
[[ $(id -u) == 0 ]]
[[ $(systemd-detect-virt --vm) == qemu ]]
[[ -d /sys/firmware/efi ]]
[[ -b /dev/vda ]]
[[ $(lsblk -dnro TYPE /dev/vda) == disk ]]
[[ -z $(wipefs --noheadings --output TYPE /dev/vda) ]]
! lsblk --noheadings --raw --output TYPE /dev/vda | grep -Fxq part
[[ -z $(lsblk -nr -o MOUNTPOINT /dev/vda | tr -d '[:space:]') ]]
! mountpoint -q /mnt
[[ ! -e /dev/mapper/cryptroot ]]
[[ ! -e /dev/disk/by-label/SECRETEFI ]]
[[ ! -e /dev/disk/by-partlabel/secret-lab-cryptroot ]]
[[ ! -e /mnt/etc/NIXOS ]]
trap 'unset key confirmation' EXIT
if [[ -n $key_fd ]]; then
  IFS= read -r -s -u "$key_fd" key
else
  IFS= read -r -s -p 'New LUKS recovery password (12+ characters): ' key </dev/tty
  printf '\n' >/dev/tty
  IFS= read -r -s -p 'Repeat recovery password: ' confirmation </dev/tty
  printf '\n' >/dev/tty
  [[ $key == "$confirmation" ]]
  unset confirmation
fi
[[ ${#key} -ge 12 ]]

parted --script /dev/vda -- mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB set 1 esp on \
  mkpart secret-lab-cryptroot 1025MiB 100%
udevadm settle
mkfs.fat -F 32 -n SECRETEFI /dev/vda1
# The explicit blank-QEMU guard authorizes this one format, never an existing
# LUKS header. There is no --wipe-slot, token enrollment or hardware-key reset.
printf '%s' "$key" | cryptsetup luksFormat --type luks2 --pbkdf argon2id \
  --label secret-lab-luks --batch-mode --key-file - /dev/vda2
printf '%s' "$key" | cryptsetup open --key-file - /dev/vda2 cryptroot
unset key
mkfs.btrfs -L secret-lab-root /dev/mapper/cryptroot
mkdir -p /mnt
mount -o compress=zstd:3,noatime /dev/mapper/cryptroot /mnt
for subvolume in root nix home; do
  btrfs subvolume create "/mnt/@$subvolume"
done
umount /mnt
mount -o subvol=@root,compress=zstd:3,noatime /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{nix,home,boot}
for subvolume in nix home; do
  mount -o "subvol=@$subvolume,compress=zstd:3,noatime" /dev/mapper/cryptroot "/mnt/$subvolume"
done
mount -o umask=0077 /dev/disk/by-label/SECRETEFI /mnt/boot
printf '%s\n' 'LUKS2 + Btrfs zstd mounted. Recovery password retained; FIDO2 enrollment is a separate, physical operation.'
findmnt -R /mnt -o TARGET,FSTYPE,OPTIONS
