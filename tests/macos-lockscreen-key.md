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

## Next gates

- Verify real CTK operation dispatch and no-PIN interaction with a non-login,
  always-refusing test object before making any identity login-eligible.
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
