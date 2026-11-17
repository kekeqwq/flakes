# macOS native lock-screen Key investigation — 2026-11-17

**Key screen unlock is not implemented or accepted.** No new Key enrollment,
PIV/PIN/OTP changes, account pairing, native signing keys or certificates.
Sudo policy and its two existing credentials are unchanged.

## 1. Owner-operated temporary PAM observation: completed and restored

Owner confirmed a known local password and consented to a two-minute observation.
Ran immutable command from `y3gfpvrpjwbc6v1n62wngaiy3l92wc4h-flakes-observe-lockscreen`.
Owner reported successful automatic restoration, backup retained privately at
`/var/root/flakes-lockscreen-observer/run.BbRgVz`.

Readback after observation: all eight real `screensaver*` profiles have no observer
line; `/var/run/flakes-lockscreen-observer.expiry` is absent. Original native LA
profile still requires `pam_localauthentication`, `pam_aks`, and OpenDirectory
account checking. Password-oriented profile retains required OpenDirectory auth.

Minimal local unified-log timing (local +0800):

| Event | First cycle: native LA service | Second cycle: directory/password service |
| --- | --- | --- |
| loginwindow `setCGScreenLocked` | 11:58:28.481488 | 11:59:04.580246 |
| native `_authCopyRights…` request | 11:58:48.086492 | 11:59:24.746816 |
| observer PAM entry | 11:58:48.159658 `screensaver_new_la` | 11:59:24.835082 `screensaver_new` |
| root authorizationhost PID | 65105 | 65367 |
| native auth return 0 | 11:58:48.191063 | 11:59:25.020120 |

PAM entry occurred 19.678 / 20.255 seconds after secure-lock marking, after the
native authentication request, not automatically at lock establishment in these
two cycles. Native keybag unlock success was also logged for the second cycle.
These records identify service/timing, not arbitrary future path behavior or
independently captured physical fingerprint/keyboard timing.

**Decision:** do not add sufficient Key auth to these PAM profiles, remove
required LA/AKS steps, or switch authorizationdb to a legacy UI to force a result.
No pre-input automatic-touch PAM integration point was demonstrated.

## 2. Credentialless CryptoTokenKit feasibility probe

Files: `macOS/private/lockscreen/ctk-empty-{host,driver}.m` and
`ctk-empty-probe.nix`. Standalone build; not imported into Darwin activation.

The extension uses public `com.apple.ctk-tokens` / persistent-token metadata,
App Sandbox + smartcard capability and ad-hoc signing. It never creates a token
object, session, certificate, private key or successful crypto operation. Its
factory always returns nil/error. No physical token is claimed or opened.

Findings:

1. Registering the extension path alone returned 0 but PK rejected it as outside
   a recognized containing app. No SIP bypass was attempted.
2. Temporarily registering the containing app in user LaunchServices and waiting
   for discovery made the host's own driver configuration visible. An immediate
   query and one LaunchServices-launched query returned false; discovery/context
   differences remain unresolved. Exit 0 alone was not counted as registration.
3. Opt-in `--empty-instance` created one fresh UUID EMPTY configuration with
   **zero keychain items**, then removed it in `@finally`. Readback count was 0.
4. At **12:29:51.433**, native `ctkd` actually launched `ctk-empty-driver`, PID77494,
   UID/eUID501, in App Sandbox; our `Flakes empty CTK driver initialized (no
   credentials)` message confirms custom driver code executed. This is execution
   evidence, not authentication or screen-unlock evidence.
5. Because the factory intentionally returns nil, cleanup logged an attempt to
   release a nonexistent token. No successful token/session was created.
6. The exact probe extension and containing-app registration were removed;
   PlugInKit query afterward was empty. No other drivers/preferences were changed.
   OS-managed caches/container metadata may remain; no broad database cleanup.

Ad-hoc AMFI warnings did not prevent this user-scoped empty driver from executing.
This does NOT prove availability from the secure lock screen, `_securityagent`,
pre-login/FileVault, actual HID access, PIN-free interaction, account pairing,
keybag operations, or fail-closed authentication.

## 3. Non-login operation dispatch and terminal cancellation

Implemented `ctk-denial-{common.h,host.m,driver.m}` and generalized the same
standalone bundle builder with `probeKind = "denial"`. Runner:
`tests/macos-ctk-probe.py` (ordinary user only, signed immutable Nix bundle,
no existing active probe registration). No certificates or private scalars.

A public P-256 point is derived deterministically from a hashed x-coordinate;
no signing keypair is generated. SHA1 identifies the public key per CTK metadata,
not an authentication/hash-security scheme. The transient proxy explicitly has
`suitableForLogin = NO`, no decrypt/key exchange, one fixed object ID/constraint,
and no associated certificate. The backend never returns a signature or
successful authentication. Host lookups are restricted to the fresh unique token
ID and public-key identifier, with returned token ID verified before use.

Two actual integration faults were found before the successful regression:

- Provider-side `applicationTag` did not preserve the host-supplied value. Initial
  strict fixture validation rejected it and lookup returned -26276. Scope now uses
  the unique token ID/public-key hash; backend keeps its no-login, object-ID,
  public-point and operation-constraint validation. No real authorization guard
  or native required PAM step was removed.
- Returning `TKErrorCodeAuthenticationFailed` from a custom no-password operation
  caused rapid framework retries (20,496 finish callbacks in the sampled window).
  The own probe host timed out at 25 seconds. This was **not a pass**; its `@finally`
  did not run after timeout termination and one non-login proxy configuration
  remained. Exact-fixture recovery verified class/prefix, point, object and
  no-login flags and removed it; readback count returned to zero. No locker,
  authorizationhost or ctkd was killed/restarted.

Fixed this probe's terminal failure as `NO + TKErrorCodeCanceledByUser`, rather
than an invitation to retry. Runner now recovers only its known non-login fixture
on a child timeout, treats timeout as failure, excludes preceding-run log rows,
and checks actual callback counts as well as signature results.

**Final-source regression: 5 cycles, 2 attempts on the same LAContext each cycle**
(13:33:31–13:33:45, +0800). Each cycle created a fresh transient non-login instance:

- Own key lookup succeeded. The real framework invoked `begin_auth` and the custom
  `finishWithError:` without a PIN/password/biometric operation or UI permission
  (`LAContext.interactionNotAllowed = YES`).
- All **10** attempts produced **no signature**, returned terminal error -4, and
  completed in **3.042–31.082 ms**. Two matching begin/finish-cancel events per
  cycle were asserted; a preceding 10-attempt version also terminated correctly.
- No credentials were cached as successful: second attempts also reached the
  rejecting callback. Instances read back as 0, own token was no longer advertised,
  and exact PlugInKit/LaunchServices registrations were removed every cycle.
- The original empty-driver variant was rebuilt/retested successfully afterward.

This proves a no-PIN custom CTK callback plus bounded terminal cancellation in
this **user-scoped, explicitly requested, non-login** operation. It does not prove
native lock-screen auto-start, actual YubiKey/HID access, wrong-Key behavior,
password parallelism, Secure Enclave/keybag integration or real unlock.

## 4. Initial PAM-backed locked FIDO probe (historical; replaced in section 5)

Builder `probeKind = "fido"` retains the same non-login public-only object. It
copies the EXISTING shared public mapping and native-linked `pam_u2f` into the
immutable bundle. `bundle-pam.py` recursively copies fixed Nix library dependencies,
rewrites them to bundle-relative loader paths and re-signs/verifies them. No
foreign OpenPAM library, home-directory static dependency or runtime download.
Only this driver adds the public USB sandbox capability; the worker inherits its
sandbox. No macOS accessory-security preference is relaxed.

Two modes are deliberately separate:

- `--dispatch` / no hardware opt-in: the driver spawns its own **module-loader
  selfcheck**, which only dlopens the native PAM/module and checks symbols. It
  never starts a PAM handle or calls authentication. Actual sandbox selfcheck
  passed at 14:03:30, worker exit 0, cancellation 66.345 ms, no signature, all
  own instances/advertisement/registrations removed.
- `--lock-touch`: visible local terminal only, no sudo; host waits up to 90 seconds
  for native lock observation and explicitly marks this one verification request.
  Worker checks the WindowServer session dictionary, UID/eUID/name, console/login
  state and `CGSSessionScreenIsLocked == true` before PAM/HID authentication,
  repeats the check just before authentication and after return. Missing/unknown
  state closes the gate. The screen-lock key is undocumented and needs actual
  owner lock/unlock calibration on this OS; it is NOT yet an accepted production
  security boundary. No fake environment flag or distributed notification can
  supply lock state to this implementation.

The worker uses Apple PAM handles, fixed RP/AppID, UP=1/PIN=0/UV=0 and the exact
existing public authfile. All secret/PIN/password conversation requests are
rejected; no such input is collected or supplied. It never enrolls or edits a Key.
Hardware verification success STILL leads to `NO + CanceledByUser`; it cannot
produce a native signature or unlock. Native Touch ID/password remain the only
recovery/unlock paths during this test.

Supervisor waits only for its exact posix_spawn child, cancels on observed unlock
or after 20 seconds, TERM then own-child KILL after one second, and defers reaping
if still pending after two more seconds. It never targets a locker/daemon/cgroup.
The ordinary-user runner has a 135-second outer bound and fixture-specific
recovery; timeout/interruption is failure, not successful rejection.

Local unlocked gate readback: false, authentication_started=false. Negative fido
mode demonstrated `hardware_not_opted_in_no_auth` and no hardware worker. Actual
locked-state FIDO access, successful touch, no-Key/other-Key and unlock-during-wait
behavior are **pending owner operation**. No new native private key/certificate or
account pairing has been performed.

### First owner hardware attempt and reference-preparation revision

Owner ran immutable `51p579x…-flakes-ctk-fido-probe`. At 14:24:51–14:24:57 the
native driver/session loaded, but **own key lookup returned -25300** (item not
found), test exit7. No `begin_auth` or hardware-worker start occurred, so no FIDO
verification happened. Own instance count returned to 0; advertisement and active
registrations were removed. Do not describe this as Key/PIN failure or success.

Hypothesis: querying this user-scoped transient DP-keychain proxy only after lock
made it unavailable to the ordinary-user host. Not yet established as root cause.
The revised host prepares/validates the opaque non-login reference while unlocked,
then emits **READY_TO_LOCK** and only afterward waits for lock to request the
operation. Keychain accessibility/ACLs, system policy and account pairing remain
unchanged; the API can still refuse use after lock. Driver/worker lock checks stay
independent and mandatory. This is a normal reference, not exported key material.

The runner now streams the host output rather than printing an early, misleading
ready message before preparation. Its existing outer timeout and exact-fixture
recovery remain. Stream-helper unit tests verified that READY arrives before child
exit, timeout terminates only the own child, and nonzero status is preserved.
Rebuilt fido bundle and no-opt-in sandbox/module/cancellation regression passed
at 14:33:26 with no hardware auth, 65.026 ms, zero retained objects/registration.
Actual revised locked access/FIDO outcome is pending owner test.

### Second owner attempt: host lock confirmed, extension has no Quartz session

Owner ran `lsiw6s…-flakes-ctk-fido-probe`. Reference lookup succeeded while
unlocked; at 14:40:45 the host confirmed lock and requested the operation. The
provider reached `begin_auth` but returned `hardware_gate_CLOSED_no_auth` and
terminal cancellation (-4, 22.697 ms). **No hardware worker started or FIDO
signature was checked.** Own objects/advertisement/registrations were cleaned.

Read-only diagnostics reproduced the discrepancy without asking the owner to
lock again: the GUI host had a complete Quartz dictionary, while the CTK XPC
provider, UID/eUID501, had `session=0` from CGSessionCopyCurrentDictionary. It was
not a false unlocked flag or a Key/PIN error.

Investigated the authoritative kernel registry-root `IOConsoleUsers` property
via public IOKit APIs, reading ONLY scalar matching/lock flags, never dumping
names, audit IDs, session UUIDs or other registry data. Initial IOService-plane
root lookup found no such property; corrected to `IORegistryGetRootEntry` (the
actual registry root). Host AND sandboxed provider then observed one matching
active console, correct UID/name/login, and unlocked/missing-lock state. No SIP,
sandbox exception, OS accessory preference or account change was needed.

The revised gate requires a unique active global console with exact ordinary
UID/user, logged-in status, lock-field presence and true lock flag. A local
Quartz dictionary, when available, must ALSO agree fully. When a daemon has no
Quartz session, it uses this independent authoritative global observation—not
the GUI caller's claim. Missing/ambiguous/global-unlocked state or a local conflict
still refuses. Both provider and worker independently perform these reads.
The property schema remains undocumented/platform-specific and production
acceptance still requires actual locked/unlock calibration and security review.

`tests/macos-lock-gate.m` exhaustively checks **65,536** boolean snapshot pairs,
plus ambiguous/missing console-owner counts, in an isolated pure decision test.
No OS query/authentication in that unit test. Sandbox observations plus no-opt-in
module/cancellation regression passed; actual revised locked FIDO is still pending.
The runner now reports an expected unverified/gate-closed result without implying
that a Python assertion traceback is a Key authentication failure.

## 5. Third owner attempt: PAM initialization blocked; direct libfido2 revision

Owner ran `4zcbryr…-flakes-ctk-fido-probe`. At 15:10:44 the global console gate
matched UID/name/console/login and a present true lock flag. The hardware worker
started after that confirmation but exited **8** about 100 ms later. No hardware
signature was verified; native cancellation returned in 143.770 ms. Cleanup read
back zero instances/no advertised token/no registrations.

Reproduced entirely WITHOUT locking or touching a Key: extending the sandbox
selfcheck to `pam_start("other", "keke", …)` yielded **PAM_SYSTEM_ERR (4)** at
15:18:30, before authentication. A library-loader-only check was insufficient.
Native PAM logged an error loading `/etc/pam.d/other`; the exact underlying errno
was not exposed by that log, so do not claim a proved filesystem-denial cause.
No system PAM/accessibility/sandbox permissions were relaxed to force it through.

The CTK worker now calls the same underlying **libfido2 1.17.0** directly, with:

- strict canonical parsing of the existing `keke` public map, distinct credential
  IDs, ES256 public keys, and exactly `+presence` options; no new credential;
- fixed RP `pam://keke-flakes`, fresh 32-byte CSPRNG nonce per request;
- standard pam_u2f-style **no-touch candidate detection only**, followed by a NEW
  nonce and UP-required, UV-disabled assertion with NULL PIN;
- `fido_assert_verify` against the explicitly corresponding whitelisted public
  key; no vendor/serial-based authorization, no PIN prompt/guess/reset, no make-cred
  calls; detection alone can never authorize;
- independent native lock checks before enumeration/request and after verification;
  existing 20-second own-child watchdog and permanent native-signature refusal.

`bundle-fido.py` replaces the PAM bundler. The worker and its fixed FIDO/CBOR/crypto
dependency closure are bundle-relative, signed and verified; no PAM service/handle
or added system-file exception is needed. Existing sudo PAM integration is unchanged.

`tests/macos-fido-verify.c` uses ephemeral software keys ONLY in memory during the
build (no files/logs/store key material, no HID). It accepts a valid assertion and
rejects wrong public key, RP, challenge, missing user-presence flag, and malformed
signature. The lock-state truth table still passes. Actual inherited-sandbox
selfcheck imported **both existing public credentials**, prepared RP/options/nonces,
and exited0 without any device enumeration or authentication. Native no-opt-in
cancellation/cleanup passed at 15:28:53 and 15:33:30. This validates initialization
and crypto failure cases, **not real locked HID access/touch**.

## 6. Fourth owner attempt: HID works; unsupported UV option

Owner ran `zz9bdh…-flakes-ctk-fido-probe`. At 15:42:24 native lock matched all
global conditions and the worker started. Worker logs show **enumeration 0,
count1**, a candidate credential found, and the actual request returned **43
(FIDO_ERR_UNSUPPORTED_OPTION)**. Signature verification was NOT invoked; the
previous `verify_result=-6` was a placeholder, not a bad signature result. Native
signature remained absent, worker exit9, callback cancelled in 304.494 ms; all own
objects/registrations were removed.

Read-only `fido2-token -I` metadata (no assertion/touch/PIN/credential enumeration)
confirmed the attached FIDO device does not expose the built-in `uv` option.
Comparing pam_u2f's `match_device_opts` identified omitted device-capability
adaptation: it changes explicit UV=false to OMIT when UV is unsupported. libfido2
1.17.0's public `fido_dev_supports_uv` checks both UV_SET/UV_UNSET capability bits,
matching that distinction.

The worker now selects OMIT for devices without built-in UV, and FALSE for
UV-capable devices. It still passes NULL PIN and ALWAYS requires UP on the final
assertion. No always-UV/PIN policy is changed or bypassed; a device requiring PIN
can still refuse. Software assertions verify that both UV forms accept a valid
UP assertion and STILL reject a validly signed assertion missing UP. Device
capability selection and whether crypto verification ran are logged as booleans;
no device paths/credential IDs/secret values. Actual corrected touch remains
pending; no successful Key verification/unlock is claimed.

## Next gates

- Owner-operated locked hardware verification with the carried secondary Key;
  touch only when it flashes, then normal native fingerprint/password unlock.
  This is deliberately NOT a Key screen-unlock test. Do not claim its outcome
  until actual worker/parent evidence is returned.
- Investigate a native token bridge with fresh registered-FIDO authorization and
  a separately protected native signing/key-management identity. Existing FIDO
  signatures are not raw X.509/PIV signatures; do not relabel existing credentials
  as a smart card. Secure Enclave backing is a candidate, not yet implemented.
- No new native key/certificate, hardware credential or account pairing without
  explaining the design/recovery implications and obtaining owner agreement.
- Before deployment prove secure-lock gating, touch without Enter, independent
  password/Key paths, negative/timeout/EOF behavior, native normal unlock and
  keybag/strong-auth correctness. No stored-password typing, signals, fake unlock
  notifications, weakened SIP or dropped required security checks.
