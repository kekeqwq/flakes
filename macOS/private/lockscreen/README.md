# Native macOS lock-screen investigation

Status (2026-11-17): **temporary PAM observation completed and restored;
credentialless CTK driver executed; non-login no-PIN cancellation tests passed;
registered-FIDO touch verification while locked passed; registrations removed;
Key screen unlock not implemented.** Full evidence: [`tests/macos-lockscreen-key.md`](../../../tests/macos-lockscreen-key.md).
These experiments are opt-in, not imported by Darwin configuration. No permanent
PAM/authorization policy change, Key enrollment or account pairing occurred.

## Why not just copy sudo_local?

The local `system.login.screensaver` right references `use-login-window-ui`.
Apple's published authd engine also marks `system.login.*` evaluations as requiring
a keybag check (`AGENT_HINT_KBGUNLOCK_REQ`). A successful standalone FIDO signature
or a sufficient PAM line therefore does not establish a complete native unlock.
Reference source (not claimed identical to this Mac's proprietary binaries):
[engine.m, pinned revision db15acbe](https://github.com/apple-oss-distributions/Security/blob/db15acbe6a7f257a859ad9a3bb86097bfe0679d9/OSX/authd/engine.m#L1534-L1545).

The installed public LocalAuthentication headers do not list a FIDO credential
insertion API. CryptoTokenKit/token identities and authorization plug-ins are
separate candidate integration points, not yet verified unlock solutions.
PIV would require its own credential/pairing analysis; this diagnostic does not
read/write PIV, change PINs, or enroll anything.

## First experiment: observe actual PAM entry timing

`observer.c` always returns `PAM_IGNORE` from authentication and setcred. It only
reads `PAM_SERVICE` and logs service name, PID and process eUID to subsystem
`com.keke.flakes.lock-observer`. It never requests input, reads PAM user/authtok,
sets PAM items, verifies a Key, or grants authentication. A root-owned, non-writable
public expiry file limits logging to the observation window. No expiry means no
logging. This is not a replacement locker or a simulated unlock UI.

`observe-session.nix` prepares a local administrator command that:

- snapshots all eight existing `screensaver*` profiles into a private root backup;
- prepends only `auth optional <immutable observer.so>`; existing rules/order remain;
- leaves `sudo*`, authorizationdb, SIP, account state and all keys untouched;
- normally restores original bytes, root:wheel ownership and mode 0644 after
  two minutes, or on ordinary EXIT/HUP/INT/TERM; compressed storage flags need not
  be preserved;
- refuses to overwrite independently changed policy contents during restoration;
- retains the observer through a temporary GC root, preserving it if restoration
  needs review. No locker/auth service is stopped or signaled.

Any PAM edit still carries loader/authentication availability risk. **Before
installation the owner must confirm a known working local account password and
agree to this brief observation**, save work, and use a visible local terminal.
Do not send a password to chat/tools. The first owner-approved observation has
completed and restored; any repeat needs a deliberate local invocation.

Build from the repository (build only, no activation):

```sh
nix build --impure --expr '
  let f = builtins.getFlake (toString ./.);
  in import ./macOS/private/lockscreen/observe-session.nix {
    pkgs = f.darwinConfigurations.mba.pkgs;
  }
' --out-link /tmp/flakes-lockscreen-observer
python3 tests/macos-lockscreen-observer.py \
  /tmp/flakes-lockscreen-observer/bin/flakes-observe-lockscreen
```

After explicit owner agreement, run the immutable store command locally with
`sudo .../bin/flakes-observe-lockscreen --observe`. Then manually Ctrl-Cmd-Q,
wait briefly without authenticating, and unlock with ORIGINAL Touch ID/password.
**This phase will not request a Key touch or enable Key screen unlock.** Sudo may
request the Key before the observation begins; that is not a screen-unlock test.
Do not expect or trigger OTP typing from a Key at the screen prompt.

Wait for restoration output before continuing. SIGKILL/power loss cannot run a
shell trap; the module still always ignores authentication and expired/absent
state disables logging. Backups are retained for local recovery. An interrupted
run can be restored using the same immutable command with
`--restore /var/root/flakes-lockscreen-observer/run.XXXXXX`. Unknown concurrent
changes require review, not forced overwrite. Never kill loginwindow to recover.

## Credentialless CTK probe

`ctk-empty-probe.nix` builds a containing app and sandboxed persistent-token
extension using only public CTK interfaces. Default host execution reads only its
own driver configuration. The explicit `--empty-instance` mode briefly adds one
fresh, zero-item configuration and removes it in `@finally`; it aborts if any
configuration already exists. The driver factory always refuses to create a token.
It has no login identity, certificate, private key, signing implementation or HID
access. No physical card driver is disabled or intercepted.

Build by replacing `observe-session.nix` in the expression above with
`ctk-empty-probe.nix` and using a separate output link. Temporary runtime tests must
register the containing app in user LaunchServices before PlugInKit discovery,
allow discovery delay, and remove only the exact probe extension/app registrations
on completion. Do not treat build success, registration exit 0 or metadata discovery
as driver execution or lock-screen compatibility; see the dated evidence record.
Do not force app/driver processes or native authentication services to stop.

## Non-login cancellation probe

The same builder accepts `probeKind = "denial"`. This variant publishes one
transient proxy for a fixed, public-only curve point, **no certificate/private
scalar and explicitly no login eligibility**. It exposes only an always-refusing
signature operation. The custom auth operation is not a PIN/password operation;
its terminal `NO + CanceledByUser` avoids CTK's retry behavior for AuthenticationFailed.
No hardware authentication, pairing, Secure Enclave key creation or unlock occurs.

Build the expression above with `probeKind = "denial";` added beside `pkgs`, and
use `--out-link /tmp/flakes-ctk-denial-probe`. Then, without sudo:

```sh
python3 tests/macos-ctk-probe.py \
  /tmp/flakes-ctk-denial-probe/FlakesDenialTokenProbe.app --kind denial --dispatch
```

The runner temporarily registers only the immutable probe, refuses an existing
registration, and asserts two rejecting no-UI callbacks/no signature, bounded
return, zero retained instances and no advertised own token. Its timeout is not
a passing auth result. After an interrupted run use the same command with
`--recover-only` instead of `--dispatch`: recovery refuses anything except this
exact non-login fixture. Never remove unrelated tokens or native driver settings.
See the dated record for the initial retry-loop failure and final regression.

## Locked FIDO verification-only probe (positive hardware test passed)

Build with `probeKind = "fido";` and a distinct output link. The bundle contains
exactly the existing public mapping and fixed libfido2/crypto libraries; no Key
enrollment, PIN/PIV/OTP change, native private key or account pairing. Its public
proxy remains unsuitable for login and never produces a native signature.

`--dispatch` is a no-hardware negative test plus sandboxed whitelist/crypto
initialization check. It does NOT enumerate devices or call get-assert. The
previous PAM-backed worker failed pam_start inside the sandbox and was replaced;
no system PAM service or added system-file permission is used by this worker.
Final assertions always require UP. UV is omitted when the device lacks built-in
UV support (otherwise explicitly false); PIN is always NULL. This mirrors the
capability adaptation in pam_u2f, not permission to skip touch.
Only the explicit visible-terminal `--lock-touch` mode marks hardware opt-in and
waits up to 90 seconds for native lock state. The kernel registry-root global
console table is mandatory: exactly one active console, matching UID/name,
logged-in state and a present true lock flag. Local Quartz state, when available,
must also agree; CTK XPC providers can have no local Quartz dictionary. No caller
assertion replaces the independent global read. Missing/ambiguous/global-unlocked
state, a local conflict, secret prompts or loss of lock fail closed. The property
schema still needs actual owner calibration/review; this is not production acceptance.

The immutable output provides `bin/flakes-test-locked-key` (no sudo, no arguments).
With the registered secondary Key already inserted and no other pending Key/sudo
request, run it locally while UNLOCKED. Wait for the host's **`READY_TO_LOCK`**
after successful own-reference lookup, then Ctrl-Cmd-Q. A preparatory banner is
not the ready signal. **Touch only when the Key
flashes. This test deliberately does NOT unlock**: use original native Touch ID
or account password afterward and wait for cleanup/output. Never send a password
or PIN to the terminal/chat. If no touch request appears within about 25 seconds
after locking, return normally with native auth and report the result; don't
restart loginwindow, ctkd or a locker. No automatic screen locking occurs.

The worker is bounded and cancelled on observed unlock. Even verified FIDO still
returns native cancellation, preserving the non-login test's lack of authority.
A terminal timeout/interrupt invokes only exact-fixture recovery, not broad token
or account cleanup. Full design/evidence/limits are in the dated record.

## Temporary Secure Enclave probe (owner approved)

`probeKind = "se"` is a separate, non-login experiment. It never accesses USB/FIDO,
creates no certificate/account binding, and never exports private key material.
It requests one nonpersistent P-256 Secure Enclave key per test instance, with
AfterFirstUnlockThisDeviceOnly/privateKeyUsage only for this disposable key.
Software fallback is prohibited. Tagged keychain lookups verify no stored item;
completion/failure or a 120-second expiry releases the opaque reference.

The unlocked creation/release smoke test passed in the actual sandbox. Copied
IsPermanent=true is a generic Apple token-key attribute, NOT accepted as evidence
of a stored item; see the dated record/source reference and independent tag checks.
Owner-operated locked signing/self-verification and ECDH/KDF passed at 16:40:11;
the native facade still returned cancellation, not a signature/unlock.

The SE output offers `bin/flakes-test-locked-se`: run without sudo while unlocked,
wait for **READY_TO_LOCK**, then manually Ctrl-Cmd-Q. **Do NOT touch the YubiKey**;
this phase tests SE-only signing/self-verification and ECDH/KDF. It will NOT unlock;
recover using original native Touch ID/password and wait for cleanup/results.
Private keys, derived secrets and signatures stay out of logs/store/files. A
failure is not permission to weaken account policy or substitute software keys.

## Combined FIDO → SE non-login gate

`probeKind = "bridge"` has a separate namespace. Its per-request verified flag is
false initially; library self-check success cannot set it. Only fresh registered
FIDO UP verification + independent continuing lock + own SE readiness permit the
internal SE self-test. Both success and failure still cancel the native request.
No login identity/certificate, persistent key, account pairing or policy write.

Pure policy truth table, real sandbox preparation and real no-hardware-opt-in
callback denial passed. The latter (`--dispatch --bridge-denial`) proves no SE
crypto even when the FIDO library selfcheck succeeds; it does NOT prove physical
no-Key handling. Subsequent owner-operated physical cases passed: no-Key denial
at 17:17:36 and combined registered-FIDO → SE admission at 17:21:33. The latter
verified FIDO first, then SE signing/self-verification and ECDH/KDF, and released
the reference with no own-tag item. Strict event-order checks passed; facade still
cancelled and exact transient state was removed. Do not repeat this positive.

Its `bin/flakes-test-locked-bridge` requires a visible ordinary-user terminal,
starts unlocked, streams READY_TO_LOCK, then needs one registered-Key touch ONLY
when flashing after lock. Recover with native Touch ID/password; it will NOT
unlock. `bin/flakes-test-locked-bridge-no-key` requires unplugged Keys and changes
only result expectations, not authentication logic. Owner-operated no-Key denial
passed at 17:17:36: independent worker log confirmed enumeration success/count0;
worker exit9, SE_NOT_CALLED, no signing/ECDH, reference/fixture cleaned. This is
not wrong-Key/timeout/unlock-during-wait or real screen-unlock acceptance.

Persistent native identity/certificate creation and account pairing remain a
separate consent gate, with signed-code/key access, per-session/lock-transition
binding, native keybag policy and recovery/revocation still unresolved.

## Storage-only SE experiment: current ad-hoc path blocked

Owner explicitly consented to write → separate-process reopen → delete for one
new SE test key, without private export, software fallback, certificates or account
pairing. Separate standalone `se-store-probe.nix` is NOT part of activation. It
uses base sandbox/smartcard entitlements, no USB/CTK registration and no signing.
`tests/macos-se-store.py` reserves a random UID-scoped tag, writes private recovery
metadata before creation, and restricts cleanup to that tag. Native create/read
requires matching unlocked console; interaction is prohibited. Public point only
is encoded for fingerprint comparison; creator exits before reader can run.

Actual result: creation **-34018 / errSecMissingEntitlement** under ad-hoc signature,
TeamIdentifier unset; no cross-process read. Delete also -34018; queries twice
reported -25300 in the visible own-tag namespace, not a deletion success/global
absence proof. Runner failed and retained `deleted_verified=false`. No software
fallback, fabricated access group, profile/trust/SIP change or certificate/pairing.

Private state:
`~/Library/Application Support/flakes/se-store-probe/run.7B030A22-00C2-4376-8C29-8FE6DE6628A7/`.
Its `package` GC root keeps the exact app for narrow review. State has only public
tag/fingerprint/status metadata, mode0600 in mode0700 directory, never key blobs.
Do not remove recovery state/root or repeat creation before resolving legitimate
signing/access. `--recover DIR` is scoped to same executable/hash/owner/tag, but
cannot bypass the missing entitlement and is NOT claimed to have succeeded.

Apple's pinned reference source describes implicit `com.apple.token` as read-only,
with writable access dependent on validated entitlements. This is consistent with
observations, not proof of installed implementation details. No valid local code-
signing identity was found; that is not evidence owner lacks a developer account.
A paid account alone is not an established solution: native locker/keybag behavior
still needs separate acceptance. Details/source references in the chronological
record; do not call this storage test successful.

## Native automatic initiation is still unresolved

Owner has no developer team; do not recommend purchasing signing credentials on
an unproved unlock premise. Read-only PIV review found hardware PIN Never / Touch
Always policies, but that alone does NOT establish native no-Enter screen unlock.
Apple documents smart-card PIN login. OpenSCToken's unmerged PR59 (pinned head and
sources in the chronological record) reports no-PIN login/keychain wrapping on
macOS26.6, yet explicitly requires loginwindow SUBMIT before touch and may require
a second touch for keychain unwrap. This is external reported behavior, not a
functional acceptance on this host. Public TKToken APIs service pending operations;
no legitimate external “verified FIDO → unlock screen” entry was established.

Do not provision PIV, replace slots/change policies, install that driver, pair an
account or automate the locker to paper over this gap. No such actions were taken.
Further investigation should first establish native automatic initiation, not
repeat crypto positives or trade away the no-PIN/no-Enter/one-touch requirement.
Current native unlocking remains original Touch ID/password; custom Key unlocking
is NOT deployed. Temporary SE storage recovery metadata/root remain retained.

## Public API audit and managed passkey candidate

Read-only current rules confirm native UI ownership and a separate
`system.login.screensaver.unlock` → `CryptoTokenKit:login` mechanism (explicitly
“Do not modify”). That name is not a callable “FIDO succeeded, clear screen” switch.
Native context/pairing/login-blob and keybag requirements still apply; no right was
requested/evaluated, no native credential/context was fabricated, no policy changed.
LAContext policy success and AuthorizationRef rights are not screen-unlock proof.

[Apple Platform SSO documentation](https://support.apple.com/guide/deployment/platform-sso-for-macos-dep7bbb05313/web)
(published 2026-11-03) DOES support macOS27 web-based/passkey authentication at
Lock Screen/login window. This is a supported system integration candidate, not a
plain-local helper API. It requires device management, compatible SSO extension
and IdP. A supplier-signed extension might avoid own developer signing, but no
provider/version, external YubiKey no-PIN/no-click/one-touch UX or recovery behavior
is accepted. Passkeys here do not unlock FileVault preboot.

No MDM enrollment, IdP/server/cloud account, new RP registration or extension was
installed. Existing pam:// public credentials cannot simply serve browser WebAuthn
for a new IdP domain. Before any deployment obtain scope consent, preserve local
password/Touch ID recovery and reject unreviewed IdP-only policies/password sync/
privilege changes. Only docs/SDK were reviewed; details in evidence section12.

## New-Mac reproducibility is a deployment requirement

Owner accepts evaluating infrastructure provided a new Mac does not need the
configuration manually rebuilt. See [REPRODUCIBILITY.md](REPRODUCIBILITY.md) for the
public/private boundary, idempotent private bootstrap and actual acceptance gates.
This is NOT consent to enrollment/provisioning, nor relaxation of Key UX/recovery.

Pinned Apple profile schema confirms these settings can be declared, but OpenID
still requires a compatible signed extension/IdP and careful recovery policy.
Offline OpenID access may be denied by default; a grace period is not guaranteed
independent password recovery. A supplier's “passwordless” or “Mac credential as a
passkey” claim is not external-Key lock-screen proof. No supplier was selected.

Do not create an untested authentication enable switch or silently deploy a
profile. Public fixed-version software/policy belongs in configuration; secrets,
machine-bound SE/registration/account state must remain private and be created or
reconciled via approved APIs. Reproducibility cannot mean cloning those credentials.

## Evidence and next gate

- Native module builds, signature verification passes, and Apple PAM handle tests
  return `PAM_IGNORE` at both entry points without conversation/authentication.
- Synthetic normal completion, partial installation, TERM and concurrent-edit
  scenarios pass using redirected private fixture paths and mocked privilege
  commands. They do not modify real PAM or establish lock-screen compatibility.
- Actual owner observation loaded the module in root `authorizationhost` under
  `screensaver_new_la` / `screensaver_new`, about 20 seconds after each lock and
  after native auth requests. No automatic lock-establishment entry was observed.
  All observer lines and expiry state were subsequently confirmed absent.
- The empty CTK probe executed custom driver code via native `ctkd` in the current
  user context. It has no credentials and cannot authenticate. Empty configuration
  count returned to zero and explicit registrations were removed. This is not a
  working login driver or a proof of secure-lock/PIN-free behavior.

- Five final-source non-login cycles (10 attempts) reached the custom no-PIN
  callback, returned cancellation in 3.042–31.082 ms and produced no signatures;
  each cycle verified cleanup. This still is not lock-screen auto-start or Key auth.

Lock gating, an own-child watchdog and a verification-only FIDO worker are now
prepared; actual sandboxed direct-libfido2 initialization and both public-key
imports passed. Software assertions test valid signatures plus wrong key/RP/nonce,
missing presence and malformed-signature rejection; those tests use memory-only
ephemeral test keys, not hardware or account credentials.
Owner's real locked hardware test passed at 15:54:45: verified FIDO assertion,
worker exit0, no native signature, all transient state cleaned. Do not repeat this
positive test or label it native screen-unlock acceptance. Primary Mac and physical
wrong-Key/timeout/unlock-during-wait cases remain untested. Owner agreed to the
isolated SE experiment; creation/release and locked primitives passed. Combined
fresh FIDO → disposable SE admission and physical no-Key rejection also passed.
Owner subsequently authorized storage-only testing; the attempt is blocked by
-34018 (see above). No working persistent bridge or login identity/account pairing
is implemented or authorized. Next resolve legitimate signing/access, not more
positive hardware tests or weakened policy. Do not repeat accepted positive hardware tests.
Do not replace required LA/AKS checks or relabel FIDO signatures as raw X.509 signatures.
Any eventual solution must start hardware authentication only after a confirmed
secure lock, permit a touch without first pressing Enter, keep password and Key
authentication independent/parallel, and unlock through the native locker's normal
path. It must fail closed, preserve recovery, and respect keybag/strong-auth requirements;
no success-only stubs, fake unlock notifications, password typing or process kills.
