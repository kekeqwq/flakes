# Concurrent touch-only authentication for the shared locker

This derives from the locked `swaylock-effects` package and preserves its UI and
password backend. It is Linux-only and consumed by `NixOS/desktop/lock-screen.nix`.
It does not start a separate desktop unlock daemon or send signals to unlock.

After ext-session-lock-v1 confirms acquisition, the compositor-facing locker
creates an anonymous `SOCK_SEQPACKET` socketpair and fork/execs an immutable
store-path helper. The helper
uses only the fixed `swaylock-key` PAM service, requires both authentication and
account approval, refuses all PIN/password/conversation input requests, and emits
one success byte on its private channel. The locker checks kernel-provided
`SCM_CREDENTIALS` against the exact worker PID/UID, rejecting a copied descriptor
used by another process. Locker and worker are nondumpable. Missing keys,
mismatched credentials,
timeouts, malformed notifications, EOF and helper failure never authorize unlock.
The original password backend remains independently responsive while a key waits.
Each key attempt is a separate process and PAM transaction. Failures exit rather
than keeping PAM/FIDO library state alive indefinitely. The locker reaps the old
child, rate-limits retries, and starts a new private channel/process. A 45-second
parent-side watchdog bounds a stuck PAM/HID operation. EOF and timeouts restart
only the authentication child, never release the secure lock. This also ensures
process teardown releases every device descriptor/flock before a new attempt.
There is no filesystem/public socket, PID-file interface, persistent authentication cache, or
credential-bearing argv/environment variable.

The worker inherits only standard streams and the private notification FD; it
cannot retain the compositor/password channels or launcher's FD-9 singleton lock.
Parent-death signalling and explicit termination/reaping bound its lifetime to
this exact locker. Password-child cleanup uses a pidfd so it remains safe across
swaylock daemonization and cannot signal a reused unrelated PID. Its inherited
singleton FD is closed too: a slow wrong-password attempt must not prevent a new
lock after a parallel key success. SIGUSR1 is ignored rather than treated as an
authentication proof. Only successful PAM routes release the normal session lock.

Build checks exercise the real helper against test-only fake PAM functions, and
the real client against a test-only fake helper: success, denial, account expiry,
PIN refusal, EOF/invalid notification, spoofed sender credentials, non-inherited
FD 9/10, bounded-attempt watchdog, cancellation/reaping
and parent death. The fake implementations are never installed. These checks do
not establish real keyboard/touch or compositor behavior; production PAM, secure
lock acquisition, password latency while a key waits, hotplug, singleton/relock,
worker cleanup and idle behavior require separate local acceptance tests.
