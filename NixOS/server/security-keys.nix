{ lib, pkgs, ... }:
let
  shared = import ../../System/Common/security-keys { inherit lib pkgs; };
  inherit (shared) registry mapping;
in
{
  assertions = shared.assertions;
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
