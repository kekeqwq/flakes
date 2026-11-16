#!/usr/bin/env bash
# Explicit fresh-VM test only; never called by a flake build/check/rebuild.
# USB selection is explicit bus/address, NOT vendor-based automatic enrollment.
set -euo pipefail
umask 077
mode=${1:?installer or desktop}
work=${2:?private VM directory}
: "${QEMU_ROOT:?Nix store root containing bin/qemu-system-x86_64}"
: "${OVMF_ROOT:?Nix store root containing FV/OVMF_CODE.fd}"
work=$(realpath "$work")
[[ $(stat -c %u "$work") == "$(id -u)" && $(stat -c %a "$work") == 700 ]]
# Validate media/viewing before creating even an empty disk or NVRAM file.
case "$mode" in
installer)
  [[ -f $work/installer.iso ]]
  checksum=$(sha256sum "$work/installer.iso")
  [[ ${checksum%% *} == 927b3102d3d1e2e7339803e2055c7511eb693e9869f7cc5202829341dfc0119e ]]
  ;;
desktop) [[ -f $work/installed-and-closed && ${VIEWING_CONFIRMED:-} == yes ]] ;;
*) exit 2 ;;
esac
if [[ -f $work/qemu.pid ]] && kill -0 "$(<"$work/qemu.pid")" 2>/dev/null; then
  echo 'This instance is already running' >&2
  exit 1
fi
usb=(-device qemu-xhci,id=xhci)
if [[ -n ${USB_BUS:-}${USB_ADDR:-} ]]; then
  [[ ${USB_BUS:-} =~ ^[0-9]+$ && ${USB_ADDR:-} =~ ^[0-9]+$ ]]
  node=$(printf '/dev/bus/usb/%03d/%03d' "$((10#$USB_BUS))" "$((10#$USB_ADDR))")
  [[ -c $node && -r $node && -w $node ]]
  syspath=$(udevadm info --query=path --name="$node")
  [[ $(<"/sys$syspath/idVendor") == 1050 ]]
  # Sanity check only. The owner must approve which physical Key this is.
  # Do not take a Key away from the compositor's active locker/PAM worker.
  if pgrep -x swaylock >/dev/null || pgrep -x key-auth-worker >/dev/null; then
    echo 'Unlock Deck normally before handing this Key to QEMU' >&2
    exit 1
  fi
  usb+=(-device "usb-host,id=security-key,bus=xhci.0,hostbus=$USB_BUS,hostaddr=$USB_ADDR")
fi
[[ -f $work/OVMF_VARS.fd ]] || cp "$OVMF_ROOT/FV/OVMF_VARS.fd" "$work/OVMF_VARS.fd"
chmod u+w "$work/OVMF_VARS.fd"
[[ -f $work/disk.qcow2 ]] || "$QEMU_ROOT/bin/qemu-img" create -f qcow2 "$work/disk.qcow2" 64G
case "$mode" in
installer)
  [[ -f $work/installer.iso ]]
  media=(-drive "file=$work/installer.iso,format=raw,if=ide,media=cdrom,readonly=on" -boot order=d,strict=on)
  # Installer management only, bound to host loopback. No LAN bridge/proxy.
  network=(-netdev user,id=net0,hostfwd=tcp:127.0.0.1:22323-:22 -device virtio-net-pci,netdev=net0)
  ;;
desktop)
  [[ -f $work/installed-and-closed && ${VIEWING_CONFIRMED:-} == yes ]]
  media=(-boot order=c,strict=on)
  # The installed-disk UI/crypto test has no network adapter at all.
  network=(-nic none)
  ;;
*) exit 2 ;;
esac
# Display the real VM console in Deck's existing Niri session, not Sunshine.
while IFS='=' read -r key value; do
  case "$key" in DISPLAY | WAYLAND_DISPLAY | XDG_RUNTIME_DIR) export "$key=$value" ;; esac
done < <(systemctl --user show-environment)
"$QEMU_ROOT/bin/qemu-system-x86_64" \
  -name secret-lab -machine q35,accel=kvm -cpu host -smp 4 -m 6144 \
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_ROOT/FV/OVMF_CODE.fd" \
  -drive "if=pflash,format=raw,file=$work/OVMF_VARS.fd" \
  -drive "file=$work/disk.qcow2,format=qcow2,if=virtio,discard=unmap" \
  "${media[@]}" "${network[@]}" "${usb[@]}" \
  -device virtio-vga-gl,max_outputs=1 -display gtk,gl=on \
  -device virtio-rng-pci \
  -device virtio-serial-pci \
  -chardev "socket,id=qga,path=$work/qga.sock,server=on,wait=off" \
  -device virtserialport,chardev=qga,name=org.qemu.guest_agent.0 \
  -chardev "socket,id=serial0,path=$work/serial.sock,server=on,wait=off,logfile=$work/serial.log,logappend=on" \
  -serial chardev:serial0 -qmp "unix:$work/qmp.sock,server=on,wait=off" \
  -pidfile "$work/qemu.pid" >"$work/qemu-launch.log" 2>&1
