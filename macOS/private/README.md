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
  dependency is added. All previously manual user fonts (Bookerly, Source Han
  Serif SC, 今楷01 duplicates) were removed on the owner's request; user Fonts
  keeps only the managed MonoLisa/今楷 copies. The legacy LXGW/WenKai package
  and its old generated terminal/IME font files were removed entirely as well.
  Audit managed fonts' licenses. TsangerType is personal/non-commercial,
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

## PIV Key 锁屏登录（OpenSCToken PIN-Never）

实验性 OpenSCToken + YubiKey PIV 路径。已验证驱动运行时可以解锁，但扩展被系统回收后，智能卡实例恢复仍不可靠。日常请保留并优先使用可用的 Mac 密码解锁路径。

### 新电脑复现步骤

1. **darwin-rebuild 构建并安装驱动**（自动完成）：
   - 构建 OpenSCToken（含 PIN-Never 补丁）
   - 安装到 `/Applications/Utilities/OpenSCTokenApp.app`
   - 在当前登录用户的会话注册，并核对 PlugInKit 返回的扩展路径；不以 `_securityagent` 身份向该用户的 PlugInKit 服务发请求。
   - 严格签名校验和注册成功不等同于锁屏已识别智能卡，仍需单独验收。

2. **手动写入 PIV 密钥**（一次性，需 YubiKey）：

   ```sh
   # 确认 9A/9D 为空槽
   ykman piv keys info 9a && ykman piv keys info 9d
   ```

   如果已写入（如迁移场景），跳过此步。否则需生成密钥+证书：
   - 9A：RSA2048，PIN Never + Touch Always（认证）
   - 9D：RSA2048，PIN Never + Touch Always（钥匙串解包）
   - 自签证书，导入 9A/9D
   - **私钥不可导出，管理密钥状态需确认**

3. **手动配对账户**（一次性，需 sudo + 触摸）：

   ```sh
   sc_auth identities   # 获取 9A 公钥哈希
   sudo sc_auth pair -v -u keke -h <9A_HASH>
   ```

   Key 亮灯时触摸。成功输出不应包含 `Failed to store Login keychain unlock key`。

4. **验证**：Ctrl-Cmd-Q 锁屏 → 空 PIN 框按 Enter → Key 亮灯 → 触摸 → 解锁。

### 安全边界

- PIN Never 移除知识因子，安全性依赖物理持有 + Touch Always。
- 密码回退独立保留，不启用强制智能卡。
- 不修改 sudo/PAM、FIDO 凭据、PIV PIN、管理密钥。
- 驱动仅安装 CTK 层，不改登录策略或 authorizationdb。

### 已知限制

- 需要按 Enter 提交（非全自动），不满足只触摸的目标。
- FileVault 预启动不支持 CTK，首次开机仍需密码。
- 2026-11-18 12:17，已有智能卡实例时解锁成功。12:18:57，PlugInKit 请求移除扩展实例；同一秒扩展注册记录的 UUID 更换，且 LaunchServices 正在更新多个应用扩展。尚不能归因到某条命令。12:19，CTK 启动了新驱动进程，但报告无法创建 token 实例，与 12:14 的 `missing tokenID` 不同。
- 安装器在已安装的同源 App 通过签名校验且注册路径匹配时不重新注册。12:24:50 激活新版安装器后，原有注册 UUID 和时间均未变，系统仍列出同一 token。这验证了常规 rebuild 不会刷新此注册记录，但不等于系统或其他程序重新注册后的实例恢复已修复。12:52:01 经智能卡认证解锁成功，注册 UUID 未变；这次未覆盖扩展被移除后的恢复。
- 上游实现的是 `TKSmartCardTokenDriverDelegate` 的 `createTokenForSmartCard:AID:error:`。Apple SDK 明确要求 SmartCard 驱动不要实现通用的 `tokenForConfiguration:error:`；不能用补一个通用回调来冒充已修复。需要验证系统回收扩展后，在卡仍插着的情况下重新枚举并成功认证；不能用重新插卡后的成功代替。

The four-layer boundaries remain mandatory; shared program definitions belong
in `System/Common`, not in this private platform layer.
