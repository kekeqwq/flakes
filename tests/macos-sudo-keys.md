# macOS Key-first sudo rollout

## Current stage: local-terminal secondary-Key sudo passed; fallback acceptance pending

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
  No privileged command ran; this is not a successful sudo test.
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

## Actual deployment and failed acceptance

Owner locally installed the exact policy. Backup:
`/var/root/flakes-pam-backups/20261117-100452-8654-sudo-keys`.
Readback verified root:wheel 0644, expected bytes and SHA256
`d876b71ec9aad1b898308443bce7c865b16fc3683b96fa0c80250570b3829973`;
Apple's original sudo password route remains unchanged.

The first fresh sudo-true PTY returned 0 after 31.95 seconds with no password,
but owner explicitly confirmed using **fingerprint**, not the Key. Therefore it
is not Key acceptance. A subsequent Key-only attempt did not complete; owner
reported fingerprint-only behavior. That test's marked sudo-true process was
cancelled, not any unrelated sudo/shell or locker. The PTY fixture's timeout
cleanup was corrected to bound TERM handling before killing its own child.

Unified logs show AMFI signature assessments for the module/libfido2, including
ad-hoc/CMS warnings and AppleSystemPolicy **allowed** entries. These mixed records
are not sufficient to conclude signature rejection is the root cause.
`tests/macos-u2f-root-probe.nix` prepares a read-only module probe under existing
administrator authorization to compare native PAM handles in root vs user
processes, without changing the production stack. Its result is not a Key-granted
privilege test. No cause for the proxy-PTY difference had been established at that point.

### Owner local-terminal confirmation

Owner executed the immutable root probe through `/usr/bin/sudo` in their local
terminal. **Before** `Root module probe starting`, sudo printed `Please touch
the FIDO authenticator.` Owner explicitly confirmed there was no fingerprint
popup and touching the lit Key allowed the command to proceed. This establishes
actual local-terminal **secondary-Key sudo success**, not merely the child probe.
The command did not explicitly use `-k`; the pre-command PAM cue and owner-confirmed
physical authentication show sudo did request authentication, rather than silently
using cached approval. Do not describe it as the cache-ignored PTY fixture.

The subsequent root-process module probe also passed: PAM 0 / pam_end 0,
no password/PIN, 14.402 seconds including human response. Thus root privilege
itself does not prevent Key access. The proxy-PTY observations remain recorded,
but the earlier blanket statement that sudo only supports fingerprint is withdrawn.
Do not claim all terminal/SSH/background contexts are verified or assign an
unproven cause to the PTY difference. No further production PAM change was made.

## Owner decision: stop additional tests; observe during everyday use

Actual installed mapping was read back and matched both original credential
records exactly, with root ownership, no group/world writes and fixed RP/AppID.
No enrollment or credential replacement occurred. Owner requested both be
configured and further checks deferred to real use; do not prompt for more tests.

Installed hash/owner/mode and unchanged password stack are verified. Secondary
Key's local sudo is verified by the owner. Remaining:

1. No Key: native Touch ID authenticates a fresh local sudo.
2. No Key: Esc from native fingerprint dialog reaches password; owner privately
   tests correct password in a local terminal. Never relay the password to tools.
3. Primary-only actual sudo when available; errors/timeouts must not grant access.
4. Re-measure other terminal/proxy/SSH contexts only if requested.

The native macOS lock screen and PIV/OTP/OpenPGP state are not modified. LUKS
registration is independent. Do not claim the rollout complete before the live
acceptance checks.
