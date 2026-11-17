# macOS 硬件认证：讨论决定与锁屏调研

Key-first sudo 策略已窄范围安装，实际加载的只读凭据表已核对包含两只既有 Key。
**第二只已由用户确认在本地终端纯触摸通过真实 sudo**；第一只已授权引用，Mac 实测待日常使用观察。
指纹与原有密码回退路径保留；用户要求停止追加认证测试。锁屏没有改动。
本轮只读检查系统文件、授权规则和公开文档，没有修改 PAM、authorizationdb 或 Key 内容。

## 换机可复现是验收要求

用户已明确：可评估 MDM/IdP 等基础设施，目的是新电脑无需重新手动拼配置。
不因此推定放弃无 PIN/无需 Enter/一次触摸和密码独立恢复，也不自动注册/管理
本机。公开程序/策略固定版本纳管；设备密钥、注册令牌、账户绑定经私有幂等
引导生成或恢复，不克隆到 Git/store。系统必需的首次授权不能伪装成零交互。
具体边界和新机验收见 [部署约定](lockscreen/REPRODUCIBILITY.md)。
目前仍未选出满足完整目标的已签名扩展/IdP 组合；已有 schema 不等于解锁体验
或恢复已验证。尤其 OpenID 离线默认拒绝/有限宽限不能当作永久独立密码恢复。
不先部署不明方案，再要求每台新机器手工修补。

## 已确定并部署的 sudo 方案

顺序：`pam_reattach` 适配 → 已登记 Key 的 U2F/FIDO 认证 → 原生 Touch ID → 原生密码。

- 有可用的登记 Key：等待触摸，用户接受这一阶段不支持 Esc 立即取消。
- 无可用的登记 Key：跳到 Touch ID；原生指纹提示仍可 Esc 回退密码。
- Key 失败/超时继续后续认证，不因错误或缺失 Key 放行。
- 不做指纹/Key 并行，不做自定义 Esc 取消层；不要求每日 PIN，不修改 Key 的 PIN。
- 保留两只 Key 的现有公开凭据、`keke` 和 `pam://keke-flakes`，不重新登记。
  公开注册表已原样移到 `System/Common/security-keys/`，两端共享数据，平台 PAM 集成分别归属各自系统层。
  macOS 不反向导入 `NixOS/` 模块。每只 Key 仍需在 Mac 上单独实测，不能因 Linux 通过便算 Mac 通过。
- 此数据可复用于兼容的同 RP PAM 服务，不等于可替代 LUKS 逐卷登记、FileVault 或 PIV 证书。

实施与实测状态见 [`tests/macos-sudo-keys.md`](../../tests/macos-sudo-keys.md)。
第二只 Key 的用户/root 隔离模块验证及本地终端真实 sudo 已通过，第一只尚未在 Mac 实测。
先前代理 PTY 测试未得到 Key 成功，不能推广成“本地 sudo 不支持 Key”；不同上下文仍需独立对待。
两只都已配置，不重新生成凭据，后续由用户日常使用观察。

不全量切换 Darwin 来测试；保留已工作的密码回退、root-only 备份及本地恢复入口。
本机此前的窄范围 PAM 安装需要用户在本地授权完成，不绕过 SIP/System Policy。

## macOS 原生锁屏：目前不能按 sudo 的简单配置方案承诺

用户已要求继续推进。已实测真实认证入口及调用时机，不能把 sudo
模块直接设成锁屏的 sufficient。用户同意后已运行
[`lockscreen/`](lockscreen/README.md) 的短期 `PAM_IGNORE` 观察器并恢复；真实
PAM 在原生认证请求后才进入。空的 CryptoTokenKit 扩展已由系统加载执行，空
配置与主动注册已清理。随后不具登录资格的拒绝型 Token 已验证免 PIN 回调：
最终版本 5 轮、10 次请求均明确取消且没有签名，修复了失败码引发的重试循环；
测试对象已移除。锁屏状态下的 FIDO 验签工具已准备，包含门控、子进程看门狗
与现有公开凭据。第三次现场操作确认锁屏门控和 worker 启动，但初始化 PAM
失败；现已改为直接 libfido2，不增加系统 PAM 读取权限。两只公钥的沙箱解析、
无硬件初始化和签名负向软件测试通过。后续现场确认锁屏 HID 可达，但设备拒绝
不支持的 UV 选项。适配后在 **15:54:45 实际锁屏触摸验签通过**：UP-required
断言及公钥校验成功，worker exit0；用户确认立刻亮灯。测试仍故意拒绝原生签名，
对象已清理，主 Key 的 Mac 实测仍待进行。用户随后同意临时、无登录资格的
Secure Enclave 实验；沙箱内已创建并释放非持久化测试密钥，独立标签查询确认
无钥匙串条目。16:40:11 锁屏后的签名/自验签及 ECDH/KDF 已通过，原生 Token
输出仍明确拒绝；**没有创建登录身份、配对账户或实现 Key 解锁**。
组合 FIDO → 临时 SE 原型已通过无硬件授权时不调用 SE 的回调检查；17:17:36
现场无 Key 拒绝也通过，独立日志确认枚举成功且设备数为 0，未调用 SE、对象
已清理。17:21:33 组合触摸成功路径也已通过：先验证新鲜 FIDO 断言，再执行 SE
签名/自验签与 ECDH/KDF，随后释放；原生输出仍拒绝，没有实现屏幕解锁。
不重复已通过的正向硬件测试。用户随后同意仅做专用 SE 钥匙串写入/跨进程读取/
删除实验；当前 ad-hoc 沙箱创建返回缺少 entitlement（-34018），跨进程读取未
进行，不能算通过。专用标签查询无可见条目，但删除 API 同样 -34018，私有恢复
元数据和原应用 GC root 已保留。没有证书/账户配对，没有回退软件密钥或扩大
权限。正式签名/可写访问组及身份、keybag 接入仍需研究和另行同意。
用户没有开发者团队；不建议为未验证路线付费。只读 PIV 调研发现：硬件支持
PIN Never / Touch Always 不等于原生无需 Enter。相关未合并的 OpenSCToken
原型仍明确要求先提交登录界面，钥匙串解包可能还需第二次触摸，未在本机复现。
因此不据此生成 PIV 密钥或配对账户；原生自动发起认证入口仍未建立。当前 Mac
真实解锁仍用原有指纹/密码，不把底层验签成功说成纯触摸解锁已实现。
进一步只读核对确认：Authorization/LAContext 成功不能当作解锁当前屏幕，系统
`CryptoTokenKit:login` 机制也不是外部验签成功后的无条件解锁开关。
Apple 2026-11-03 的官方文档另明确支持 macOS27 Platform SSO 在锁屏使用网页/
passkey 认证；但需设备管理、兼容扩展与 IdP，是不同部署范围，且尚未验证外部
Key 无 PIN/无点击/一次触摸。没有注册 MDM/IdP、安装扩展或新登记凭据；若继续
此路线，须先明确接受其范围并审查本地密码/指纹恢复、离线和密码同步策略。
现有 pam:// 凭据不自动成为 IdP 的浏览器 WebAuthn 凭据，也不涉及 FileVault。
[现场记录](../../tests/macos-lockscreen-key.md) 区分这些实验与真实解锁验收。
重做观测或引入原生凭据前仍须明确同意和恢复路径。最终要求安全锁屏后才启动 Key
认证、无需先按 Enter、密码与 Key 独立并行、成功由原生 locker 正常解锁。

### 本机只读证据

检查时本机为 macOS **27.3**。`security authorizationdb read system.login.screensaver`
显示原生锁屏使用 `use-login-window-ui` 规则，不是 sudo 的 `sudo_local` 入口。

系统同时有多组 PAM 文件：

- `screensaver` / `screensaver_new`：OpenDirectory 密码相关路径。
- `screensaver_la` / `screensaver_new_la`：`pam_localauthentication`、`pam_aks` 等路径。
- `screensaver_new_ctk`：`pam_smartcard` 与非密码账户检查。

文件存在不等于已经证明每种锁屏交互具体调用哪一份。本轮没有动态追踪认证，也没有做真实
锁屏改动。不能说 macOS 完全不走 PAM，但同样不能据此说给 `screensaver` 加一行就能覆盖
原生 Touch ID/智能卡/密码的分流，并在锁定后主动点亮 FIDO Key 等待触摸。

### Apple 文档支持的硬件路线

Apple 原生智能卡集成是 **PIV / CCID / CryptoTokenKit**。本地配对流程需要认证/加密身份、
管理员授权和智能卡 PIN，文档描述以智能卡和 PIN 登录。这不是现有 U2F/FIDO 凭据表，不能
直接拿现有两个 credential handle 当成 PIV 证书使用。

- [Intro to smart card integration](https://support.apple.com/guide/deployment/intro-to-smart-card-integration-depd0b888248/web)
- [Use a smart card on Mac](https://support.apple.com/guide/deployment/use-a-smart-card-on-mac-depc705651a9/web)

Apple 的 [Security Keys for Apple Account](https://support.apple.com/en-us/102637)
讲的是 Apple Account 的第二因素，不代表支持同一只 FIDO Key 纯触摸解锁本机屏幕。

上游 pam-u2f 历史 macOS issue 曾有 screensaver 集成、睡眠后设备发现不稳及认证失败导致
注销的报告（[112](https://github.com/Yubico/pam-u2f/issues/112)、
[71](https://github.com/Yubico/pam-u2f/issues/71)）。它们针对旧系统，只能说明风险，
**不能用来证明当前 27.3 必然可用或必然不可用**。

### 当前结论与边界

- sudo 的串行方案可以单独推进；不要把它等同于原生锁屏也已可行。
- 尚未找到并验证“原生锁屏保留 Touch ID/密码，复用现有 FIDO 凭据，无 PIN、无需先按 Enter、
  直接触摸解锁”的受支持实现。不做“绝对不可能”的结论，但不能承诺只是几行配置。
- 原生 PIV 是另一套方案，标准文档包含 PIN，不符合当前的纯触摸目标；没有试图取消其 PIN 要求。
- 不重置/覆盖现有 PIV、OTP、OpenPGP，不为了研究禁用 SIP、不弱化授权规则。
- 不用 Hammerspoon/AppleScript 储存并代输账户密码，不杀进程/发信号伪造解锁。
- 如将来继续研究，须另行授权、准备本地恢复路径，再隔离验证真实锁屏调用链及睡眠/唤醒。
  当前生产锁屏保持 Apple 原生方案；本轮不修改。
