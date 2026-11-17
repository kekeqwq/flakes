# Native macOS lock-screen investigation

Status (2026-11-17): **diagnostic built; not installed; Key screen unlock not implemented.**
This is explicitly opt-in, not imported by the Darwin configuration. No real PAM
files, authorization rights, Key credentials, or lock-screen settings were changed
while preparing/building it.

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
Do not send a password to chat/tools. No installation has been performed yet.

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

## Evidence and next gate

- Native module builds, signature verification passes, and Apple PAM handle tests
  return `PAM_IGNORE` at both entry points without conversation/authentication.
- Synthetic normal completion, partial installation, TERM and concurrent-edit
  scenarios pass using redirected private fixture paths and mocked privilege
  commands. They do not modify real PAM or establish lock-screen compatibility.
- Actual entry timing and native loader acceptance remain untested. No log records
  alone do not prove PAM is unused; loader rejection/another service could explain
  absence. Build-time `service=other` records are not lock-screen evidence.

Determine whether any applicable entry runs before user interaction, or only
AFTER native fingerprint/password approval. Only then select an integration path.
Any eventual solution must start hardware authentication only after a confirmed
secure lock, permit a touch without first pressing Enter, keep password and Key
authentication independent/parallel, and unlock through the native locker's normal
path. It must fail closed, preserve recovery, and respect keybag/strong-auth requirements;
no success-only stubs, fake unlock notifications, password typing or process kills.
