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

## 7. Locked hardware verification accepted — 15:54:42–15:54:45

Owner ran `xvsly2…-flakes-ctk-fido-probe` and reported **the Key flashed immediately**.
Carried Key is secondary per prior physical context; primary Mac testing remains
pending. This test deliberately logs no per-Key handle/public-key/device serial.

- Host acquired its own non-login reference while unlocked, then owner locked.
- Provider independently observed the unique matching global console with
  lock-field present/true. Worker started at **15:54:42.166237**.
- Worker metadata: one device, built-in UV unsupported, UV option omitted.
- At **15:54:45.873**, worker logged `assert_result=0`,
  `verification_attempted=1`, `verify_result=0`, `verified=1`.
- Worker exit0 at **15:54:45.921133**, parent independently confirmed still locked
  and logged `hardware_signature_VERIFIED_native_signature_STILL_DENIED`.
- Native operation still cancelled with -4 and no native signature, exactly as
  designed. Total operation **3822.703 ms**, including human touch wait; not a
  separately measured cryptographic/LED latency.
- Zero retained instances, own token no longer advertised, exact registrations
  removed. Independent post-test PlugInKit readback confirms absent registrations.

**Accepted scope:** real registered-FIDO UP-required signature verification from
an inherited CTK sandbox after confirmed native lock, without supplying PIN or
password to the verifier. No new FIDO credential/PIV/PIN change occurred. No need
to repeat this positive hardware experiment.

**NOT accepted yet:** actual native screen unlock, native login/keybag identity,
locker-initiated automatic dispatch, primary Key on Mac, physical unauthorized
Key/no-Key/unlock-during-wait regressions, or password-vs-Key parallel acceptance.
The owner recovered through the existing native UI; no per-method recovery timing
was measured. No account was paired or real native signing key generated.

## 8. Owner-approved ephemeral Secure Enclave primitive probe

Owner explicitly agreed to a temporary, non-login SE test key (no private export,
account pairing, PIV/PIN change or software fallback). Added `probeKind = "se"`
with separate app/driver IDs; it has NO FIDO/USB access and never asks for a Key
touch. Existing non-login proxy still returns native cancellation, not signatures.

`ctk-se-primitive.h` requests P-256, `kSecAttrTokenIDSecureEnclave`,
`kSecAttrIsPermanent=NO`, privateKeyUsage and AfterFirstUnlockThisDeviceOnly.
That accessibility applies ONLY to this new disposable test key, not existing
keys/accounts. An interaction-not-allowed LAContext prevents a surprise prompt.
Creation is permitted only with an independently observed matching unlocked
console. A unique test-only random application tag scopes persistence queries and
unexpected-item cleanup; no broad key enumeration/deletion.

The first metadata guard rejected reported IsPermanent=true and released the
reference without signing. Public Apple source explains why this is not a
persistence indicator: [SecCTKKeyCopyAttributeDictionary](https://github.com/apple-oss-distributions/Security/blob/db15acbe6a7f257a859ad9a3bb86097bfe0679d9/OSX/sec/Security/SecCTKKey.m#L511-L587)
marks ALL token keys permanent in copied attributes. This source is a reference,
not claimed identical to installed proprietary binaries. The guard now requires
real SE token identity, non-extractable status, explicit nonpersistent creation
and actual no-keychain-item result for the unique tag, rather than that generic
copied flag. Any unexpected own-tag item is deleted and the experiment rejected.

**Actual sandbox creation/release smoke test passed at 16:26:22**:

- enclave=1, token ID present, extractable=0; no private representation API called;
- unique-tag DP-keychain lookup -25300 before use and after reference release;
- no signature/key exchange requested in this smoke mode;
- one ephemeral key per fresh test instance, reused across provider factory calls;
- native request cancelled, own virtual instance/token/registrations removed.

The helper holds only an opaque native key reference and no exportable private
blob. It releases on completion/failure and has a 120-second expiry if the client
never reaches the callback. No private key/certificate/signature/shared secret is
written to Git/store/argv/logs. Public fixed peer point only—no peer private key.

Next owner mode prepares the reference while unlocked, waits for READY_TO_LOCK,
and after independently confirmed lock tests: ECDSA signing + own-public-key
verification, wrong-message rejection, raw ECDH determinism and X9.63/SHA256 KDF
output length. Secrets/signatures remain local memory and aren't returned to the
native token caller; the request still cancels.

**Owner-operated locked SE primitives PASSED at 16:40:11** using
`/nix/store/9n7b4i6q6n55f56r8zys7hsyvjns6vxk-flakes-ctk-se-probe`:

- host independently confirmed native lock before dispatch;
- 16:40:11.110550 `se_sign_and_self_verify_PASSED_no_signature_export` (includes
  wrong-message rejection in the helper); 16:40:11.133836 ECDH raw-repeat/KDF checks
  passed; helper independently required continuing lock before each private
  operation and after completion;
- 16:40:11.134072 opaque test reference released; own-tag lookup -25300 afterward;
- 16:40:11.136463 `se_locked_primitives_PASSED_native_output_STILL_DENIED`;
- native facade still cancelled -4, no returned signature, 61.303 ms whole request
  (not an isolated signing benchmark); zero instances/advertisement and exact
  registrations removed per supplied terminal output.

No Key touch was required or claimed; this confirms SE primitive availability,
not hardware-factor authorization. No native login identity/keybag integration,
account pairing or actual unlock is implemented. Do not repeat this accepted
standalone SE positive test.

## 9. Combined non-login authorization prototype (physical acceptance pending)

Added separate `probeKind = "bridge"` / `FlakesBridgeTokenProbe.app` namespace,
not imported into activation. It creates the same consented disposable SE key
while unlocked. Each callback initializes its own FIDO-verified flag to false.
Only a successful fresh UP assertion from the bounded own worker, continuing
independent lock and a live own SE key permit the internal SE self-test. Library
self-check success is NOT hardware authorization. There is no global/cached
successful-auth flag; final native facade still cancels even after both succeed.

Preparation checks passed:

- pure eight-case FIDO/lock/key-ready truth table, including success followed by
  missing proof (no cached authorization); no OS/HID/key generation in unit test;
- actual sandbox no-opt-in smoke: library/whitelist self-check and ephemeral SE
  creation/release, no HID enumeration/SE crypto, zero retained fixture;
- actual no-hardware-opt-in denial at 17:01:32: library selfcheck PASSED, but
  `bridge_rejected_SE_NOT_CALLED`; no SE signing/ECDH events, reference released,
  own-tag lookup -25300, native cancellation in 69.998 ms and no retained fixture.
  This is a real callback-control-flow test, NOT a physical no-Key test.
- final no-auth sandbox regressions passed for fido, se and bridge, plus a repeat
  of the explicit denial fixture and live READY/own-child timeout stream tests.
  No hardware touch or locked standalone positive was repeated.

Prepared immutable bridge artifact:
`/nix/store/najcpq6rnh7gi78gp28imv3yq3msbi1m-flakes-ctk-bridge-probe`.

`--kind bridge --dispatch --bridge-denial` selects that no-HID denial fixture.
Owner-only `--lock-bridge` prepares while unlocked, waits for READY_TO_LOCK, then
performs one touch request before SE; native output remains denied. Optional
`--expect-no-key` changes ONLY runner expectations, never driver/verifier behavior;
its wrapper requires physically unplugged Keys, a started locked worker with exit9
(no gate-closed/unlock/timeout substitute), and no SE calls. It does not infer USB
absence from an error; inspect the scoped worker enumeration evidence as needed.

**Owner-operated physical no-Key denial PASSED at 17:17:36** with the prepared
artifact's `flakes-test-locked-bridge-no-key`:

- host confirmed native lock; provider global observation at 17:17:35.977346
  independently showed lock=1, correct active console/user;
- worker started at 17:17:35.977845; independent scoped readback for worker PID
  53450 at 17:17:36.084: `flakes_fido_enumeration_result=0 count=0` (successful
  enumeration, zero devices—not inferred from a generic failure);
- worker exit9 at 17:17:36.147993, no verification; 17:17:36.157265
  `bridge_rejected_SE_NOT_CALLED`, no SE signing/ECDH events;
- reference released, own-tag query -25300, native cancellation -4 in 204.751 ms
  whole request; zero instances/advertisement and exact registrations removed;
  independent PlugInKit readback also absent;
- owner returned with terminal output; recovery method unspecified. This does not
  establish both password and Touch ID recovery paths or real unlock parallelism.

**Owner-operated combined positive PASSED at 17:21:33** using the same artifact's
`flakes-test-locked-bridge`:

- provider independently observed the locked matching console before its worker
  started at 17:21:29.336547;
- independent scoped worker readback (PID 56068) confirmed enumeration success,
  count1, unsupported built-in UV correctly omitted, no-PIN request, and at
  17:21:33.322 assertion result0 / verification_attempted1 / verify_result0 /
  verified1;
- parent worker exit0 at 17:21:33.346592, fresh FIDO accepted before SE at
  17:21:33.347274; SE signing/self-verification passed at 17:21:33.367368,
  raw ECDH/KDF checks passed at 17:21:33.394407;
- reference released, own-tag lookup -25300; combined pass at 17:21:33.398942;
  native facade still cancelled -4, no returned signature, 4097.640 ms whole
  request including human touch wait (not pure crypto latency);
- runner checked strict event ordering; zero retained instances/advertisement,
  exact registrations removed and independent PlugInKit readback absent.

These two physical cases establish missing-Key rejection and registered-FIDO →
disposable-SE admission in the non-login prototype. They do NOT establish native
locker dispatch, native login signing/keybag unlock or real screen unlock. No
per-Key identifiers were logged; exact physical-Key attribution beyond carried
owner context is not independently proved. Wrong-Key/timeout/unlock-during-wait,
primary Mac and actual native recovery/parallelism remain pending. No standing
login authority or new persistent credential was created. Do not repeat accepted
standalone or combined positive hardware tests.

The exposed public-only proxy field is now named `proxy_private_material_created`
to avoid confusing its lack of private material with the real ephemeral SE test
key created separately inside the provider.

This is not production login policy. Before any persistent/login-eligible identity
or pairing: separately obtain consent and resolve stable signed-code/key access,
per-native-session proof lifetime/lock-transition binding, certificate/keybag
requirements, negative recovery cases, removal/revocation and original password/
Touch ID paths. No standing account unlock authority is granted by this prototype.

## 10. Consented SE storage-only round trip: blocked by entitlement

Owner replied “继续吧” to the explicit write → separate-process reopen → delete
proposal, with no private export/software fallback/certificate/account pairing.
Implemented standalone `se-store-probe.nix` / `se-store-probe.m` and private-state
orchestrator `tests/macos-se-store.py`; none is imported into activation. The app
uses the same base sandbox/smartcard entitlements as the CTK prototypes, but has
its own bundle ID and NO extension/USB/LS registration. It never signs or performs
key exchange; only public-point encoding for fingerprint comparison is allowed.

Design: ordinary matching unlocked console required for creation/read; one random
UID-scoped canonical UUID tag, absence preflight, nonpersistent public key and
permanent P-256 SE private key, AFU/ThisDeviceOnly/privateKeyUsage for this new test
key only, LAContext interaction forbidden. Creator must exit/release before a
separate PID reopens the same hardware key and compares public SHA256. Finally
only that reserved tag is deleted and re-queried. Public recovery metadata is
written 0600 under a 0700 owner directory BEFORE creation, never private key blobs,
references, passwords or derived secrets. Interrupted/ambiguous creation is not a
cleanup pass. `--recover DIR` requires same immutable executable/hash/owner and
reserved-tag state; it never enumerates/deletes other keys.

Actual storage test using
`/nix/store/b2sm4xycf7k7qy84la5gvg0bh9rd4iqj-flakes-se-store-probe`:

- read-only signing inventory: 0 valid local code-signing identities; probe is
  ad-hoc signed, TeamIdentifier not set. This does not establish whether owner has
  an Apple developer account/team elsewhere;
- PID63223 preflight own-tag query -25300; PID63229 creation returned
  **-34018 / errSecMissingEntitlement**, no key reference returned. Thus persistent
  creation is NOT established and cross-process reopening was NOT run;
- PID63231 own-tag deletion also -34018, subsequent query -25300; later independent
  read-only PID65946 query again -25300. These are namespace-visible no-item
  snapshots, NOT a successful deletion API call or global-keychain absence proof;
- runner correctly failed and retained `deleted_verified=false`. No certificate,
  login identity/account pairing, existing credential edit or signing attempted.

Private recovery metadata remains at
`~/Library/Application Support/flakes/se-store-probe/run.7B030A22-00C2-4376-8C29-8FE6DE6628A7/`.
Its `package` indirect Nix GC root retains the exact signed app for narrow review;
do not remove it until resolved. Metadata contains no private key material and is
not copied into Git/store. No broad cleanup or new entitlement was attempted.

Relevant public source reference (not claimed identical to installed binaries):
Apple Security revision `db15acbe6a7f257a859ad9a3bb86097bfe0679d9`,
`OSX/sec/ipc/server_entitlement_helpers.c` `SecTaskCopyAccessGroups` validates app-ID/
group use and describes implicit `com.apple.token` as READ-ONLY, explicitly noting
-34018 vs not-found behavior. `sectask/SecTask.c` `SecTaskEntitlementsValidated`
checks kernel signing-validation flags; declaring a fabricated entitlement is not
valid provisioning. `OSX/libsecurity_keychain/lib/SecItem.cpp`
`SecItemCategorizeQuery` routes non-CDSA SecKey/token/access-control queries away
from legacy keychains; removing the DP flag is not an established supported fix.
Do NOT infer a precise installed implementation or that paid membership alone
solves native unlock. No access-group/provisioning/SIP/trust bypass or software
key fallback is authorized.

Build/validation: Werror build + existing pure lock truth table passed; five
invalid operation/tag/UID inputs rejected before any keychain call (reusable
`tests/macos-se-store-schema.py`). `tests/macos-se-store-flow.test.py` mocks every
native/GC call and tests success, denied deletion despite a no-item snapshot, and
ambiguous creator timeout; missing entitlement cannot be relabeled successful
cleanup merely because a query says not-found; ambiguous creation retains recovery. No native keys are generated by these mocks.
The orchestrator now automatically retains its exact package GC root before new
creation; the earlier actual blocked run's root was explicitly added afterward.
Shared unlocked-console helper was moved verbatim into `ctk-lock-state.h`, not
relaxed; combined prototype rebuild and stream regression passed, no physical
positive was repeated. The blocked runtime result remains a failure, NOT a working
storage/login bridge.

## 11. No developer team; read-only PIV alternative review

Owner confirmed no Apple developer team/signing setup and requested continuing.
Scope here is READ-ONLY research, not permission for a new PIV key/certificate,
policy/PIN change, account pairing, MDM enrollment, signing identity or UI automation.
No hardware PIV inventory/authentication/write was performed, no extra touch tests
or private-key operations, and no service/cache refresh commands were run.

Sources reviewed:

- [Apple: Use a smart card on Mac](https://support.apple.com/guide/deployment/use-a-smart-card-on-mac-depc705651a9/web),
  current published page dated 2026-09-17: native local pairing/login procedure
  explicitly uses a smart-card PIN and authentication/encryption identities.
  This is NOT a documented pure-touch/no-submit path.
- [Yubico PIN/touch policy reference](https://docs.yubico.com/yesdk/users-manual/application-piv/pin-touch-policies.html):
  per-key PIN Never and Touch Always are distinct policies. Policies are selected
  at generation/import and cannot subsequently be changed on that key; enabling
  PIN Never removes the knowledge factor (vendor explicitly warns of the security
  reduction). Hardware policy support does not establish native Mac UI support.
  No assumption was made that existing PIV slots are empty or safe to replace.
- [OpenSCToken PR59](https://github.com/frankmorgner/OpenSCToken/pull/59), OPEN and
  UNMERGED as observed, head `82b359430fe2fe54d49090cdbb94aed1811c047d`,
  [pinned guide](https://github.com/frankmorgner/OpenSCToken/blob/82b359430fe2fe54d49090cdbb94aed1811c047d/docs/YUBIKEY_PIV_MACOS_LOGIN.md):
  author reports macOS26.6 no-PIN PIV 9A login/9D keychain wrap after custom driver
  fixes. It explicitly says loginwindow still needs a SUBMIT ACTION before card
  crypto starts; touch is not an unsolicited login input event. Guide's actual
  test sequence is submit, then touch, with a possible second touch for keychain
  unwrap. It also calls for valid app/extension signing. These are third-party
  claims, NOT reproduced/accepted on this macOS27.3 host and not proof no other
  route could exist. We did NOT build/install/run its provisioning/cache-reset
  commands or weaken its PIN checks in our code.
- Local public `TKToken.h` describes callbacks for a PENDING requested operation
  (`beginAuthForOperation`, sign/decrypt/exchange, `finishWithError`), not an
  external “FIDO verified → unlock current screen” API. Inspection of native PIV
  binary metadata/strings alone is NOT a functional proof of PIN/UI behavior.

Conclusion: PIN-free hardware crypto and native no-Enter, one-touch screen unlock
are different gates. PIV provisioning is NOT justified by these sources for the
requested UX; it may introduce irreversible slot replacement/security tradeoffs
without solving caller dispatch or number-of-touches. No working supported native
auto-dispatch/unlock path is established. Do not present paid signing, new PIV keys,
PIN Never, a simulated Enter, or an arbitrary successful SecKey call as a solved
native unlock. Current scope pauses provisioning and preserves password/Touch ID;
read-only research must first find evidence of a legitimate native initiation path.

## 12. Read-only native initiation/API audit; scoped Platform SSO candidate

Owner requested continuing. No authentication evaluation, credential request,
lock cycle, input injection, profile/account change or key provisioning occurred.
Only public headers, pinned authd source, native binary strings and read-only
`security authorizationdb read` were inspected.

Observed current policy (NOT modified):

- `system.login.screensaver`: class rule, `use-login-window-ui`;
- `use-login-window-ui`: user authentication, session-owner, shared=false;
- `system.login.screensaver.unlock`: evaluate-mechanisms, `CryptoTokenKit:login`,
  comment “Do not modify. Performs unlock operations for screensaver.”

The last name is NOT evidence of a safe arbitrary-client unlock switch. Native
CryptoTokenKit mechanism binary strings mention username/PIN/token ID/serialized
token data, paired-user public-key hash and construction of a login blob in the
Authorization context. Strings are static clues, not accepted runtime behavior or
permission to fabricate trusted token data. No invocation of that right occurred.
Pinned authd `engine.m` marks system.login.* with required keybag-unlock hint;
SkipInternalAuth branches skip internal checkpw rather than creating an arbitrary
credential and are NOT proof that external FIDO can replace native LA/AKS checks.

Public SDK audit:

- Authorization API grants rights to an AuthorizationRef; its success alone does
  not establish clearing the current loginwindow/WindowServer lock. No rights
  were requested/extended/evaluated, even without UI.
- `LAContext.evaluatePolicy` evaluates a policy for its context; documented
  successful implications are policy-specific. Public credential setters are
  application password / smart-card PIN, not a generic external-FIDO proof setter.
  No canEvaluate/evaluatePolicy/setCredential calls were made.
- TKToken APIs service requested crypto/auth callbacks, not an unsolicited screen
  unlock notification. The working probes used their OWN caller, not loginwindow.
- `ASAuthorizationProviderExtensionLoginManager` cannot be normally init/new'ed;
  it is passed during registered Platform SSO callbacks. Its reauthentication
  request is for extension SSO tokens, not documented arbitrary lock clearing.
  No registration/configuration/key-rotation/reset methods were invoked.

A genuine supported integration candidate exists, but is a different scope:
[Apple Platform SSO for Mac](https://support.apple.com/guide/deployment/platform-sso-for-macos-dep7bbb05313/web),
page published 2026-11-03, explicitly documents macOS27 web-based authentication
and passkeys at the Lock Screen/login window. Requirements include device
management supporting Extensible SSO, a compatible app/extension, and an IdP.
SDK27 also contains OpenID authentication/federation additions. Thus do NOT claim
“macOS categorically cannot use passkeys to unlock.” This is not evidence that our
plain-local CTK prototype can auto-start or that external YubiKey UP-only (no PIN,
no click, one touch) works in that managed web flow.

Scope/correctness gates before any such deployment:

- Owner must choose whether MDM/IdP integration is acceptable; no permission to
  enroll/manage the Mac or create cloud/server accounts is inferred from research.
- A compatible supplier-signed extension MAY avoid needing the owner's developer
  team, but available provider/version/license and exact key UX must be verified;
  no paid account/subscription or deployment is recommended on speculation.
- Browser WebAuthn needs the IdP's valid RP domain, not the existing `pam://keke-flakes`
  credential. Do not migrate/change that whitelist or silently enroll new hardware
  credentials. No existing PIN changes, resident-key/UV requirement assumptions.
- Password/Touch ID recovery must remain independently usable. Online-required
  authentication, grace-period expiration, password sync and privilege mapping can
  change that and must be reviewed. Do not enforce an IdP-only login policy.
- Apple explicitly excludes passkeys for FileVault preboot in this web flow; this
  candidate is NOT a FileVault/LUKS solution or permission to change disk settings.

Current result: no working local no-Enter native unlock entry found in reviewed
APIs; managed Platform SSO/passkey support is documented but undeployed/untested.
Missing deployment/UX/recovery evidence must not be reported as a fixed feature.

## 13. Owner priority: reproducible new-Mac deployment, not manual reconfiguration

Owner clarified that infrastructure complexity is acceptable to evaluate; the goal
is a reproducible setup so a new computer does not need manual configuration from
scratch. This is not inferred permission to enroll this Mac, create tenants/servers,
change account policy or waive no-PIN/no-Enter/one-touch and independent recovery.
Do not repeatedly ask pure-local vs managed scope; instead evaluate against the
[deployment contract](../macOS/private/lockscreen/REPRODUCIBILITY.md).

New read-only schema review: Apple device-management Release-v27.2 commit
`9e7fdbe23990b2551c4b29b39bc8b0de956805eb`,
`mdm/profiles/com.apple.extensiblesso.yaml` confirms declarative Bundle/Team ID,
OpenID method, web host allowlist and policy fields. OpenID support MUST exist in
the extension; schema presence does not make any supplier compatible. Registration
Token and possible authorization headers remain secrets despite being strings.
Offline OpenID access is DENIED without allowed grace policy; finite grace is not
independent perpetual password recovery. `AllowWebLoginPasswordSync` defaults
false; account creation, privilege mapping, and UI across Login/FileVault also need
explicit control. No profile generated/applied, no fallback policy relaxed.

Supplier proof caution: Microsoft's official macOS Platform SSO deployment guide
requires Intune/Company Portal. Its “Platform Credential as a passkey” means the
Mac's SE credential used in the browser, not external YubiKey unlocking the Mac;
smart-card instructions include PIN. That guide does not establish the needed
OpenID/no-PIN/no-click UX, so Entra was not selected or deployed merely because it
advertises passwordless/PSSO.

Public software/policy should be pinned and declarative; private machine-bound
registration/key/account state needs a narrow idempotent bootstrap, not copying SE
keys or exposing enrollment tokens in store. If an IdP supports it, register each
approved Key for that RP once and reuse the account authorization across Macs;
per-device registration still remains distinct and provider-specific. No claim of
zero-interaction deployment or successful native unlock. No infrastructure, host,
VM, account, key, certificate or policy was created by this review.

## Next gates

- Reproducible managed integration is acceptable to EVALUATE. Select a verifiable
  supplier/IdP combination against the deployment contract before implementing
  installation/profile/bootstrap modules; no untested enable switch. Actual
  enrollment/provisioning still needs separate informed consent.
- Combined non-login fresh FIDO → disposable SE positive and physical no-Key
  rejection passed. Preserve evidence, do not repeat these positives; wrong-Key/
  timeout/unlock-during-wait regressions remain for later authorization review.
- Storage-only own-tag round trip was authorized and attempted; -34018 blocks
  current ad-hoc sandbox path. Resolve legitimate signing/writable keychain access
  requirements before further creation attempts. Do not widen entitlements or
  create a signing identity/certificate/account pairing without new consent.
  Preserve narrow recovery metadata and its app GC root; deletion is unverified.
- Native automatic initiation without Enter remains an independent unresolved
  requirement; prioritize documented evidence before more key creation/pairing.
  PIV alternatives reviewed so far do not demonstrate this. Owner has no developer
  team; do not ask them to purchase one on an unproved unlock premise.
- Investigate a native token bridge with fresh registered-FIDO authorization and
  a separately protected native signing/key-management identity. Existing FIDO
  signatures are not raw X.509/PIV signatures; do not relabel existing credentials
  as a smart card. Ephemeral SE primitives work; persistent login-identity backing
  is not implemented.
- Beyond the agreed disposable non-login experiment, no new persistent native
  identity/certificate, hardware credential or account pairing without explaining
  design/recovery implications and obtaining owner agreement.
- Before deployment prove secure-lock gating, touch without Enter, independent
  password/Key paths, negative/timeout/EOF behavior, native normal unlock and
  keybag/strong-auth correctness. No stored-password typing, signals, fake unlock
  notifications, weakened SIP or dropped required security checks.
