{ pkgs, lib, ... }:
{
  # Mesh VPN client on both platforms. No account, auth key or login state is
  # managed here: `sudo tailscale up` is instance-private; the `tailscale set`
  # preference `--accept-routes` lives in the same persistent daemon state and
  # is how this client reaches LAN subnets advertised by the router. The shared option
  # maps to nix-darwin's launchd daemon or NixOS' systemd service. Do not
  # install the App Store GUI client alongside this daemon.
  services.tailscale = {
    enable = true;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    # Plain client, not a subnet router or exit node. Opening the UDP port
    # keeps peer-to-peer links possible.
    openFirewall = true;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    # Leave system DNS to Surge. MagicDNS names still resolve through the
    # module's scoped /etc/resolver/ts.net entry; the local Surge profile
    # excludes 100.64.0.0/10 from its TUN so that resolver traffic is direct.
    overrideLocalDns = false;
  };
}
