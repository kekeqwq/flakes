# Public FIDO authorization registry

`credentials.json` contains public, non-resident FIDO credential handles and
public keys for `keke`, with the stable relying-party ID `pam://keke-flakes`.
Publication is intentional and authorized by the owner. It contains no private
key, PIN, OTP seed, disk key, or LUKS header. Anyone reading it still needs the
registered physical authenticator to produce a valid assertion. It does reveal
credential/identity associations.

This registry is being staged for sudo and desktop-lock integration. **It is not
yet wired into production PAM.** The first credential was generated successfully;
touch-only authentication and the full production regressions must pass before
activation. Do not interpret file presence as successful sudo/lock validation.

Add keys by registering each physical device with this same relying-party ID,
then adding a uniquely named record after validation; do not overwrite existing
records or reset a key. Remove a record to revoke it in rebuilt/deployed PAM
consumers. Old deployments do not update themselves. Keep the password path.
Public registry records do not constitute permission to enable arbitrary PAM
services, SSH, or to accept all Yubico devices.

Disk enrollment is separate: each new LUKS2 volume needs its own hardware-backed
enrollment at installation. Never put a LUKS header or disk-unlocking secret here.

`tests/linux-security-key-pam.py` is a real, isolated PAM check using
`pam_start_confdir`, not a mocked authenticator. It creates only a temporary PAM
stack with `pam_u2f` as the sole required authentication module; all PIN/password
input requests fail closed. It never changes `/etc/pam.d`, unlocks the desktop,
or authorizes sudo. Use a bounded human-touch window and inspect its status-only
report rather than printing credential or debug dumps.
