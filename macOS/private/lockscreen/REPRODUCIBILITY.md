# 原生 Key 解锁：换机可重复部署的验收约定

状态：**设计/候选方案审查，不是已实现的锁屏模块**。用户确认核心目标是换机
无需重新手工拼配置；不排斥基础设施复杂度。未据此推定放弃“无 PIN、无需先按
Enter、一次触摸、密码独立恢复”等既有要求，也未获得接管设备/部署服务的授权。

## 1. “可复现”的具体含义

- 同一份公开配置、固定版本与哈希，可以在新 Mac 生成相同的程序和策略；
  不靠在系统设置里重新记忆并点击每个选项，不运行 `latest` 下载。
- 程序必须核对签名来源/扩展 Bundle ID/Team ID。供应商签名与本机自己拥有开发者
  账号不是一回事；但目前尚未选出满足完整目标的可交付扩展。
- 配置可复现不等于克隆设备凭据。Secure Enclave 私钥、设备/用户注册令牌、
  MDM 身份、账户绑定和 IdP 数据库是私有状态，不能写进 Git/公开 Nix store。
- 必须把不可避免的首次设备授权收敛成**有计划、可重入、可恢复的私有引导**。
  不承诺每台机器完全零交互；系统要求的同意/认证不能用复制密钥或自动输入密码
  来省略。自动设备注册也依赖事先建立的管理/设备归属，不会凭空由 Nix 创建。
- 不在每台机器复制一套包表/脚本。macOS 原生集成在 `macOS/private/`；现有公共
  PAM 数据继续以 `System/Common/security-keys/` 为唯一来源。

## 2. 公开声明与私有状态分开

| 对象 | 纳管/部署方式 | 新机器操作 |
| --- | --- | --- |
| 扩展/包含应用 | 固定发布版本、哈希、Bundle ID、签名 Team ID，Nix 获取；无未知下载源 | 同一部署入口安装，不手工另配版本 |
| 公共 SSO 策略 | 受审查的 profile/declaration 模板、稳定标识、显式 RP/域名 allowlist | 管理系统或经同意的部署流程应用，不人工逐项点击 |
| IdP/MDM 非秘密配置 | 如果选定方案支持，使用声明式配置/版本化导出；schema 固定版本 | 复用同一服务/策略，而非逐机另建服务 |
| 现有 sudo Key 名单 | 现有两只公开凭据及固定 `pam://keke-flakes`，不变 | 复用现有部署，无新登记/改 PIN |
| IdP WebAuthn 凭据 | 首次经同意后在 IdP 登记；注册结果先私有保管 | 若供应商支持，复用 IdP 账户已有 Key，而非逐 Mac 新建 Key 凭据 |
| MDM/设备注册身份、SE 密钥 | 每机本地/平台 API 生成或管理服务私有下发；不可跨机复制 | 引导检查并补齐缺失注册，需要时由用户本机确认 |
| 注册令牌、证书私钥、IdP 管理凭据/数据库 | 私有备份和运行时文件/FD；不放 argv/env、日志、Git/store | 私有恢复/轮换，绝不从公开 flake 生成有效秘密 |
| 当前被阻断 SE 测试的恢复记录 | 现有私有目录与精确应用 GC root，见现场记录 | 不是新机依赖，不克隆为正式身份，不声称清理已验证 |

浏览器 WebAuthn 使用 IdP 的合法 RP 域名。现有 PAM 凭据不能改个 label 当成它；
如需新 RP 登记，须另行同意，保留既有 FIDO/PIV/OTP/OpenPGP 数据，不改 PIN。
若要把新的公开注册结果提交 Git，也必须另获同意，不能沿用旧 PAM 数据的授权。

## 3. 私有引导的幂等与失败行为（待实现）

1. **只读 plan**：核对系统版本、原生密码恢复可用、用户名 `keke`、设备归属、
   已安装应用签名/版本、注册状态、现有策略及冲突；缺少输入就停止。
2. **显式 apply**：仅在方案和恢复路径已确认后注册/安装本机获批项。注册令牌
   走私有运行时通道，不内联进公开 profile/Nix 求值结果。
3. **状态检查**：已经正确注册/配对的设备直接复用；重复运行不再生成 Key、
   不重复绑定账户、不覆盖已有槽位。旧状态不匹配时报告并要求人工决策，不自动
   “先删再建”。中断保留私有恢复记录和所需精确程序版本。
4. **验证而非只看 enable**：确认真实原生锁屏与账户/钥匙串行为；检测不通过
   保留密码恢复，不停止活动 locker/系统认证服务，不假报已解锁。
5. **定向移除/撤销**：区分 IdP 硬件凭据、各设备注册、账户绑定和策略，分别
   撤销并检查。回滚 Nix 不等于撤销服务端/设备状态，旧配置也可能恢复旧授权。

此处是接口/行为要求，没有可直接执行的“安装成功”命令。现在不部署占位模块，
也不提供一个未验证却可 `enable=true` 的认证开关。

## 4. Platform SSO 候选的实际证据与风险

Apple 文档支持 macOS27 在锁屏通过 Platform SSO 使用网页/passkey，但要求
设备管理、兼容扩展和 IdP。这证明存在系统集成路线，不证明某个现成供应商
已经支持本人的外部 YubiKey 无 PIN/无点击/一次触摸目标。

Apple device-management schema 固定参考：
[`9e7fdbe23990b2551c4b29b39bc8b0de956805eb` (Release-v27.2)](https://github.com/apple/device-management/blob/9e7fdbe23990b2551c4b29b39bc8b0de956805eb/mdm/profiles/com.apple.extensiblesso.yaml)。
已核对的字段包括：

- `ExtensionIdentifier`；macOS 要求 `TeamIdentifier`，不是可任意伪造的签名身份。
- `PlatformSSO.AuthenticationMethod=OpenID` 从 macOS27 开始，且明确要求扩展支持。
- `WebLoginURLAllowList` 必填；只允许明确 IdP 域名，不能用任意网页脚本扩展信任。
- `RegistrationToken` 是注册秘密，虽然 schema 中是字符串，也不能因此放进 store。
- `AllowWebLoginPasswordSync` 默认 false；不得为此目的同步/更改现有本地密码。
- `UnlockPolicy` 的 OpenID 离线行为需要单独审查：未允许离线宽限时会拒绝离线；
  有限宽限不等于永久独立密码恢复。`RequireAuthentication` 等模式也不等于
  Key 与本地密码并行。**这个恢复兼容性门槛未通过前，不注册本机。**
- `NonPlatformSSOAccounts` 可以排除账户，但把 `keke` 排除又不能同时声称已使
  它获得同一套 SSO 锁屏能力；也不能暗中以另建账户代替原有密码恢复要求。
- `AlwaysUseLoginUI` 从27.2开始；OpenID 默认也会使用相应 UI。仅填写 UnlockPolicy
  不能证明 Login Window/FileVault 其余行为不受影响；须完整验证。
- 不自动创建/重命名用户、赋予管理员/组权限、启用设备/用户标识证明或触发 key
  rotation/reset。这些都是独立的账户/设备管理授权。

一个已审查但**不能据此选型**的例子：[Microsoft Entra macOS Platform SSO
部署文档](https://learn.microsoft.com/en-us/entra/identity/devices/device-join-macos-platform-single-sign-on)
要求 Intune 管理、Company Portal 和配置的扩展；文中“平台凭据作为 passkey”
是 Mac 的 SE 凭据用于浏览器，不能当成“外部 YubiKey 解锁 Mac”的证据。其
智能卡解锁说明包含 PIN。未从该文档证实所需的 OpenID/外部 Key UX，不选择
供应商、不注册租户、不安装 Company Portal 或管理 profile。

## 5. 交付前必须实际通过

- 先选出有明确版本/签名/发布渠道、支持所需 OpenID 与外部 Key UX、恢复策略
  可审查的组合；“支持 PSSO/passwordless/passkey”这几个词不能替代行为证明。
- 锁屏确立后才启动认证；正确 Key 一次触摸、不按 Enter、不先点按钮、不要求
  PIN；拒绝未授权 Key，不把 USB 型号/序列号当授权。
- 无 Key/错误 Key/超时/认证中手动解锁/断网/IdP 或 MDM 故障/策略更新与回滚，
  均保留本地原生密码与指纹的独立恢复；不靠保存并输入账户密码。
- 保留本地账户身份、文件和现有认证；不意外改变 FileVault，不能声称 passkey
  可用于 FileVault preboot。
- 在新的实际设备按同一公开配置与私有引导重放，确认不是当前机器临时状态。
  未获许可不创建 VM、主机或服务来代替这项验收。
- 当前其他桌面资源/字体可复现性审计仍独立存在，不能据此宣布整台桌面完全可复现。

如果后续自建 Linux 基础设施，Linux 服务归 `NixOS/server/`，主机只提供身份/
硬件差异；不新增框架层，不导入 Mac 私有文件去配置 Linux，也不在本轮创建
新主机、VM、服务、租户或管理设备。

当前结论：用户接受评估基础设施换取可重复部署；供应商/外部 Key UX/独立恢复
仍未选定或实测。可复现性要求已明确，不等于原生 Key 解锁功能已实现。
