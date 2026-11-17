{ lib, pkgs }:
let
  registry = builtins.fromJSON (builtins.readFile ./credentials.json);
  ids = map (key: key.id) registry.keys;
  credentials = map (key: key.credential) registry.keys;
in
{
  inherit registry;
  mapping = pkgs.writeText "flakes-public-u2f-keys" (
    registry.user + ":" + lib.concatStringsSep ":" credentials + "\n"
  );
  assertions = [
    {
      assertion = registry.user == "keke" && registry.origin == "pam://keke-flakes";
      message = "The public hardware-key registry must use the shared keke relying party.";
    }
    {
      assertion =
        credentials != [ ]
        && lib.length (lib.unique ids) == lib.length ids
        && lib.length (lib.unique credentials) == lib.length credentials
        && lib.all (
          credential: builtins.match "[^:,\n]+,[^:,\n]+,es256,\\+presence" credential != null
        ) credentials;
      message = "Hardware-key records must be distinct, touch-required, PIN-free ES256 credentials.";
    }
  ];
}
