# lab (aarch64) and lab-x86

One private host file, `default.nix`, for throwaway QEMU guests. It imports
`NixOS/desktop/baseline.nix` (desktop + newest stable kernel) and adds only this
instance's disk layout, virtio output, and Sunshine settings. `flake.nix` registers it twice
so only the NixOS system differs.

Install from the minimal ISO into a disk, then boot that disk. Nothing here
formats a disk; the partition table is created during installation.

## Networking on Deck

Deck is on Wi-Fi, so a bridge is not reliable. Instead the guest keeps QEMU's
user-mode network and Deck publishes a second LAN address for it:

- Deck alias: `192.168.2.131/24` on `wlo1` (Deck itself keeps `.130`).
- QEMU binds Sunshine's ports on loopback only (`127.0.0.1:24784`, `24789`,
  `24790`, `24810` and UDP `24798`–`24810`), so Deck's own Sunshine can keep the
  standard ports on the same host.
- nftables `prerouting` DNAT rewrites traffic for `.131` to those loopback
  ports. `net.ipv4.conf.all.route_localnet` and `...wlo1.route_localnet` must be
  `1`, otherwise DNAT to loopback is dropped.
- Moonlight on the Mac adds host `192.168.2.131` and pairs with the standard
  ports; the guest's Sunshine web UI is `https://192.168.2.131:47990`.

The alias, DNAT rules, and sysctls are runtime state. Redo them after a reboot,
then boot the disk image; teardown removes the table and alias.
