# Public FIDO authorization registry

`credentials.json` contains public, non-resident FIDO credential handles and
public keys for `keke`, with the stable relying-party ID `pam://keke-flakes`.
Publication is intentional and authorized by the owner. It contains no private
key, PIN, OTP seed, disk key, or LUKS header. Anyone reading it still needs the
registered physical authenticator to produce a valid assertion. It does reveal
credential/identity associations.

`../security-keys.nix` wires this registry into `sudo`/`sudo-i`, not into all PAM
services. `NixOS/desktop/lock-screen.nix` supplies the independent touch-only lock
stack. The candidate is currently under temporary real-system acceptance; do not
confuse test activation with a persisted boot generation. Both physical keys passed separate real
`pam_u2f` authentication with user presence required and PIN/user verification
disabled. The test conversation rejects every PIN/password input request; neither
key requested one. Primary passed on its first bounded-window attempt (18.34 s
including human response time); secondary passed on its third attempt (0.51 s,
after two approximately 29 s timeouts). The secondary key already has a PIN:
registration used client-only CTAP1/U2F mode without changing that PIN, and the
normal, unmodified PAM module successfully verified the resulting credential.
Actual sudo reauthentication with EOF stdin (no supplied PIN/password) and real
no-keyboard touch unlock passed on the primary Key. While a Key waited, an
independent real password submission unlocked in 0.177 s; mouse, empty Enter,
wrong password, singleton/relock and worker-cleanup cases passed. The owner also
reported working sudo/lock password fallback after removing the Key. No-key
native-idle and hotplug acceptance are being completed separately. Isolated
results are not a real unregistered-third-key test: a real negative check instead
used the primary device against a secondary-only authorization list and rejected
it without requesting input (0.39 s).

Add keys by registering each physical device with this same relying-party ID,
then adding a uniquely named record after validation; do not overwrite existing
records or reset a key. Remove a record to revoke it in rebuilt/deployed PAM
consumers. Old deployments do not update themselves, and rolling back to an old
system generation restores its old registry; plan retirement of such rollback
authorities when revoking a lost Key. Do not delete old generations or recovery
backups without the owner's explicit approval. Keep the password path.
Public registry records do not constitute permission to enable arbitrary PAM
services, SSH, or to accept all Yubico devices.

## Adding or removing a Key

Build the pinned `pam_u2f` package for the enrollment host and use its `pamu2fcfg`
with `-u keke -o pam://keke-flakes -i pam://keke-flakes`. Do not use resident,
no-presence, PIN-verification or user-verification flags. Save the result privately,
then validate that new credential alone with `tests/linux-security-key-pam.py`
before adding a uniquely named JSON record. Never replace the existing list.

A device that already has a PIN may require it for CTAP2 _creation_, even when
daily authentication is configured PIN-free. Do not guess/reset the PIN or turn
off device interfaces to work around this. If an enabled U2F interface is suitable,
a client-only U2F registration can produce a non-resident ES256 `+presence`
credential, as verified with the secondary Key here. This is a PAM credential,
not a FIDO2 hmac-secret disk enrollment, and never authorizes changing the Key's
PIN/OTP/PIV/OpenPGP configuration.

To remove a Key, delete only its JSON record and rebuild/deploy every affected
instance, preserving the password and other Keys. This changes PAM authorization
only; separately revoke each corresponding LUKS2 slot/token if that disk was also
enrolled. Public registry data is not a portable LUKS header or disk-unlock secret.

Disk enrollment is separate: each new LUKS2 volume needs its own hardware-backed
enrollment at installation. Never put a LUKS header or disk-unlocking secret here.

`tests/linux-security-key-pam.py` is a real, isolated PAM check using
`pam_start_confdir`, not a mocked authenticator. It creates only a temporary PAM
stack with `pam_u2f` as the sole required authentication module; all PIN/password
input requests fail closed. It never changes `/etc/pam.d`, unlocks the desktop,
or authorizes sudo. Use a bounded human-touch window and inspect its status-only
report rather than printing credential or debug dumps.
