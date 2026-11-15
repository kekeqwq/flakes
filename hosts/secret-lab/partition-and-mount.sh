#!/usr/bin/env bash
# DESTRUCTIVE, opt-in fresh-VM installer only. Never imported by a rebuild.
# Passphrase is read silently from /dev/tty, or from a private FD with --key-fd N.
set -euo pipefail
if [[ ${1:-} != --erase-fresh-qemu-vda ]]; then
  echo 'Usage: partition-and-mount.sh --erase-fresh-qemu-vda [--key-fd N]' >&2
  exit 2
fi
shift
[[ $(id -u) == 0 ]]
[[ $(systemd-detect-virt --vm) == qemu ]]
[[ -b /dev/vda ]]
[[ -z $(wipefs --noheadings --output TYPE /dev/vda) ]]
! lsblk --noheadings --raw --output TYPE /dev/vda | grep -Fxq part
# Refuse any mounted vda filesystem, an installed root, or an existing pool.
! findmnt -rn -S /dev/vda1 >/dev/null
! findmnt -rn -S /dev/vda2 >/dev/null
! zpool list -H -o name 2>/dev/null | grep -Fxq secret-lab
[[ ! -e /dev/disk/by-label/SECRETEFI ]]
[[ ! -e /mnt/etc/NIXOS ]]
if [[ ${1:-} == --key-fd && ${2:-} =~ ^[0-9]+$ ]]; then
  IFS= read -r -s -u "$2" key
else
  IFS= read -r -s -p 'New ZFS passphrase (8+ characters): ' key </dev/tty
  printf '\n' >/dev/tty
fi
[[ ${#key} -ge 8 ]]

parted --script /dev/vda -- mklabel gpt mkpart ESP fat32 1MiB 1025MiB set 1 esp on mkpart primary 1025MiB 100%
udevadm settle
mkfs.fat -F 32 -n SECRETEFI /dev/vda1
zpool create -f -R /mnt -o ashift=12 \
  -O mountpoint=none -O canmount=off -O compression=zstd -O atime=off \
  -O acltype=posixacl -O xattr=sa -O normalization=formD \
  secret-lab /dev/vda2
printf '%s\n' "$key" | zfs create -o encryption=aes-256-gcm \
  -o keyformat=passphrase -o keylocation=prompt -o mountpoint=none \
  -o canmount=off secret-lab/secure
unset key
for dataset in nixos nix home; do
  zfs create -o canmount=noauto -o mountpoint=legacy "secret-lab/secure/$dataset"
done
zpool set bootfs=secret-lab/secure/nixos secret-lab
mkdir -p /mnt
mount -t zfs secret-lab/secure/nixos /mnt
mkdir -p /mnt/{nix,home,boot}
mount -t zfs secret-lab/secure/nix /mnt/nix
mount -t zfs secret-lab/secure/home /mnt/home
mount /dev/disk/by-label/SECRETEFI /mnt/boot
zfs get -r encryption,encryptionroot,keyformat,keylocation,compression secret-lab
