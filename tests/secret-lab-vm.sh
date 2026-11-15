#!/usr/bin/env bash
# Explicit opt-in VM only; never called by a flake build/check/rebuild.
set -euo pipefail
umask 077
mode=${1:?installer or desktop}
work=${2:?private VM directory}
: "${QEMU_ROOT:?Nix store root containing bin/qemu-system-x86_64}"
: "${OVMF_ROOT:?Nix store root containing FV/OVMF_CODE.fd}"
work=$(realpath "$work")
if [[ -f $work/qemu.pid ]] && kill -0 "$(<"$work/qemu.pid")" 2>/dev/null; then
  echo 'This instance is already running' >&2
  exit 1
fi
[[ -f $work/OVMF_VARS.fd ]] || cp "$OVMF_ROOT/FV/OVMF_VARS.fd" "$work/OVMF_VARS.fd"
chmod u+w "$work/OVMF_VARS.fd"
[[ -f $work/disk.qcow2 ]] || "$QEMU_ROOT/bin/qemu-img" create -f qcow2 "$work/disk.qcow2" 64G
case "$mode" in
installer)
  [[ -f $work/installer.iso ]]
  media=(-drive "file=$work/installer.iso,format=raw,if=ide,media=cdrom,readonly=on" -boot order=d,strict=on)
  graphics=(-device virtio-vga,max_outputs=1 -display none)
  daemon=(-daemonize)
  ;;
desktop)
  # Gate: installation must finish, all mounts close, and the pool export.
  [[ -f $work/installed-and-exported ]]
  media=(-boot order=c,strict=on)
  graphics=(-device virtio-vga-gl,max_outputs=1 -display gtk,gl=on)
  daemon=()
  # Do not reuse a stale DISPLAY from a login shell. No LAN forwarding here.
  while IFS='=' read -r key value; do
    case "$key" in DISPLAY | WAYLAND_DISPLAY | XDG_RUNTIME_DIR) export "$key=$value" ;; esac
  done < <(systemctl --user show-environment)
  ;;
*) exit 2 ;;
esac
"$QEMU_ROOT/bin/qemu-system-x86_64" \
  -name secret-lab -machine q35,accel=kvm -cpu host -smp 4 -m 6144 \
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_ROOT/FV/OVMF_CODE.fd" \
  -drive "if=pflash,format=raw,file=$work/OVMF_VARS.fd" \
  -drive "file=$work/disk.qcow2,format=qcow2,if=virtio,discard=unmap" \
  "${media[@]}" "${graphics[@]}" \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:22323-:22 -device virtio-net-pci,netdev=net0 \
  -device virtio-rng-pci -vnc "unix:$work/vnc.sock" \
  -chardev "socket,id=serial0,path=$work/serial.sock,server=on,wait=off,logfile=$work/serial.log,logappend=on" \
  -serial chardev:serial0 -qmp "unix:$work/qmp.sock,server=on,wait=off" \
  -pidfile "$work/qemu.pid" "${daemon[@]}" >"$work/qemu-launch.log" 2>&1
