# macOS Key-first sudo rollout

## Current stage: built / isolated module verified; live sudo deployment pending

- Shared registry moved byte-for-byte to `System/Common/security-keys/credentials.json`.
  No credentials added, regenerated or reenrolled. RP/AppID remains `pam://keke-flakes`.
- Order: optional pam_reattach, sufficient pam_u2f, sufficient native pam_tid;
  macOS's original required OpenDirectory password path is unchanged.
- No `nodetect`, `nouserok`, `alwaysok`, PIN/UV requirement, parallel broker or
  custom keyboard listener. Esc during Key wait is not promised. No usable Key
  falls through to Touch ID; cancelling native Touch ID retains password fallback.
- The cached Darwin pam-u2f 1.4.0 linked a second Nix OpenPAM. A small immutable
  adapter changes that dependency to `/usr/lib/libpam.2.dylib`, re-signs ad-hoc,
  and verifies linkage. Required native PAM symbols exist. Apple codesign strict
  verification and an actual Apple-PAM-handle module invocation passed.
- Raw isolated no-Key test: PAM result 9, pam_end 0, no secret prompt, 2.485 s.
  This correctly denies that module's authentication, permitting a sufficient
  rule to fall through; it is not a Touch ID or sudo acceptance result.
- Owner carries only the secondary Key. Read-only ykman identification matched
  serial **15490313**. Raw signature test: PAM result 0, pam_end 0, touch only,
  no PIN/password prompt or input, 4.663 s including owner response.
  No privileged command ran; this is not yet a successful sudo test.
- Primary **20452713** is not physically available on this Mac; Mac acceptance
  remains pending. Do not substitute a second test of the secondary for it.
- Full Darwin system and `checks.aarch64-darwin.sudo-touchid` built successfully.
  Full Deck system evaluation succeeded. Linux rebuild/boundary execution is
  not claimed here; no connection to powered-off Deck was attempted.

## Narrow deployment

`macOS/private/sudo-key-deployment.nix` builds an immutable local installer.
It requires existing administrator authorization, refuses an unrecognized
sudo_local hash, confirms native password fallback, saves root-only original
and content backups, adds a unique system GC root without removing the previous
Touch-ID root, and atomically replaces only `/etc/pam.d/sudo_local`.
It verifies `/etc/pam.d/sudo` was not changed. It does not activate Darwin,
Home Manager, Homebrew, launchd, screen-lock rules or any hardware credentials.

Run from the owner's local terminal because earlier agent-originated PAM writes
were denied by macOS System Policy. Do not disable SIP or bypass that policy.
Keep an authenticated administrator terminal available through acceptance.
The installed fingerprint/password policy authorizes this first installation;
the new Key cannot authorize sudo until its module has actually been deployed.

## Remaining acceptance

1. Read back installed owner/mode/hash and unchanged macOS password stack.
2. Secondary-only actual fresh sudo: touch Key, no fingerprint/PIN/password,
   only privileged command `true`; ignore sudo cache.
3. No Key: native Touch ID authenticates a fresh sudo.
4. No Key: Esc from native fingerprint dialog reaches password; owner privately
   tests correct password in a local terminal. Never relay the password to tools.
5. Primary-only actual sudo when available; errors/timeouts must not grant access.

The native macOS lock screen and PIV/OTP/OpenPGP state are not modified. LUKS
registration is independent. Do not claim the rollout complete before the live
acceptance checks.
