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

## Remaining clean-machine reproduction gaps

These were observed on the actual MBA and are **not** supplied completely by
this flake. Do not claim a perfect fresh-machine reproduction until they are
resolved separately:

- **Manual fonts:** `~/Library/Fonts` contains MonoLisa Nasy, Bookerly, Source
  Han Serif SC and 仓耳今楷 files. `LXGWWenKaiIME-Medium.ttf` is an intentional
  Nix-generated copy and is not a missing source. Audit the other fonts'
  licenses; use pinned public sources for open fonts and an explicit private
  provisioning mechanism for proprietary ones. Do not publish the binaries.
- **Emacs configuration/state:** `~/.emacs.d` is an independent Git checkout,
  not deployed by this flake, and `init.org` had an uncommitted edit during
  testing. The migration did not modify it. Nix supplies the Emacs executable
  and native module, but not that checkout or its Elpaca state. Do not overwrite
  it or publish its contents as part of a deployment test.
- **WezTerm plugin:** `bar.wezterm` is fetched at runtime without a pinned
  revision. An existing plugin cache is not evidence of cold-start reproducibility.
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
