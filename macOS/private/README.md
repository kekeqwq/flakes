# macOS deployment and reproducibility

## Verified on MBA

The native-flake/four-layer migration (`3972b24`) was pulled and built on the
actual `aarch64-darwin` MBA in `/Users/keke/Repos/flakes`.

- `darwin-rebuild build --flake .#mba --max-jobs 1 --cores 2 -L` succeeded.
- The input-method Lua / Node tests ran successfully during the build.
- Fish, Git, WezTerm, mpv, scrcpy and Emacs executables from the new system / Home
  Manager paths passed version-command smoke tests. This does not substitute for
  a complete interactive GUI / accessibility-permission test.
- Evaluating the old revision `f663e07ac69f744c4ab64cd1f16929cd78bad4b8`
  and the migrated configuration showed no removed or added system packages,
  Home Manager packages, declared font packages, Homebrew casks, managed home
  file targets, XDG targets, activation entry names or user LaunchAgent names.
  Emacs's final package, username/home, hostname and managed macOS defaults
  were unchanged.
- A real-machine pre-activation check also succeeded using the safe command
  below. A successful build/check is not proof that all unmanaged user files
  can be recreated on a clean Mac.

## Important: do not use `darwin-rebuild check` with this pin

The pinned nix-darwin CLI exports `checkActivation=1` for its `check` action,
but the generated `activate` script starts with `#!/usr/bin/env -i .../bash`.
That shebang clears the exported variable. Consequently the nominal `check`
action can **actually activate the configuration**, including Home Manager
and Homebrew. It is not a safe dry run with this version.

This happened during the MBA test. The original system profile was retained,
and its activation script was then explicitly reapplied to restore the
original running generation. No `switch` was performed. The new configuration
was subsequently checked with the explicit environment/interpreter invocation
below, which exited with `ok` before the mutating activation stages.

To build and check without activating, run from the repository in **Bash**:

```bash
system="$(nix build .#darwinConfigurations.mba.system --no-link --print-out-paths)"
bashStore="$(nix eval --raw .#darwinConfigurations.mba.pkgs.bashNonInteractive.outPath)"
sudo /usr/bin/env -i checkActivation=1 "$bashStore/bin/bash" "$system/activate"
```

Do not replace the last command with `sudo env checkActivation=1 "$system/activate"`:
that still executes the env-clearing shebang. Explicitly invoking Bash is
essential. Only use `sudo darwin-rebuild switch --flake .#mba` when activation
is intended; it can reload applications and run Homebrew cleanup.

## Original sudo Touch ID deployment (reference)

The original Touch-ID-only rollout enabled `sudo_local.touchIdAuth` and `reattach`.
That local stack contained an **optional** `pam_reattach` adapter followed
by **sufficient** `pam_tid.so`. It does not replace the macOS-owned sudo stack:
its existing required `pam_opendirectory.so` password route remains available.
The adapter covers GUI bootstrap-session differences in tmux/screen. No fingerprint
image/template or account password is exported or stored by this repository.
`watchIdAuth` is not enabled as an additional PAM module.

The complete Darwin system and `checks.aarch64-darwin.sudo-touchid` were built.
Biometric unlock is configured in the actual Mac's system settings, but that
alone is not proof of successful sudo fingerprint authentication.

For this deployment, use a narrow sudo-local update rather than running the whole
Darwin activation (which could reload applications and run Homebrew). The coding
agent's administrator-authorized deployment was denied by macOS System Policy;
the existing sudo/PAM files stayed unchanged in those rejected attempts. The
owner then completed the same narrow deployment from the local terminal; the
actual generated PAM file and unchanged macOS password stack were verified.
Do not disable SIP or weaken system protections to work around a deployment
denial.

A scoped GC root at `/nix/var/nix/gcroots/flakes-macos-sudo-touchid` retains the
built system and module closure. Root-only backups of the previous symlink,
content and macOS sudo reference are under `/var/root/flakes-pam-backups/`.
The exact generated local-file hash is declared as a known hash so a later normal
nix-darwin activation can recognize this narrow deployment and restore its
canonical `/etc/static` link. The exact deployed hash is also retained so a later
package/store-path change does not prevent that migration. This is **not** a full
Darwin generation switch.

Actual fingerprint acceptance passed on the Mac: `/usr/bin/sudo -k ... true` in
an isolated PTY returned 0, with no password input, no password-fallback prompt,
and sudo cache explicitly ignored. Total elapsed time including the human
response was 5.08 seconds; this is not a fingerprint-sensor latency benchmark.
This test was launched from the agent's tmux context with the adapter enabled.
The reproducible no-secret PTY fixture is `tests/macos-sudo-touchid.py` (requires a
human response to the macOS biometric prompt; do not run as root).
Password fallback retains the original OpenDirectory rule. The owner separately
confirmed successful password authentication after a fresh sudo invocation and
choosing/cancelling the biometric prompt to use the password route.

After deploying, run `/usr/bin/sudo -k; /usr/bin/sudo /usr/bin/true` in Ghostty,
including tmux, to request fresh fingerprint authentication. Separately test the
password choice/fallback in a visible terminal; do not send a password to the
agent or put it in argv/history/reports. A cancelled prompt or timed-out test is
not a successful authentication. GUI-session availability, biometric policy or
sensor availability can cause password fallback; remote/SSH biometric behavior
is not guaranteed. Administrator authorization for deployment is not itself a
sudo Touch ID test.

## Key-first sudo / separate lock-screen research

The agreed sudo policy is **narrowly deployed**: registered-Key first, otherwise
native Touch ID, with Esc from Touch ID retaining password fallback. Both
existing credentials are in the actual immutable mapping. Owner confirmed the
secondary Key authenticated real sudo in a local terminal with touch only, no
fingerprint/PIN/password. Primary Mac acceptance and new-stack no-Key fallback
checks are deferred to everyday use at the owner's request. Earlier proxy-PTY
results do not establish a general lack of Key support or verify every context.
See [`tests/macos-sudo-keys.md`](../../tests/macos-sudo-keys.md).

Esc need not cancel an active Key wait. Native macOS lock screen integration
remains a separate unimplemented research item; see [`SECURITY-KEYS.md`](SECURITY-KEYS.md).

## Remaining clean-machine reproduction gaps

These were observed on the actual MBA and are **not** supplied completely by
this flake. Do not claim a perfect fresh-machine reproduction until they are
resolved separately:

- **Fonts:** managed Latin is MonoLisa Nasy; Chinese is 仓耳今楷05 W03/W05,
  obtained byte-for-byte from pinned chinese-fonts-overlay sources. `fonts.nix`
  copies these managed files into user Fonts for CoreText; no manual font-file
  dependency is added. Existing duplicates, Bookerly, Source Han Serif SC and old
  generated terminal/IME files are NOT deleted. The raw LXGW package temporarily
  remains installed but no managed app chooses it. Its old derivation/selection
  helpers are removed; final body cleanup is deferred to the owner.
  Audit remaining manual fonts' licenses. TsangerType is personal/non-commercial,
  non-redistributable, and MonoLisa also has licensing limits; do not publish
  binaries/caches or infer distribution rights from local installation.
- **Emacs configuration/state:** `~/.emacs.d` is an independent Git checkout,
  not deployed in full by this flake. Nix supplies the Emacs executable
  and native module, but not that checkout or its Elpaca state. Shared desktop
  default.el now declares Latin/JinKai selection without copying the private init;
  this font migration also updates only that checkout's explicit font references.
  Do not overwrite unrelated configuration/state or publish the checkout as part
  of a deployment test.
- **Terminal migration:** Ghostty replaces WezTerm and its plugin. Its macOS
  cask and native glass integration are declared in the private layer; shared
  settings and remaining GUI acceptance tests are in `System/Common/desktop/TERMINALS.md`.
- **Homebrew:** cask names are declared, but their individual payload versions
  and mutable tap state are not pinned here. Disabling automatic upgrades does
  not pin what a fresh installation will download.
- **Private/runtime data:** application accounts, SSH/signing keys, browser
  profiles, Rime user dictionaries and macOS privacy/accessibility permissions
  require separate migration or provisioning. Do not put secrets in Git or
  the public Nix store. Hammerspoon's accessibility consent must be checked
  in the user's GUI session.

The four-layer boundaries remain mandatory; shared program definitions belong
in `System/Common`, not in this private platform layer.
