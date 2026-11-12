# 配置可复现性追踪清单

> 本文件由助手维护，分析结果直接告诉用户。勾选表示该项按明确边界完成，不表示所有机器都已部署最新提交。
> 本轮按用户要求：先走完仓库审计，再统一构建测试。未获部署指令不自动 switch，不删除用户状态。

## 0. 当前结论与边界

- [x] 本轮仓库第一方配置的依赖与公私归属检查完成；已确认问题均已修配置、明确排除或列为实例前提。
- [ ] 最新工作树尚未完成统一构建测试，特别是 Enhanced-nox 5.2.4.10 与新公共 Sunshine 代理布局。
- [ ] 全新系统实际安装尚未验证；不启动 VM、不清空 home、不格式化磁盘来验证。
- 上轮 Deck 已成功 switch 的基线是提交 `58df058` 的配置内容；本轮工作树继续修改，不能将旧成功结果套到新配置。
- macOS 不追求完整复制系统状态；本轮重点是 Linux/Deck，以及共享配置是否自带依赖。
- Windows 不在本轮部署范围；WezTerm 保留的 Windows 分支不是 Windows 环境已纳管的声明。

### 公私含义

| 类别                           | 处理                                                                               |
| ------------------------------ | ---------------------------------------------------------------------------------- |
| 公共静态配置、插件、字体、脚本 | Git + Nix 固定来源及依赖；新实例不需要旧 home                                      |
| 实例配置                       | `hosts/<name>/`；磁盘/文件系统、显卡、显示输出、实例服务启用、下载目录、局域网目标 |
| 秘密及可变数据                 | 用户/服务自行初始化或用户选择的私有备份；不进入公开 Git / Nix store                |
| 用户明确排除                   | 不迁移、不删除，也不继续当作公共复现缺陷                                           |
| 网络运行数据                   | 明确 URL/服务前提；不把 tracker 列表、搜索响应等动态内容伪称为固定构建资源         |

**主机私有配置不等于保密存储。** hosts 文件仍会进入 Git/Nix store；其中不能放密码、私钥、订阅令牌或数据库。

## 1. 用户最终决策

- [x] 分区表、磁盘初始化由每实例安装时手动准备；不复刻另一台机器的分区，不引入自动格式化流程。
- [x] 默认西文 MonoLisa，简繁中文 LXGW；日文无需求。MonoLisa 正/斜体由用户明确要求复制入仓库。
- [x] Pi 只复现插件与运行依赖，不复现模型/provider/failover/账户/会话。
- [x] Emacs 用户配置由用户独立管理；本仓库只负责声明的程序/原生模块，不审计独立 dotfiles/Elpaca 工作流。
- [x] IINA、Anki、GoldenDict、Surge、Tinycast、Moonlight 本地设置/数据不要求复现。
- [x] 浏览器扩展由 Google 账户同步；不复制浏览器 profile、字典数据库或用户脚本。
- [x] PrismLauncher、Steam 游戏、CEC/Gamescope 用户状态、Weylus、htop/Qt/文件选择器本地状态不要求复现。
- [x] NetworkManager 公共服务启用，用户自行联网；不复制连接 profile 和密码。
- [x] Rime 首次部署即有小鹤双拼＋雾凇，训练数据每实例自行生成，不复制其他实例 userdb。
- [x] Sunshine 公共配置只负责后台转发；捕获、GPU、输出、权限、应用列表及配对由实例决定。
- [x] OpenList 安装和服务仅在 Deck；具体挂载、账户和数据库属于实例数据。
- [x] 废弃 Zellij、Codex CLI、Zsh、Foot、SMB、sing-box；删除仓库定义，不删除历史/认证/数据。
- [x] qBittorrent Enhanced Edition 正式 v5.2.4.10 nox；WebUI 8080，ngosang trackers_all，Deck 下载目录 `/var/lib/qBittorrent/downloads`。
- [x] ImageGlass 官方 cask 尚未收录时暂不处理；此前官方 cask 单项 API 为 404，全量列表无匹配。不将此查询视为永久结论。

## 2. 公共配置逐项处理

### F-01 字体

- [x] 删除旧 `NixOS/desktop/fontconfig.xml` 的苹方/冬青别名与本地字体依赖。
- [x] `pkgs/monolisa-nasy/` 包含 Normal/Italic；复制文件与本机原件 SHA-256 一致。
- [x] `System/Common/desktop/fonts.nix` 两平台安装 MonoLisa、LXGW、DejaVu、Nerd symbols、Noto Sans Symbols 2。
- [x] Linux sans/serif 为 MonoLisa → LXGW WenKai，monospace 为 MonoLisa → LXGW WenKai Mono；emoji 由 Linux Noto Color Emoji 提供。
- [x] 上轮 Deck 隔离 Fontconfig（不含旧用户字体目录）字符匹配验证通过：西文、简中、繁中、等宽中文全部来自受管字体。
- [x] 旧 Deck 字体文件未删；其 MonoLisa 正/斜体与受管包逐字节相同。旧副本优先匹配不等于新机器缺文件。
- 例外：MonoLisa 为专有字体，纳管不授予公开分发权；发布仓库/二进制缓存前需确认授权。
- macOS 无同等 Fontconfig 的全系统 UI 字体开关；安装字体并让受管应用显式选择，不替换系统 UI 字体。

### F-02 WezTerm/bar

- [x] bar 固定提交 `af6642a004942d6b58b777d002cb7ee82ca94872` 与哈希，HM 部署到 `~/.config/wezterm/bar`，本地加载。
- [x] 替换上游依赖可变插件缓存的模块发现代码；不依赖运行时 Git 下载或旧 cache。
- [x] 当前版本 bar 可选 Spotify 模块默认禁用，其 `spt` 调用不是当前依赖；不为未启用模块额外装一套工具。
- [x] 上轮插件独立构建、Mac 独立加载、Deck 受管插件加载均通过；Deck `⇡` 与中文分别由受管 DejaVu/文楷渲染。
- [x] tmux helper 有明确 tmux PATH，Mac 亮暗切换不依赖 GUI 的 shell PATH；Linux 固定 Mocha，背景透明。
- 范围外：若手动把 Lua 复制到 Windows，必须连同 bar 目录和字体部署；单文件复制不属于本轮保证。

### F-03 mpv/Yazi/LocalSend

- [x] `System/Common/desktop/apps.nix` 纳管 `mpv/mpv.conf`：`save-position-on-quit`、`volume-max=300`，共享平台不重复安装 mpv。
- [x] Linux Yazi 图片默认 qimgv，视频默认 mpv；其他文件保留合适的 edit/open/extract 默认行为。
- [x] 各本地文件类型与兜底规则可选 LocalSend；`O` 菜单选择发送，`g s` 直接发送所选文件；远程 VFS 文件先下载。
- [x] qimgv/mpv/localsend_app 均有 Linux 包来源，不依赖手写 bin 目录；上轮实际生成 TOML/快捷键已核对。
- [ ] 用户实际打开图片/视频、发送测试文件的交互验收未确认；不擅自发送私人文件来勾选。
- 排除：qimgv 自动保存 GUI 配置、旧内嵌 mpv 路径和旧 GUI 脚本不作为迁移目标；不擅自删改其保存文件。

### F-04 Fcitx5/Rime

- [x] `NixOS/desktop/input-method.nix` 提供 Rime addon、nixpkgs 雾凇、小鹤双拼、keyboard-us/rime 列表及 Ctrl+Shift+Space。
- [x] Catppuccin 候选主题声明；仅部署静态文件，ignoreUserConfig=false；userdb/installation/user/build 状态保持本地。
- [x] 删除 Emacs Shift 集成中重复的裸 `pkgs.fcitx5` 安装，避免遮蔽带插件 wrapper 和 XDG autostart；测试包含禁止回归的断言。
- [x] 上轮全新临时 userdir 生成小鹤 schema/prism 成功；该过程没有复制旧训练数据，已加入 desktop-boundaries。
- [x] 上轮 switch 后自动启动使用 fcitx5-with-addons；D-Bus 实时列表含 keyboard-us/rime，AddonForIM rime 返回 rime；系统/用户失败单元均为 0。
- [ ] 实际应用内小鹤打字由用户确认；静态 schema 构建与实时注册不冒充交互验收。

### F-05 Fastfetch/Fish/桌面偏好

- [x] `System/Common/fastfetch/` 纳管 Deck 配置及 ASCII 图，共享部署；无外置 home 图像依赖。
- [x] 上轮 Deck fastfetch 执行退出 0，ASCII 与声明源逐字节一致。HM 对同内容普通文件可能保留，不能单凭非链接就判为漏管。
- [x] Fish 保留 Nix 声明；激活只移除带官方 Fish 4.3 自动迁移标记的 frozen 文件，不删除历史、universal 变量或自写脚本。
- [x] Linux 默认浏览器 Chrome；上轮 text/html、HTTPS 的 xdg-mime 查询均为 Chrome，兼容 MIME 路径冲突已修。
- [x] Modern 光标同时声明 pointerCursor 与 Dconf；上轮实际查询为 Bibata-Modern-Ice。

### F-06 Sunshine

- [x] Sunshine 已从共享桌面移除。Deck 在 `hosts/deck/` 自己启用服务、捕获和 8282 转发；普通桌面不安装、不转发。
- [x] Deck 显式启用 Sunshine，并拥有 capSysAdmin、KMS/VAAPI/GPU/DP-1 及状态路径；旧 Deck 重复代理块已移除。
- [x] 登录认证保留；配对、证书、应用列表每实例初始化，不公开纳管；不会为远程访问关闭认证。
- [x] 上轮原代理实测首页 200、后台 401；401 代表需登录，并非不可达。
- [ ] 新公共代理布局待本轮构建/实际部署后回归；旧结果不能替代新布局验收。
- 网络前提：HTTP 代理只用于可信 LAN；不可信网络通过 SSH/TLS。后台可访问不等于全新无输出设备必定能捕获画面，捕获前提属实例。

### F-07 OpenList/Deck 首页

- [x] OpenList 服务及安装移到 `hosts/deck/openlist.nix`，普通桌面/无头 fixture 不默认启用。
- [x] 保留 Deck 的工作目录和既有数据所有权；不读/搬运 `~/data/config.json`、数据库或日志。上轮服务 active。
- [x] 首页 `hosts/deck/center/index.html` 纳管，nginx root 为 Nix 输出；上轮 HTTP 内容与跟踪文件逐字节相同，不再依赖 `/kk/center`。
- [x] Wi-Fi 192.168.0.1、PC:9090、Surge 地址只作为 Deck 局域网导航；不是承诺 rebuild 会部署外部设备/服务。
- [ ] 首页 qBittorrent 8080 入口待 Enhanced-nox 部署后验收；此前只有 GUI 的缺口由 F-08 修复，不重复列作新决策。

### F-08 qBittorrent Enhanced-nox

- [x] 正式 release-5.2.4.10 对应 `ec66016a20d4dc7ba0f5bf4587b9d0577f2f886c`，源码固定哈希。
- [x] 删除旧 qbittorrent GUI 开发分支覆盖；仅覆盖 Enhanced-nox，版本求值已确认 5.2.4.10，不是旧 unstable 提交。
- [x] `NixOS/server/qbittorrent.nix` 仅在实例启用服务时配置；Deck 显式启用，普通桌面/无头 fixture 默认不启用。
- [x] 公共政策：WebUI 8080、认证保护开启、ngosang trackers_all URL；tracker 键已对照最终发布源码。
- [x] 下载路径由实例声明，默认独立服务目录；补充 tmpfiles 的下载目录所有权，避免第一次启动的非 root 服务不能创建 sibling downloads。
- [x] `qbittorrent-policy.py` 只合并公开政策键，保留实例密码/用户名与未声明设置；原子写入 0600。之前合成幂等/保密字段保留测试通过。
- [x] 永久回归测试 `tests/qbittorrent-policy.py` 已执行：空实例、保留凭据、幂等、文件权限、拒绝破坏非法配置均通过；本机 Nix sandbox 的 qbittorrent-policy 检查也构建通过。测试导入不在源码目录留下 bytecode。
- [ ] 最新包编译、tmpfiles/服务启动、首登认证、WebUI 和 tracker 获取尚未验证，不能宣称已部署。
- 私有边界：不迁移旧 GUI profile、torrent/resume、PT passkey、下载内容；新实例在 WebUI 设置私有密码，绝不提交固定密码/哈希。
- 动态边界：URL 固定，列表内容动态更新是预期；不将其当成固定源码下载。不在声明式构建中偷偷联网获取列表。

### F-09 Pi 插件

- [x] Pi flake、multi-account tarball/lock/npmDeps、session-kit tarball 均固定来源；主题补丁及测试在仓库。
- [x] session-kit 仅需 Pi 宿主 API/Node 内建模块及 zip/unzip；共享包表已有命令。可选 Codex/Claude 会话导入不是必须部署那些程序的理由。
- [x] Mac 学习扩展固定 Eero 输入：web-fetch 使用固定 npmDeps，图像工具有 mmdc/librsvg/ImageMagick，PDF 有 PyMuPDF Python；输入法 reporter 的 tmux/python/原生执行器来源受管。
- [x] Mac 学习私有工作流不擅自装到 Linux；Linux 当前公共插件集合按已有声明复现。
- [x] models、provider、failover、session-kit 设置、auth、sessions 与搜索 API key 属每实例/运行状态，不要求从旧机器复制。
- 限制：这是固定版本的依赖入口审计，不是对第三方全部源码进行安全证明；升级插件仍需重查依赖。

### F-10 Obsidian/其他受管 GUI 资源

- [x] Obsidian 主题 CSS/manifest 固定提交和哈希；本地两个插件源码在仓库，模块依赖是宿主 API，构建工具由 Nix 声明。
- [x] 默认外观、快捷键、CSS 及插件入口纳管；Mac 程序补丁在构建期应用并签名，不依赖手工改 app.asar。
- [x] 笔记、vault 内容、核心插件用户选择、workspace 和索引状态未强制复刻；本轮仅保证声明的默认体验，不纳管整份用户 vault。
- [x] Linux Niri/Waybar/rofi/GTK/Kvantum/Papirus/Bibata/壁纸资源有包或仓库来源；Niri 主配置与主机显示注入都受管。
- [x] Niri 调用 wezterm/rofi/wpctl，有对应程序/集成声明；无 Downloads 下旧 KDL 或用户脚本依赖。
- [x] GUI Emacs/原生 Rime 桥由本仓库安装；独立 Emacs 用户工作流已按用户要求排除。

### F-11 已删除遗留项

- [x] Zellij 模块/导入注释及 latest zjstatus 引用删除。
- [x] Codex CLI 模块、OpenCodex 环境变量、Zsh/p10k/completion/homefile 及 treefmt 遗留项删除。
- [x] 未启用 Foot/SMB 模块、禁用 sing-box 服务定义删除。
- [x] 旧 qBittorrent GUI overlay 删除，保留正式 Enhanced-nox 包定义。
- 未做：清空认证文件、删除日志/历史、卸载 macOS 系统自带 shell、清理旧用户目录或游戏数据。

## 3. 实例输入与外部前提（不是公共缺陷）

- [x] `hosts/deck/hardware.nix`：ZFS dataset 名、EFI/SD 设备、/boot 权限；安装者按本机硬盘准备。
- [x] Deck hostname/hostId、Jovian/内核、显示输出、供电策略与硬件映射留在主机层。
- [x] Deck Sunshine 捕获参数、实例状态路径、下载目录、OpenList 及 nginx 局域网导航留在主机层。
- [x] 固定公共用户名 keke 是仓库约定，不误报为遗漏的私有输入；hostname 由各主机提供。
- [x] 登录密码、SSH/GPG/应用认证、NetworkManager 连接、Sunshine 配对每实例初始化；不扫描或复制秘密。
- [x] 现有 `readme.org` 包含具体磁盘格式化示例，仅是旧 Deck 安装笔记，不是应在其他实例直接执行的自动化方案；本轮未执行其中命令。
- [x] `/opt/containerd`、旧备份/unused 目录本身不被当前仓库引用，不因为旧机器存在就作为新机依赖安装，也不擅自删除。

## 4. macOS 例外与已排除应用

用户明确接受 macOS 系统限制；以下不阻塞 Deck 公共配置验收：

- [x] Homebrew/cask 名称纳管，但版本随 tap/app 自更新，不能声称 flake.lock 锁定所有 GUI 程序。已有 autoUpdate/upgrade=false 也不等于历史版本固定。
- [x] ImageGlass 暂按手工安装例外保留，duti 规则需要应用存在；官方 cask 收录后再复查。
- [x] Hammerspoon/Karabiner/Rime 静态文件与执行器依赖受管；辅助功能、输入监控、输入源启用、Keychain、应用授权是系统/用户前提，不尝试规避权限。
- [x] Mac 串口别名中的具体设备属于 macOS 私有工作流，不搬进 Linux。
- [x] 其他仅盘点到的 GUI 偏好/数据库（calibre、Heptabase、MarginNote、Spotify 等）不作为本轮 Deck 阻塞项；没有据此擅自迁移。
- [x] Chrome/Safari 脚本与沙盒内容曾遇 macOS 权限限制：未检查部分明确留为未覆盖；Chrome 扩展后来已由用户指定账户同步，不绕过权限。
- [x] IINA、Anki、GoldenDict、Surge、Tinycast、Moonlight 等按用户明确决定排除，不重复列为待完成。

## 5. 仓库覆盖记录

检查方法：核对导入树与启用状态，扫描全部第一方文本中的 home/绝对路径、外部 URL、下载与执行入口；按所属模块追踪资源和命令来源。二进制字体比对哈希，图片资源核对是否跟踪。不是只看 enable 布尔值，也不把未导入文件当实际运行依赖。

| 区域                                 | 检查内容                                                            | 结论                                                         |
| ------------------------------------ | ------------------------------------------------------------------- | ------------------------------------------------------------ |
| flake.nix / flake.lock / treefmt.nix | 原生 outputs、平台组装、input pin、overlay、检查入口                | 无新增 mutable 构建来源；QBE/策略回归检查已接入待跑          |
| System/Common 根层                   | 导入树、Fish/Git/tmux/Yazi/Pi/终端 Emacs、Python/开发工具           | 第一方资源有来源；账户/历史不复制；旧 shell 模块已移除       |
| System/Common/desktop                | 字体、WezTerm/bar、共享 apps、Obsidian 插件/CSS、GUI Emacs/原生模块 | 资源自带或固定获取；用户 dotfiles/vault/账户另界定           |
| NixOS/server                         | 引导/locale/用户基础、udev/开发工具、Enhanced-nox                   | 公共服务不默认套用实例；旧 OpenList/SMB/sing-box 已分离/删除 |
| NixOS/desktop                        | session/theme/font/input/Waybar/Niri/Yazi/代理                      | 无反向读取 Deck 文件；Sunshine 捕获属主机，资源有固定来源    |
| hosts/deck                           | 硬件、显示、Jovian、服务启用、网页和网络                            | 机器差异留此；静态网页已纳管；秘密不入 store                 |
| hosts/mba / macOS/private            | 私有集成、Brew、launchd/IME、Rime、学习扩展及脚本                   | 共享配置不复制；Mac 系统授权/自更新例外明确                  |
| pkgs                                 | Emacs patches、xrock、Weylus、QBE、MonoLisa                         | 源码/patch 哈希固定；字体授权边界已记录                      |
| tests / 本地测试脚本                 | 测试依赖、fixture、失败断言                                         | 准备统一执行；不读私人数据库或真实凭据                       |
| README / AGENTS / 静态资源           | 部署约束、安装笔记、资源引用                                        | 文档中的外部服务/手工步骤不冒称 Nix 自动恢复                 |

未声称覆盖：第三方全部传递源码的安全审计、应用用户数据库语义、Mac 被权限阻止的内容、实际全新设备安装、Windows。

## 6. 验证账本与剩余统一验收

### 已有实机证据（旧部署，不套用于本轮新修改）

- [x] Deck 上轮 `desktop-boundaries` 构建通过，包含无 Jovian 普通桌面/无头与全新 Rime schema 部署。
- [x] 上轮完整系统 build/switch 成功，Home Manager Result=success/ExecMainStatus=0，系统/用户失败单元均为 0。
- [x] 当时 nginx/OpenList/Sunshine active：首页 200、认证后台 401；Fcitx wrapper 与 Rime 注册通过。
- [x] 当时字体隔离匹配、Chrome 默认关联、Modern 光标、受管 Yazi/mpv/Fastfetch/bar 路径已核对。
- 旧最终系统：`/nix/store/bkf9wq80p08crj66s4qibw46zdvqviyl-nixos-system-deck-26.11.20261110.a9cb3b1`。
- 旧日志：`/tmp/deck-repro-fcitx-switch.log`；首次 HM MIME 冲突和裸 Fcitx 问题已在该成功之前修复。

### 清单走完后的统一验证（本机部分已执行）

- [x] 新增配置/资源/测试已纳入 flake 可见工作树；本轮没有重置或覆盖用户其他工作区内容。
- [x] 修改文件格式化与 `git diff --check`；已核对无 Codex/Zsh/Foot/SMB/sing-box 运行定义。treefmt 首次因 checklist 表格和此前首页 HTML 的格式失败，已按格式器修正，未改变首页逻辑；最终 `checks.aarch64-darwin.treefmt` 与 `qbittorrent-policy` 重跑均构建通过，日志 `/tmp/checklist-final-checks.log`。
- [x] 合成 qBittorrent-policy 回归 3 项测试通过，覆盖空实例、幂等、保留认证、0600、非法配置不破坏；Nix sandbox 检查构建通过。
- [x] 两平台完整配置求值与 desktop-boundaries derivation 求值通过，覆盖公共桌面/无头断言、Sunshine proxy 实例开关、QBE 5.2.4.10、下载目录所有权；Linux 边界检查的构建仍待下项。
- [x] `nix build .#darwinConfigurations.mba.system --no-link` 完整构建成功；未激活。日志 `/tmp/checklist-mba-build.log`。未调用 darwin-rebuild check/switch。
- [ ] Linux `desktop-boundaries` 完整构建；Enhanced-nox v5.2.4.10 构建；Deck 完整系统构建。最新检查 SSH 连接超时，未同步新工作树、未在旧仓库上冒充执行新检查；等待 Deck 可连接。
- [ ] 需要部署时明确执行 switch 并验证：服务无失败、Home Manager、nginx/认证后台、Enhanced WebUI 登录和下载目录权限。
- [ ] Tracker 获取是运行网络检查，不与离线构建可复现性混为一谈；不为测试下载真实种子。
- [ ] 用户确认 Yazi 打开/发送、实际小鹤输入；不擅自向远端发送私人文件。
- [ ] 核对两边仓库内容/提交，同步 checklist；未经要求不强制覆盖工作树、不推送远端。
- [ ] 是否在全新 home/机器验证由用户批准，不启动虚拟机或破坏现有数据。

## 7. 完成标准

公共配置与资源有明确固定来源；实例输入只在主机层；秘密和动态状态不进入公开 store；排除项有用户依据；求值、构建、激活、交互结果分别记录。只有上述验证完成后才能说最新配置构建/部署通过，不能说所有应用数据或所有硬件都已完全可复现。
