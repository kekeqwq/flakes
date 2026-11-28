{
  config,
  lib,
  pkgs,
  ...
}:
let
  peer = "100.75.211.82";
  subnet = "192.168.2.0/24";
  tailscale = lib.getExe' config.services.tailscale.package "tailscale";
  jq = lib.getExe pkgs.jq;
  repair = pkgs.writeShellScript "tailscale-subnet-route-check" ''
    set -eu

    # Do not change preferences while logged out or when the peer no longer
    # advertises the approved route.
    if ! ${tailscale} status --json | ${jq} -e --arg peer ${peer} --arg subnet ${subnet} '
      .BackendState == "Running" and any(.Peer[]?;
        ((.TailscaleIPs // []) | index($peer)) != null and
        ((.PrimaryRoutes // []) | index($subnet)) != null)
    ' >/dev/null; then
      exit 0
    fi

    route_field() {
      /usr/bin/awk -v key="$1:" '$1 == key { print $2; exit }'
    }

    # Discover the Tailscale interface from its peer's explicit /32, not a
    # default route (which may point at another VPN's utun).
    peer_route=$(/sbin/route -n get ${peer}/32 2>/dev/null) || exit 0
    tunnel=$(route_field interface <<< "$peer_route")
    case "$tunnel" in utun[0-9]*) ;; *) exit 0 ;; esac
    [ "$(route_field destination <<< "$peer_route")" = ${peer} ] || exit 0
    [ "$(route_field mask <<< "$peer_route")" = 255.255.255.255 ] || exit 0

    # Query the prefix rather than a host, which may have a cloned /32.
    subnet_route=$(/sbin/route -n get ${subnet} 2>/dev/null) || subnet_route=""
    if [ "$(route_field interface <<< "$subnet_route")" = "$tunnel" ] &&
       [ "$(route_field destination <<< "$subnet_route")" = 192.168.2.0 ] &&
       [ "$(route_field mask <<< "$subnet_route")" = 255.255.255.0 ]; then
      exit 0
    fi

    # Respect an intentional opt-out; repair a missing route, not a disabled policy.
    ${tailscale} debug prefs | ${jq} -e '.RouteAll == true' >/dev/null || exit 0
    echo "Refreshing missing Tailscale route for ${subnet} on $tunnel"
    ${tailscale} set --accept-routes=false
    /bin/sleep 1
    ${tailscale} set --accept-routes=true || ${tailscale} set --accept-routes=true
  '';
in
{
  launchd.daemons.tailscale-subnet-route-check = lib.mkIf config.services.tailscale.enable {
    serviceConfig = {
      # Launch Apple's interpreter directly instead of asking launchd to
      # spawn the Nix-store script as an executable.
      Program = "/bin/bash";
      ProgramArguments = [
        "/bin/bash"
        "${repair}"
      ];
      RunAtLoad = true;
      StartInterval = 60;
      StandardOutPath = "/var/log/tailscale-subnet-route-check.log";
      StandardErrorPath = "/var/log/tailscale-subnet-route-check.log";
    };
  };
}
