{ lib, pkgs, ... }:
let
  registry = builtins.fromJSON (builtins.readFile ./security-keys/credentials.json);
  ids = map (key: key.id) registry.keys;
  credentials = map (key: key.credential) registry.keys;
  mapping = pkgs.writeText "flakes-public-u2f-keys" (
    registry.user + ":" + lib.concatStringsSep ":" credentials + "\n"
  );
in
{
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
  # This file intentionally contains public credentials only. The immutable,
  # root-owned store file prevents an unprivileged process adding a sudo key.
  environment.etc."security/flakes-u2f-keys".source = mapping;
  security.pam.u2f.settings = {
    authfile = "/etc/security/flakes-u2f-keys";
    origin = registry.origin;
    appid = registry.origin;
    userpresence = 1;
    pinverification = 0;
    userverification = 0;
    cue = true;
  };
  # Do not globally enable U2F: SSH, login and unrelated PAM consumers are not
  # part of this policy. Missing/unrecognized keys fall through to pam_unix.
  security.pam.services = lib.genAttrs [ "sudo" "sudo-i" ] (_: {
    u2f = {
      enable = true;
      control = "sufficient";
    };
  });
}
