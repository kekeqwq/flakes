# Native macOS lock-screen investigation

Status (2026-11-17): **temporary PAM observation completed and restored;
credentialless CTK driver executed; non-login no-PIN cancellation tests passed;
registrations removed; Key screen unlock not implemented.** Full evidence: [`tests/macos-lockscreen-key.md`](../../../tests/macos-lockscreen-key.md).
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

## Locked FIDO verification-only probe (owner test pending)

Build with `probeKind = "fido";` and a distinct output link. The bundle contains
exactly the existing public mapping and fixed native PAM/FIDO libraries; no Key
enrollment, PIN/PIV/OTP change, native private key or account pairing. Its public
proxy remains unsuitable for login and never produces a native signature.

`--dispatch` is a no-hardware negative test plus sandboxed library-loader check.
Only the explicit visible-terminal `--lock-touch` mode marks hardware opt-in and
waits up to 90 seconds for native WindowServer lock state. Missing/unknown lock,
wrong UID/console state, prompts for secrets or loss of lock fail closed. The
undocumented session-lock key still needs actual owner calibration; do not treat
this research gate as production acceptance.

The immutable output provides `bin/flakes-test-locked-key` (no sudo, no arguments).
With the registered secondary Key already inserted and no other pending Key/sudo
request, run it locally, then Ctrl-Cmd-Q on `Ready`. **Touch only when the Key
flashes. This test deliberately does NOT unlock**: use original native Touch ID
or account password afterward and wait for cleanup/output. Never send a password
or PIN to the terminal/chat. If no touch request appears within about 25 seconds
after locking, return normally with native auth and report the result; don't
restart loginwindow, ctkd or a locker. No automatic screen locking occurs.

The worker is bounded and cancelled on observed unlock. Even verified FIDO still
returns native cancellation, preserving the non-login test's lack of authority.
A terminal timeout/interrupt invokes only exact-fixture recovery, not broad token
or account cleanup. Full design/evidence/limits are in the dated record.

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
prepared; unlocked/no-opt-in checks and actual sandboxed module loading passed.
Next test real locked token-sandbox hardware access with owner touch.
Only later assess a protected native identity with explicit owner agreement.
Do not replace required LA/AKS checks or relabel FIDO signatures as raw X.509 signatures.
Any eventual solution must start hardware authentication only after a confirmed
secure lock, permit a touch without first pressing Enter, keep password and Key
authentication independent/parallel, and unlock through the native locker's normal
path. It must fail closed, preserve recovery, and respect keybag/strong-auth requirements;
no success-only stubs, fake unlock notifications, password typing or process kills.
