# 配置结构：强制分层规则

本文件是仓库配置归属的强制约定。新增、迁移和重构都必须遵守；不得为了
“先能运行”重新引入主机耦合、重复程序配置或旧的 `common/`、`nixos/` 目录。
路径大小写以本文为准，必须在 Linux 和 macOS 上保持一致。

## 四大块（唯一的系统配置归属）

### 1. `NixOS/server/`

- Linux 专属的非图形系统基础、系统服务、终端相关的系统集成。
- 始终导入 `System/Common/`，从而获得统一的 fish、Git、Pi、Yazi、终端
  Emacs 和开发工具；这些跨平台程序的定义不得在这里复制一份。
- 不启用 desktop 也必须有完整的 NixOS 终端体验。
- 不得依赖 Niri、Waybar、显示管理器、GUI Emacs、图形输入法或 Jovian。
- 需要屏幕/桌面会话的服务（例如 Sunshine）属于 desktop，不属于 server。

### 2. `NixOS/desktop/`

- 当前主力 Linux 桌面的完整 **Linux 专属增量**：Niri、登录入口、
  Waybar、Linux 图形输入法、桌面主题/字体集成、Sunshine 等。
- 唯一的公开桌面开关：`my.desktop.enable = true;`。
- NixOS base 默认包含 server，开启桌面后必须得到：
  **server + System/Common + System/Common/desktop + NixOS/desktop**。
- 不得导入 `hosts/deck/`、Jovian 或按主机名判断硬件行为。
- 显示等主机差异必须通过明确的选项注入，例如
  `my.desktop.niri.outputs`（显示器）或 `my.desktop.niri.extraConfig`，
  禁止反向读取某台机器的文件。

### 3. `System/Common/`

- macOS / Linux 共用的配置和程序定义，禁止放 Linux 专属 systemd、
  udev、boot 设置，也禁止放 Homebrew、launchd、Hammerspoon 等 macOS 私有设置。
- 根层仅放无图形依赖的配置；无头 Linux 和 macOS 都使用这一层。
- `System/Common/desktop/` 放两端共用的图形程序/配置，例如 Ghostty、
  共享 GUI 应用、GUI Emacs 和共享 Emacs 原生模块。
- 仅在 `my.desktop.enable` 时启用 desktop 子层。没有打开该开关时，
  不得通过 Common 间接启用图形程序。
- Emacs 公共定义在这里：无头系统默认 nox，desktop 子层选择 Linux
  PGTK / macOS 原生后端；不能把整份 Emacs 配置分别复制到两种系统。
- 允许同一共享程序对平台后端做小范围适配；大块平台私有集成必须移入
  对应的 NixOS 或 macOS 层。跨平台可运行不等于当前已共享：仅在 macOS
  使用的私有工作流，迁移时不要顺便在 Linux 安装一整套新程序。

### 4. `macOS/private/`

- macOS 专属系统设置、Homebrew/casks、launchd、Hammerspoon、Squirrel、
  Karabiner、原生默认应用关联及私有应用/工作流。
- 导入 `System/Common/` 并启用共享 desktop；不得导入任何 `NixOS/` 文件。
- 不得把已有共享程序（fish、Git、Pi、Emacs、Ghostty 等）的完整定义
  重新复制到这里。平台专有补丁和集成可以放在这里。

## 主机与基础设施

- `hosts/<name>/` 只放主机身份及真正的机器差异：hostname、host ID、
  磁盘/文件系统、显卡、硬件、stateVersion、硬件专属串流设置/服务。
- 公共用户名固定为 **keke**；hostname 必须由每台主机分别指定。
- Deck 是普通桌面的一种硬件部署。Jovian、Deck 的显示配置/电源策略、
  专用内核及局域网服务仅在 `hosts/deck/` 导入或配置。
- 旧 PC 配置已弃用并删除。不得将其旧包表当作新桌面的模板。
- `flake.nix` 使用原生 Nix flake outputs 直接组装，以 `lib.genAttrs`、
  `nixosSystem`、`darwinSystem` 管理系统与主机；禁止重新引入 flake-parts、
  `mkFlake`、`perSystem` 或 `withSystem` 等组装框架。
- `treefmt.nix` 是普通格式化配置，通过 treefmt-nix 的库接口调用。
  `pkgs/` 是自定义包/overlay，`tests/` 是测试；它们不构成额外的系统配置层。
- 第三方 input 内部仍可有自己的传递依赖；不得把“本仓库移除框架”描述为
  “整个依赖图里已无该框架”，也不要为此擅自改写第三方源码。
- 新机器仅注册 base、启用 desktop（需要图形时）并写硬件/身份差异，
  不得重新维护一套桌面包表。目前不要创建 `mynewvpc` 或启动虚拟机。

## 硬件密钥与加密实例

- 用户要求创建加密实例时，必须先提醒其插入指定的 YubiKey，并在登记
  请求就绪、指示灯闪烁时明确提示触摸。每个新 LUKS2 加密卷都必须单独
  登记硬件密钥；sudo/锁屏的 PAM 凭据不能替代磁盘解锁登记。
- 默认解锁目标是“备用密码 **或** 已登记 Key 的一次触摸”，不要求
  YubiKey PIN；不把“插入即自动解锁”视为默认授权。未登记的第三只 Key
  不得通过，不能仅凭厂商、型号或 USB 序列号放行。
- 不要求两只 Key 同时在场：可先登记第一只，再逐只新增。必须保留后期
  新增、撤销指定 Key 的能力；新增不得覆盖已有 Key 或密码槽。PAM 授权
  映射与各 LUKS2 卷的登记相互独立，撤销时须分别处理并核验目标。
- 登记前必须保留可用的备用密码/恢复路径；登记成功后验证触摸解锁和
  密码回退，不能把“凭据已生成”描述为 sudo、锁屏或冷启动均已通过。
  不重置 Key、不更改 PIN、不覆盖 OTP/PIV/OpenPGP 等已有凭据。
- 经用户同意，sudo/锁屏的公开凭据 ID、公钥及固定 relying-party ID 可
  Git 纳管于 `System/Common/security-keys/credentials.json`，供新实例直接
  继承；这些不是私钥或磁盘解锁秘密。新增记录先逐只实测，再明确提交，
  不得把任何检测到的 Yubico 设备自动加入授权。撤销须部署到所有实例；
  回滚旧系统 generation 会恢复旧授权，不能声称仅修改当前列表就使旧
  部署、旧启动项或此前复制的材料全部失效。
- 锁屏的密码与 Key 认证必须独立并行，只触摸不得先按 Enter。硬件认证
  只能在 compositor 确认安全锁屏后启动，成功后由 locker 本身正常解锁；
  禁止用 kill/信号绕过认证，失败/EOF/错误 Key 不得解锁。回归测试失败时
  保留锁屏供人工恢复，不停止或重启包含活动 locker 的服务 cgroup。
- sudo 等非图形认证策略属于 `NixOS/server/`；锁屏并行认证和 Plymouth
  属于 `NixOS/desktop/`，无需逐主机重复启用。分区、加密卷及其密钥登记
  属于实例私有部署，未加密实例不得被隐式加密，也不得自动转换 Deck
  现有磁盘。新加密实例优先评估 LUKS2 + Btrfs（zstd），不强制 ZFS。
- 私钥、密码、恢复材料和明文磁盘解锁秘密不得进入 Git、公开 Nix store、
  argv 或日志；登记结果先私有保存。LUKS2 头部备份也按私有恢复材料管理。
  撤销 Key 后，旧头部备份仍可能恢复旧授权；需同步处理备份，且不能宣称
  撤销能使此前复制的磁盘/头部失效。

- 通过 SSH 执行部署时，若远端 sudo 等待用户输入密码，并且用户要求用浮动窗格（float pane）接入，在用户**当前本机的 tmux client** 上用 `tmux display-popup`，弹窗内用 `ssh -t` 连接并 attach 已有的远端 tmux 会话。不要在远端 tmux client 上开弹窗，也不要另起一遍部署。保持 SSH 严格主机密钥校验；密码由用户直接在弹窗输入，不经聊天、命令参数或 `tmux send-keys`。

## 可复现性与变更验证

- 静态配置、壁纸、插件、字体等资源必须被 Git 跟踪或以固定版本和哈希
  获取。禁止新增未经说明的 home 目录静态依赖或运行时 `latest` 下载。
- 私钥、密码、Sunshine 客户端证书、应用数据库和账户状态不能提交或
  放入公开 Nix store；必须说明私有部署/备份方式。
- 受管字体授权和运行时依赖记录在 `NixOS/desktop/README.md`。
  在字体授权及外部文件审计完成前，不得声称整个桌面已经完全可复现。
- 改分层后必须验证：
  1. Deck 完整系统求值与 rebuild，不能只验证几个 enable 布尔值。
  2. `nix build .#checks.x86_64-linux.desktop-boundaries --no-link`，覆盖
     无 Jovian 普通桌面及 desktop 关闭的无头系统。
  3. 涉及共享层/路径移动时，对 macOS 配置进行求值检查。
  4. 检查 Deck 的系统包、Home Manager 包、磁盘、内核、用户、Niri
     和 Sunshine 等未意外丢失。
- 当前锁定的 nix-darwin 的 `darwin-rebuild check` 不是安全 dry-run：
  激活脚本的 `env -i` shebang 会清除 `checkActivation`，导致真实激活。
  禁止将它当只读检查；按 `macOS/private/README.md` 显式调用 Bash 并保留
  `checkActivation=1`。仅在明确需要激活时使用 `switch`。
- `build`、`test`、`switch` 的结果必须区分。求值成功不代表构建成功；
  外部下载失败不代表已修复。未经确认，不进行破坏性磁盘操作或自动
  切换桌面会话。只有用户明确要求后再进行虚拟机复现测试。
