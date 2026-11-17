# Platform SSO 候选：证据审查，不是生产选型

用户目标见 [可复现部署约定](REPRODUCIBILITY.md)。本表不代表已安装、注册、
购买许可或通过原生锁屏验收。没有因供应商示例而变更账户、密码或登录策略。

## 筛选结果

| 候选/固定源码参考 | 查到的能力 | 阻挡正式选择的证据 |
| --- | --- | --- |
| authentik Platform v0.73.0，源码标签参考 `c17da2e00f028bb27086edb7974df6c63b27f84b` | 有固定哈希的 ARM64 Apple 签名/公证发布包；对应桥接源码在27+配置 dynamicOpenID | 外部 Key 无 PIN/无点击/一次触摸、独立恢复未测；README 明示 pre-alpha；PSSO 位于 EE 许可范围，生产须符合订阅条款；示例不安全照搬 |
| UiO Weblogin SSO `119f395624ff460a77e0ea615edc6e04af3cecdd` + Keycloak 扩展 `57b9803f1fb87f6bab2dd5e5ba0c2c13d0abe12e` | 可自托管的协议实现；Weblogin 对27+也配置 dynamicOpenID，不只 SE 登录 | GitHub release 查询未找到客户端发布资产，README 要求自行 Xcode 编译并配置 MDM；未建立无自有签名身份下可复现获取受信任客户端的渠道；UX/恢复未测 |
| XCreds `6d70acaf1ed20dd98ca2c0b7b591359752c8f843` | 提供 OIDC 登录代理和 app | 该固定 README 明确保存当前本地密码、同步账户/钥匙串密码；不据此冒充原生外部 Key 方案，不在本轮部署。未声称所有未来版本都相同 |
| Microsoft Entra/Company Portal | 有受管理的正式扩展和文档 | 已读文档的“Mac 凭据作为 passkey”不等于 YubiKey 解锁 Mac；智能卡说明含 PIN；未据此通过完整目标，不注册租户/Intune |

来源：

- [authentik 固定发布](https://github.com/goauthentik/platform/releases/tag/v0.73.0)、
  [README](https://github.com/goauthentik/platform/blob/c17da2e00f028bb27086edb7974df6c63b27f84b/README.md)、
  [SysdBridge](https://github.com/goauthentik/platform/blob/c17da2e00f028bb27086edb7974df6c63b27f84b/ee/psso/Bridge/SysdBridge.swift)、
  [EE 许可](https://github.com/goauthentik/platform/blob/c17da2e00f028bb27086edb7974df6c63b27f84b/ee/LICENSE)
- [UiO 客户端](https://github.com/unioslo/weblogin-mac-sso-extension/tree/119f395624ff460a77e0ea615edc6e04af3cecdd)、
  [服务端](https://github.com/unioslo/keycloak-psso-extension/tree/57b9803f1fb87f6bab2dd5e5ba0c2c13d0abe12e)
- [XCreds 固定 README](https://github.com/twocanoes/xcreds/blob/6d70acaf1ed20dd98ca2c0b7b591359752c8f843/README.md)
- [Microsoft 文档](https://learn.microsoft.com/en-us/entra/identity/devices/device-join-macos-platform-single-sign-on)

## authentik：发布物身份这一关已通过

固定 URL：
`https://github.com/goauthentik/platform/releases/download/v0.73.0/authentik.Agent.Installer.pkg`

- SHA-256：`37aaed47183fa20bc903f1358e33af4f5b7a866be19b4bcacca44660bf8fff67`
- 安装包签名：Developer ID Installer，Authentik Security Inc.，Team `232G855Y8N`。
  本机 pkgutil 显示可信 Apple 分发签名、公证与可信签名时间戳。
- 包含应用：`io.goauthentik.platform.agent`；PSSO 扩展：
  `io.goauthentik.platform.psso`，extension point `com.apple.AppSSO.idp-extension`。
- 应用及扩展版本均0.73.0、架构均 ARM64；严格验签、Apple generic anchor、
  指定 identifier/证书 OU Team 约束与整个应用递归验签均通过。
- 包中的 LSMinimumSystemVersion 为15.0，不等于 OpenID 能在15运行；所需 OpenID
  功能仍以 macOS27+ 为门槛。未接受 Intel 或其他系统的部署兼容性。
- 对应源码标签仅用于审查参考；没有用供应商私钥重建发布包，不能声称完成
  源码/二进制等价证明。固定哈希保证固定字节，不保证永远不被 Apple 撤销信任。

已经提供独立的 **只读候选审计 derivation**：

```sh
nix build --impure --expr '
  let f = builtins.getFlake (toString ./.);
  in import ./macOS/private/lockscreen/authentik-artifact-audit.nix {
    pkgs = f.darwinConfigurations.mba.pkgs;
  }
' --no-link
```

它固定版本/哈希下载，校验上述签名、标识、版本和架构，只解包检查元数据，
**绝不安装、注册或执行代理/安装脚本**。输出只有 `report.json`；明确标记
`deployment_approved=false`、`native_unlock_verified=false`。未导入任何系统模块
或 activation。没有为此新增认证 enable 开关或创建 MDM/IdP。

审计内含失败关闭单测：哈希错误必须在原生工具前拒绝；签名未建立时不解包；
标识/版本异常拒绝。单测替换全部原生工具调用，不运行软件负载。
真正的 Nix build、当前构建主机上的签名检查和重复构建通过，不代表换机或
真实锁屏/断网恢复已经通过。本轮报告产物：
`/nix/store/idg1knjr0irv9siki5an4gkvd6dh42il-authentik-0.73.0-artifact-audit/report.json`。

## 不能照搬的部分与后续门槛

- 安装脚本会启停代理、写 launchd、链接 CLI、写浏览器 native-messaging 配置并
  启动 app；这里仅阅读/解包，没执行。未来部署需逐项审查，不把“固定包”误当
  “安装行为无需审查”。
- 随附示例启用用户创建、授权、账户权限映射、设备标识证明，且在多个认证范围
  声明 RequireAuthentication；还使用 UserSecureEnclaveKey。字段组合与 Apple
  schema 支持范围都需核对，不假定示例就是安全的 OpenID/恢复配置。
- PSSO 在 `ee/` 下，生产使用有有效 EE 订阅等要求；许可区分开发测试与生产。
  能下载不等于能免费生产使用，不自动购买/接受订阅或绕过技术授权。
- 即使供应商签名解决分发来源问题，也没验证原生注册、WebAuthn 自动发起、外部
  Key/PIN/触摸次数、系统离线宽限和原账户密码/指纹恢复。不能先管理常用 Mac
  再碰运气。
- 下一次真正联调需要经同意的测试 MDM/IdP、可信 HTTPS/RP、私有注册状态和明确
  许可条件。不能凭“继续”自行新建服务器/VM/云账户、购买许可、接管 Mac，或
  覆盖现有 FIDO/PIV 凭据。下一步应先形成最小联调范围和恢复方案再申请部署授权。
