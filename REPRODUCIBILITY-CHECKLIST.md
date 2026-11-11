# 全平台配置可复现性 Checklist

## 目标与执行规则

目标：新机器仅靠本仓库、锁定的资源和明确记录的私有恢复步骤，得到预期的 macOS / Linux 环境；不依赖旧机器上未说明的手工安装或隐藏配置。

本文件是长期审计、用户决策与验收记录，不是“已全部修复”的声明。

- 当前范围：整个 flakes 仓库 + macOS 本机 + Deck 只读审计。macOS 接受系统限制，不追求完全复现；重点为 Deck。
- 当前状态：首轮盘点中，尚未完成全量深查。下文区分已确认问题和待查项。
- 配置由 Nix 生成，不代表其字体、插件、脚本、外部服务或用户数据全部可复现。
- 存在普通配置文件，不等于其中全部是用户定制；需区分默认值、缓存、历史和主动修改。
- 不为审计擅自迁移配置、安装软件、重建系统、删除数据或清理 stash。
- 用户决定采用方案后再实施。每项只有满足验收条件才勾选，并补充提交、验证命令及结果。
- 私钥、账户令牌、订阅地址、密码、客户端证书和应用数据库不进入公开 Git / Nix store；检查时不抄录秘密值。
- 不因某次求值成功就宣称构建、激活或新机器恢复成功。

状态：`已确认` / `待深查` / `待用户决定` / `待实施` / `待验收`。

处理方式：`Nix/Git 纳管` / `固定资源` / `私有备份` / `手工授权步骤` / `删除依赖` / `接受差异并记录`。

## 用户已作出的范围决策（后续审计必须遵守）

- Emacs 用户配置由用户单独管理；不迁入 flakes，不继续审计 Elpaca/用户配置恢复。
- IINA、Anki、GoldenDict、Surge、Tinycast、Moonlight 的本地配置/数据不要求复现；不迁移、不删除现状，不再作为本项目未完成项。
- ImageGlass 若官方 Homebrew 尚未收录，暂不处理安装缺口；已查询官方 cask 全量 API，无匹配项。
- Zellij 已废弃：删除仓库模块及遗留导入注释；不迁移其插件。
- mpv 两项本地设置迁入共享桌面配置，Mac/Linux 统一。
- Fontconfig：用户已决定废弃旧规则，简繁中文用 LXGW，日文无需求；西文用本机 MonoLisa，明确要求复制文件进 flakes 纳管。
- MonoLisa 属专有字体；按用户要求复制，但发布仓库或二进制缓存前需确认分发授权，不能把“用户要求纳管”等同于已获得公开再分发权。
- bar.wezterm 改为 Nix 固定源码部署，保留当前缓存所用提交，避免顺便升级行为。

## 0. 总验收门槛

- [ ] **SCOPE-01 仓库全覆盖**：逐一检查全部受 Git 跟踪的配置、脚本、资源及其跨文件引用；记录未覆盖项。
- [ ] **SCOPE-02 macOS 本地覆盖**：核对安装的软件、配置目录、偏好、插件、启动项及本地脚本；不能只看 flake 包表。
- [ ] **SCOPE-03 Deck 本地覆盖**：开机后只读盘点 Linux 的实际软件、配置、字体、服务及与仓库的偏差。
- [ ] **SCOPE-04 外部依赖闭环**：每个受管程序引用的命令、字体、插件、路径和外部服务都有来源或恢复说明。
- [ ] **SCOPE-05 私有恢复闭环**：每类必需私有状态都有备份范围、恢复顺序与权限说明，不提交内容。
- [ ] **SCOPE-06 平台验证**：macOS 完整求值/构建；Deck 完整系统求值/rebuild；Linux `desktop-boundaries` 检查；保留无头层边界。
- [ ] **SCOPE-07 无旧 home 依赖验证**：在用户批准的干净用户目录/机器验证静态配置可恢复。未批准前不启动 VM、不切桌面会话、不破坏旧 home。
- [ ] **SCOPE-08 最终决策完成**：所有发现均有用户决定；被接受的非可复现部分明确列为例外，不悄悄当作完成。

## 1. 仓库：已确认的外部依赖与不可复现项

### F-01 Linux Fontconfig 与私有字体

- [ ] 状态：用户已决定并完成配置修改，待激活与实际匹配验收。
- 新实现：删除旧 `NixOS/desktop/fontconfig.xml`；`NixOS/desktop/fonts.nix` 为 sans/serif 指定 MonoLisa Nasy → LXGW WenKai，monospace 指定 MonoLisa Nasy → LXGW WenKai Mono；不新增日文字体策略。
- MonoLisa 正体/斜体已从本机复制到 `pkgs/monolisa-nasy/fonts/`，与原文件 SHA-256 一致；共享 `fonts.nix` 两平台安装，不再依赖旧 home。包构建成功，Mac/Deck 完整系统及边界检查 derivation 求值通过。尚未完成 Linux 构建/激活及实际 `fc-match`。
- macOS 无等同 Fontconfig 的统一系统字体替换；本仓库安装字体供应用使用，WezTerm 显式选择 MonoLisa/共享回退。macOS 系统 UI 字体未替换。
- 以下为改动前历史发现：
- 原位置：`NixOS/desktop/fontconfig.xml`、`NixOS/desktop/fonts.nix`。
- 引用了 MonoLisa Nasy、PingFang SC/TC、Hiragino Maru Gothic ProN；有 `Ping Fang SC` 与 `PingFang SC` 命名差异，需核实匹配结果。
- 上述字体不都由共享字体模块提供；新 Linux 主机会回退或缺少原有字形，不能复现现有字体效果。
- macOS 本地另有普通文件：MonoLisa 正体/斜体、Bookerly 系列、思源宋体 SC、仓耳今楷。系统自带字体不等于 Linux 可用。
- 当前基础：`System/Common/desktop/fonts.nix` 声明仓库内 MonoLisa、DejaVu、文楷、Nerd symbols、Noto Sans Symbols 2；其他私有字体不属于此次默认字体方案。
- 决策已定：默认西文 MonoLisa（文件纳管），简繁中文文楷，删除旧别名与日文字体规则。
- 验收：每个实际要求的 family 有来源；Mac/Linux 分别验证匹配和关键字符；明确哪些仅为可选首选。

### F-02 WezTerm 运行时插件

- [ ] 状态：已获批准并完成配置修改；插件 Nix 构建成功，WezTerm 独立配置本地加载检查退出 0；macOS / Deck 完整系统 derivation 求值成功。待实际激活、GUI 行为及 Deck 构建验收，暂不勾选。
- 位置：`System/Common/desktop/wezterm.nix`。已改为固定提交 `af6642a004942d6b58b777d002cb7ee82ca94872` 与 SHA-256，由 Nix 部署到 `~/.config/wezterm/bar`，本地加载；仅替换上游依赖插件缓存的模块发现代码。
- 原位置使用 `wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")`。
- Lua 配置受管，但 bar 插件运行时下载且未由本仓库固定提交和哈希；旧插件缓存可能掩盖问题。
- 同时需核对 bar 插件内部的字体/资源和其他运行时依赖。
- 决策：固定插件源码并由 Nix 部署 / 内置必要代码 / 接受运行时更新。
- 验收：清空插件缓存的环境可获得同一版本；不依赖运行时默认分支。

### F-03 Zellij 的 latest 插件

- [x] 状态：按用户决定废弃并删除整个 Zellij 模块及导入注释；latest 引用随之删除。未删除用户会话数据。
- 位置：`System/Common/zellij.nix`，`zjstatus/releases/latest/download/zjstatus.wasm`。
- 不同时间下载内容可能不同；不能由 flake.lock 固定。
- 决策：固定版本和哈希 / 删除未用配置 / 接受例外。
- 验收：实际启用的插件不使用 mutable latest 地址。

### F-04 Emacs 用户配置不在本 flake 内

- [x] 状态：用户明确排除；Emacs 配置单独管理，不属于本项目关闭门槛。以下为历史发现，不继续展开。
- 本机：`~/.emacs.d/` 为独立 Git 工作区，有 `early-init.el`、`init.org`、`init.el`、`elpaca/`、`tree-sitter/`、`eca/`。
- 仓库：`System/Common/emacs.nix` 和 `System/Common/desktop/emacs*.nix` 管理程序及部分原生模块，不等于部署整套用户配置。
- 待查：独立仓库来源/提交/未提交修改；Elpaca 锁定；启动时下载；编译产物；外部程序、字体、字典、模型、项目路径。
- 决策：固定外部配置仓库并引用 / 将静态配置迁入共享层 / 保持独立但定义恢复契约。
- 验收：无旧 `.emacs.d` 时可恢复同样配置，插件版本和原生依赖明确；历史、认证、缓存分离。

### F-05 Codex 外部服务及平台路径

- [ ] 状态：已确认，待用户决定。
- 位置：`System/Common/codex.nix`。
- 共享配置内有 `/Users/keke/...` 项目信任路径；Linux 不具有相同路径。
- `opencodex` provider 指向 `http://surface:10100/v1`，依赖另一台机器、网络、服务和认证。仅配置该 provider 不代表当前默认会使用它。
- 决策：路径按平台生成；外部 provider 可选化或记录部署前提。
- 验收：新机器默认可启动；可选 provider 缺席时不误报整套环境已恢复；密钥有私有注入途径。

### F-06 Homebrew 软件不是 flake.lock 锁定版本

- [ ] 状态：已确认，待用户决定可接受的版本边界。
- 位置：`macOS/private/system.nix`、`macOS/private/input-method.nix`。
- cask 名称受管，但 tap 元数据、下载资源、应用自动更新会变化。`autoUpdate = false` / `upgrade = false` 不等于将 cask 固定到历史版本。
- 本机已见 cask 记录与应用版本不同，例如 DingTalk、Heptabase；这可以由自更新引起，不能据此判定安装损坏。
- 决策：接受应用跟随更新 / 重点应用固定来源 / 对支持的平台使用 Nix 包。
- 验收：逐项标明“保证安装”还是“保证同版”；记录额外 tap 的恢复前提。

### F-07 默认图片程序未由 flake 安装

- [x] 状态：用户接受暂不处理。已查官方 Homebrew cask API 的 `imageglass` 端点（404）及全量 cask 列表（无 ImageGlass）；不据此声称未来也不会收录。
- 位置：`macOS/private/system.nix` 的 duti ImageGlass 关联。
- 本机 `/Applications/ImageGlass.app` 存在，但当前 Homebrew cask 声明未列它；新机器只有关联规则而没有对应应用。
- 决策：声明安装 / 更换默认程序 / 将其列为手工安装前提。
- 验收：干净机器的默认图片关联能找到已安装的应用。

### F-08 Linux OpenList 状态与启动目录

- [ ] 状态：已确认，待定义私有恢复方式。
- 位置：`NixOS/server/services.nix`，以用户 home 为工作目录启动 OpenList。
- 服务定义受管；实际配置、数据库、挂载源与登录状态不由该定义恢复。
- 决策：静态参数纳管；数据库/凭据私有备份，明确运行用户与文件位置。
- 验收：新机器能按步骤恢复预期挂载，而不仅是启动空白服务。

### F-09 可选 sing-box 外置配置

- [ ] 状态：已确认，但当前服务禁用，不属于当前启动阻断。
- 位置：`NixOS/server/services.nix`，`~/.config/sing-box/config.json`。
- 决策：继续禁用并说明 / 定义私有配置部署方案。
- 验收：启用时必需文件、权限、订阅和更新方式都有来源。

### F-10 Deck 局域网网页与外部设备

- [ ] 状态：仓库引用已确认，Deck 实际文件待查。
- 位置：`hosts/deck/center.nix`，网页根目录 `/kk/center`；反向代理另依赖局域网设备地址。
- 网页内容不随当前 flake 自动提供；网络拓扑也不会被 rebuild 创建。
- 决策：网页纳管或固定资源；局域网地址/服务作为明确部署输入。
- 验收：新 Deck 部署得到网页内容；无目标设备时有明确限制说明。

### F-11 Sunshine 客户端状态与证书

- [ ] 状态：仓库引用已确认，Deck 私有恢复待查。
- 位置：`hosts/deck/configuration.nix`，Sunshine state/credentials 指向用户目录。
- 系统、服务、捕获参数受管；配对证书、账户和客户端数据库不是静态公开配置。
- 决策：私有备份恢复 / 新机器重新配对。
- 验收：明确恢复目录、权限和顺序；不将私钥/配对状态放到公开 store。

### F-12 Shell 的可选外部环境

- [ ] 状态：已确认引用，待检查实际影响。
- 位置：`System/Common/zsh.nix`，可选 `/home/me/.opam/opam-init/init.zsh`、`$HOME/.local/share/bin`。
- opam 文件有存在性判断，缺席不必然报错；但其提供的环境和本地命令不受本 flake 保证。
- 决策：移除遗留路径 / 定义可选工作流 / 纳管实际使用的工具。
- 验收：不用旧 home 也能解释完整 PATH 和依赖；未使用项不伪装成必需项。

## 2. macOS：已发现的本地配置与资源

以下条目表示“存在本地配置/数据”，不表示必须把整个目录公开纳管。逐项区分静态设置、自动生成默认值与私有状态。

### M-01 媒体与下载程序

- [ ] **mpv**：用户批准纳管；已在 `System/Common/desktop/apps.nix` 用 HM 声明 `mpv/mpv.conf`，设置 `save-position-on-quit`、`volume-max=300`，Mac/Linux 共用。待构建/激活验收；现有普通文件须安全备份后再激活，不能直接覆盖。`watch_later/` 不改动。
- [x] **IINA（用户排除，不迁移）**：`~/Library/Preferences/com.colliderli.iina.plist` 有本地偏好；`~/Library/Application Support/com.colliderli.iina/plugins/` 有 Online Media 0.9.10、OpenSubtitles 0.9.6、User Scripts 0.9.3。插件安装、启用状态、脚本和 Online Media 下载器依赖待深查；账户不要提交。
- [ ] **qBittorrent**：`~/.config/qBittorrent/qBittorrent.ini`、`qBittorrent-data.ini` 及 Application Support 下 RSS / `BT_backup/`。设置与下载目录可选择纳管；任务、凭据、历史分开备份。是否仍使用待确认。
- [ ] **Spotify**：程序由 Nix/SpotX 提供；用户偏好、登录及本地资料位于 Application Support，需盘点静态设置与账户的界限。
- [ ] **OBS**：存在 `~/Library/Application Support/obs-studio/`，包括 `basic/scenes/Untitled.json`、`basic/profiles/Untitled/`、`plugin_config/`；当前未在 `/Applications` 顶层看到 OBS.app，可能是残留。待确认是否使用、场景引用的媒体/字体/设备路径；直播密钥不入 Git。

### M-02 学习、笔记、词典

- [x] **GoldenDict-ng（用户排除，不迁移）**：`/Applications/GoldenDict-ng.app` 不在当前 cask 安装清单；`~/.goldendict/config` 引用 `~/MyDicts`，另有 styles、favorites、history。`MyDicts` 中有 OALDPEX、ODE glance、myLM6。程序来源、静态配置、词典授权/内容、可能的本地服务依赖分别追踪，不能直接提交词典。
- [x] **Anki 插件（用户排除，不迁移）**：`~/Library/Application Support/Anki2/addons21/` 有 Migaku、Elemental Anki Interactive Heatmap、Edit Field During Review、Anki-Connect、Sentence Translator、Local Audio Server for Yomichan。插件及其自定义配置未由 flake 固定。待检查本地音频目录、服务、外部 API 和脚本依赖；卡片、媒体、账户走私有恢复/同步。
- [ ] **Obsidian**：本机注册 vault `~/Learning`。`appearance.json`、`community-plugins.json`、`hotkeys.json`、主题和 CSS 已有 Nix store 链接；`core-plugins.json` 是本地文件。插件外层目录为普通目录，不能据此判定插件代码未受管，需继续逐个检查内部文件来源。笔记、附件、工作区和索引状态另行备份。
- [ ] **calibre**：`~/Library/Preferences/calibre/` 有 GUI 设置、转换设置、阅读器配置、字体目录、全局设置等；需核实自定义部分及书库路径。电子书、数据库与账户独立恢复。
- [ ] **Heptabase / MarginNote**：程序由 cask 安装，笔记、数据库、工作区和用户设置依赖本地/云端。确认哪些快捷键/界面配置需导出，哪些只需要账户恢复。

### M-03 网络、快捷键与 GUI 设置

- [x] **Surge（用户排除，不迁移）**：`~/Library/Application Support/Surge/Profiles/` 有 `KK.conf`、另一份命名配置和 `.managed/`；配置、规则及模块可能引用外部资源。待脱敏深查；订阅和代理凭据必须私有。
- [x] **Tinycast（用户排除，不迁移）**：偏好存在自定义窗口管理快捷键等键；Application Support 有 quicklinks 数据库、extension-data、launcher-ranking 等。区分快捷键/扩展配置与剪贴板、历史和私有链接；不可把整个数据库提交。
- [ ] **ImageGlass**：`~/Library/Application Support/ImageGlass/igconfig.json`、`_themes/`、`_plugins/` 等存在；确认真正自定义项和插件/主题内容；同时处理 F-07 安装缺口。
- [x] **Moonlight（用户排除，不迁移）**：`~/Library/Preferences/com.moonlight-stream.Moonlight.plist` 包含本地主机、串流选项、配对相关字段；flake 只声明部分偏好（例如鼠标模式）。设置可选择纳管，配对证书与密钥仅私有备份或重新配对。
- [ ] **LocalSend**：App 由 cask 安装，容器内设置/身份/历史待查；`~/.config/localsend-cli/` 也存在，需判断是否已弃用的 CLI 残留。
- [ ] **Karabiner / Hammerspoon**：已有 Nix 配置集成，仍需确认实际加载文件全部受管、是否有额外用户规则、模块、绝对路径或本地修改。辅助功能/输入监控授权需手工恢复说明。
- [ ] **Rime / Squirrel**：基础方案与专用字体受管；用户训练词库、`user.yaml`、`installation.yaml`、同步目录等是用户状态。记录私有恢复边界，检查是否有额外自定义方案/脚本未受管。

### M-04 AI、CLI 与编辑器

- [ ] **Pi**：扩展/skills 部分由 Nix 提供；本机仍有可变 `settings.json`、`models.json`、`models-store.json`、failover 配置、npm 目录等。只检查脱敏的配置结构与依赖；auth、多账号 OAuth、API key、sessions 和日志不公开纳管。确认哪些自定义 provider/model/failover 设置应静态化。
- [ ] **Codex**：确认实际配置哪些由 HM 覆盖、哪些是本地追加；认证、会话及外部代理依赖分离。
- [ ] **Fish**：核对 `~/.config/fish/` 内实际 conf.d、functions、通用变量与 Nix 声明的差异；history 不属于静态配置。
- [ ] **Zsh**：本机 `~/.zshrc` 是普通文件，需与 Nix 生成/声明的 shell 设置对照，确认是否仍使用、是否引用本地脚本/路径。
- [ ] **其他 CLI**：本机 `~/.config/` 下有 btop、eca、gh、gtk-3.0、htop、mihomo 等目录；逐项判定设置来源、实际使用、外部程序及凭据。mihomo 的配置与数据库存在，不等于代理工作流已被声明。
- [ ] **Zed**：Application Support 有 extensions/languages/external_agents/debug_adapters 等运行目录；确认应用是否仍在使用、配置在哪里、哪些语言服务器/扩展动态下载。
- [ ] **全局包与自装命令**：继续核对 npm / uv / pip / Ruby / Cargo / 本地 bin 等入口。当前用户 `nix profile list --json` 返回空 elements；这不能证明所有程序都已纳管。

### M-05 安装来源与启动项

- [ ] **非 cask / 非 Nix 的应用**：本机看到 GoldenDict-ng、ImageGlass、Quark、WPS、Userscripts、uBlock Origin Lite、红果短剧等，不在当前 brew cask 列表；需区分 App Store、侧载、手动安装、残留。Safari 为系统应用，不作为漏装项。
- [ ] **程序受管但配置外置**：Anki、Chrome、Surge、Tinycast、聊天/云盘软件等不能因 cask 声明就勾选整套恢复完成；需按本表分离静态设置、账户与数据。
- [ ] **启动项与权限**：用户 LaunchAgents 有 Google 更新项和 `org.nix.input-method.plist`；后者即便是普通文件也可能由 Nix 激活生成，需比对内容来源后判定。系统 LaunchDaemons 另见 Surge helper、Kairos awdltool helper；查来源、是否仍需、授权/服务恢复步骤。
- [ ] **本地其他工作流仓库**：`~/Repos/` 有 enableMacosAI、Kiki-Immersion-Safari、resume、sing-box-nix-builder 等；只按“是否被当前配置/启动项调用”排查，不自动把所有项目或个人文档纳入系统配置。
- [ ] **macOS 系统状态**：输入源启用、隐私权限、登录项、默认关联、Keychain、应用授权和 App Store 登录分别核对；不能默认 nix-darwin 覆盖全部系统状态。

## 3. 检查受限与尚不能下结论的部分

- [ ] **PERM-01 Chrome**：读取 `~/Library/Application Support/Google/Chrome/Default/Extensions` 遇 macOS `Operation not permitted`。扩展版本、配置、用户脚本、下载的本地组件尚不能确认；需用户授权后查或通过浏览器导出。不得绕过权限后声称原审计已覆盖。
- [ ] **PERM-02 Safari Userscripts**：其 Group Container 读取遇权限限制。脚本源码、脚本目录选择和外部 URL 待用户授权/导出。
- [ ] **PERM-03 沙盒应用**：容器及 Group Containers 的部分设置可能受限；目录名盘点不等于内容审计完成。
- [ ] **COVER-01 本地静态配置深查**：目前不保证所有 plists、SQLite、应用私有格式都已解析。需补充“已确认用户定制”的具体键和资源依赖，避免把自动生成数据全当配置。
- [ ] **COVER-02 外部仓库/插件内部依赖**：固定入口后还要检查内部下载、脚本依赖和可变分支；尚未对所有第三方代码作完整审计。

## 4. Deck 开机后的检查清单

- [ ] 比对 Git 提交/未提交改动、当前 system generation 与实际生效配置，避免审计旧部署。
- [ ] 盘点 `~/.config/`、home dotfiles、本地 bin、system/user profile、Flatpak/手动 AppImage 等安装来源。
- [ ] 比对 `~/.local/share/fonts`、fontconfig 实际匹配、Niri/Waybar/Emacs/WezTerm 使用的字体。
- [x] Emacs 独立配置按用户决定排除；仅验证本仓库自身声明的程序/共享原生模块，不扩展审计用户配置。
- [ ] 检查 systemd 用户/系统服务的 override、EnvironmentFile、工作目录、外置脚本、凭据和启动前提。
- [ ] 检查 Sunshine、OpenList、`/kk/center`、可选代理的静态配置/私有状态边界。
- [ ] 检查 Niri、Waybar、rofi、终端、Yazi、浏览器等本地配置是否覆盖 Nix 或引用外部资源。
- [ ] 检查磁盘挂载、硬件设备路径与局域网依赖；保留真正主机差异，不搬到共享层。
- [ ] 在 Deck 执行 `nix build .#checks.x86_64-linux.desktop-boundaries --no-link`，记录完整结果。
- [ ] 按用户批准范围完成 Deck 全系统构建/重建并核对包、内核、磁盘、用户、Niri、Sunshine；不擅自切换桌面。

## 5. Deck 实机首轮结果（2026-11-11）

只读审计，没有安装、重建、删除或同步 Deck 仓库；没有读取 Wi-Fi 密码、私钥、认证令牌或应用数据库内容。两台机器的配置版本不同，必须先区分“旧部署现象”和“当前方案缺陷”。

### D-00 基线与已核实边界

- [x] 已连接 Deck，仓库 `e96ef89` 且工作区干净；Mac 仓库为 `2aad373`。Deck 尚未包含本轮 bar/mpv/MonoLisa 与 Fontconfig 修改，不属于新方案验收。
- [x] 当前系统 `/nix/store/7hm5nly5av6q277p74y86whvrcf91gjg-nixos-system-deck-26.11.20261110.62c4d39`，内核 `7.2.10-valve1`；系统和用户 `--failed` 均为 0。
- [x] 扫描 `/etc/systemd/system`：470 个 store 文件/链接、13 个 mask，无普通本地单元；`/etc/systemd/user`：115 个 store 文件/链接，无普通本地单元；用户 `~/.config/systemd/user`：8 个 store 链接。仅表示这些目录未发现外置单元，不保证单元调用链全部可复现。
- [x] Niri、Waybar、壁纸服务、rofi、GTK/Kvantum、WezTerm、Yazi、tmux 入口指向 Nix store；不能因此略过其外部依赖。
- [x] 用户/root 的 `nix profile list --json` 均为空 elements；未发现当前 PATH 中的 Flatpak/Brew 安装器；本地仍有旧 flatpak 目录，不据此认定仍装有 Flatpak 应用。
- [ ] 当前配置同步、完整 Linux build、边界检查与激活尚未执行；仍不能关闭 SCOPE-06。

### D-01 qimgv：已失效的 mpv 路径与本地脚本

- [ ] 状态：已确认，待用户决定。
- 证据：`~/.config/qimgv/qimgv.conf:36` 的 `mpvBinary` 固定为旧 `/nix/store/dazqdlqksm989z58pf5mwskjqpnrh7aq-mpv-with-scripts-0.41.0/bin/mpv`；实机检查不存在。当前 PATH 另有受管 mpv，但这项设置仍引用旧版本。
- 同文件还定义调用 `localsend_app` 的脚本；当前命令存在，但脚本和关联快捷键没有声明。主题配置在本地 `theme.conf`。
- 候选处理：只纳管真正自定义项，下载器/播放器用稳定入口或当前 derivation；不把保存的窗口/浏览状态一并固定。
- 验收：图片浏览/视频播放与发送脚本均不依赖旧 store 目录，新机器配置可生成。

### D-02 PrismLauncher：已失效的 Java 路径

- [ ] 状态：已确认，待用户决定是否属于复现目标。
- 证据：`~/.local/share/PrismLauncher/prismlauncher.cfg` 的 `JavaPath` 为 `/nix/store/k4877vrvzk3pf4k44g1r6k454vjs8f17-openjdk-17.0.13+11/bin/java`；实机不存在，当前 shell PATH 也无 java。
- Launcher 程序受管，但 Java 选择、instances、模组、资源和版本元数据在本地。
- 候选处理：纳管 Java 运行时及选择规则；游戏实例另行定义固定版本/私有备份；或按用户决定排除整个游戏工作流。

### D-03 Fcitx5 / Rime：程序与词库受管，用户方案外置

- [ ] 状态：已确认，待用户决定。
- 实际运行 fcitx5；插件/雾凇来源由 `NixOS/desktop/pkgs.nix` 提供。
- `~/.local/share/fcitx5/rime/default.custom.yaml` 是本地文件：包含 `rime_ice_suggestion:/` 并选择 `double_pinyin_flypy`。若只重建现有系统声明，不会自动恢复这一小鹤双拼选择。
- `~/.config/fcitx5/config`、`profile`、`conf/classicui.conf` 是本地文件；候选界面选 Catppuccin，但选项本身未声明。当前磁盘 profile 只列 keyboard-us；这不等于已经证明正在运行的内存状态也没有 Rime，需要交互验证。
- `build/` 是可重建缓存；`rime_ice.userdb`、installation/user 状态是私有训练数据，不公开提交。
- 候选处理：纳管方案、输入法列表与必要快捷键/候选设置；训练词库单独私有备份。

### D-04 Fastfetch 自定义外置

- [ ] 状态：已确认，待用户决定。
- `~/.config/fastfetch/config.jsonc` 与 `ascii.txt` 为普通文件，配置直接引用 `~/.config/fastfetch/ascii.txt`，标注 FastCat 来源。
- 程序受管，新机器会缺失当前展示内容。JSON schema 的网络地址不等于 Fastfetch 每次执行会下载它，不能误报为运行时下载依赖。
- 候选处理：将配置和 ASCII 图纳管；或接受默认展示。

### D-05 Fish 升级迁移文件

- [ ] 状态：已确认存在，是否保留待用户决定；不是已证实的手工定制。
- `~/.config/fish/conf.d/fish_frozen_theme.fish` 固定了语法高亮颜色；`fish_frozen_key_bindings.fish` 由 Fish 4.3 升级迁移生成。
- `config.fish` 本身受管；两个迁移文件不是 Nix 管理。新 home 的表现可能与沿用旧 home 不同。
- universal 变量中四项 WLR/WAYLAND 设置已在 `hosts/deck/configuration.nix` 声明，不重复算作未纳管依赖。
- 候选处理：确认当前高亮是否要保留后，再纳管必要变量或使用新版默认值；不擅自删除迁移文件。

### D-06 桌面默认应用关联

- [ ] 状态：已确认，待用户决定。
- `~/.config/mimeapps.list` 为普通文件，HTTP/HTML 部分指向 Chrome，但 XHTML 和若干关联仍指向 firefox-nightly。
- 不是 Yazi 的 opener 设置；新机器不会从当前 flake 恢复这份桌面级默认关联。
- 候选处理：选择明确默认浏览器、图片、视频、PDF 应用后，用 HM mimeApps 声明；不原样保留历史重复项。

### D-07 Dconf 光标偏好与受管值不同

- [ ] 状态：已确认差异，待决定是否处理。
- 实际 dconf `/org/gnome/desktop/interface/cursor-theme` 为 `Bibata-Original-Ice`，而受管 `~/.icons/default/index.theme` 指向 `Bibata-Modern-Ice`。
- GTK/Kvantum、图标与暗色设置的受管值已能找到，未设置额外 GNOME font-name。
- 候选处理：明确所需光标后统一声明；不把 Dconf 整个数据库提交。

### D-08 浏览器插件和学习工作流

- [ ] 状态：已确认扩展本地安装，配置/字典/脚本待脱敏深查。
- Chrome 检出 Yomitan、asbplayer、Migaku Early Access、Tampermonkey BETA、uBlock Origin Lite、DuckDuckGo、User-Agent Switcher、Google Docs Offline 等；未由当前 flake 完整声明。
- 程序安装不保证扩展设置、Yomitan 字典、用户脚本和本地音频/API 服务可恢复。账户令牌、站点资料和浏览器数据库不公开纳管。
- 候选处理：用户决定需保留哪些扩展/配置，再采用固定插件、策略安装、导出配置或私有备份；不复制整个 Chrome profile。

### D-09 `/kk/center` 网页内容外置

- [ ] 状态：实机确认，关联 F-10。
- 目录存在，含本地 `index.html`（6581 字节），未由当前 flake 提供。原生服务声明只指定 nginx root。
- 新部署没有这个文件就不会得到当前首页；局域网反向代理还依赖具体设备。
- 候选处理：用户批准后纳管静态网页，网络地址留在 Deck 主机层。

### D-10 OpenList / Sunshine / 网络的私有恢复

- [ ] **OpenList**：服务 active，工作目录 `/home/keke`，User 未指定（默认 root）；状态实际位于 root 所有的 `~/data/config.json`、`data.db`。未读取内容。账户、挂载和数据库需私有备份，静态配置可另拆。
- [ ] **Sunshine**：实际运行的是 `/etc/systemd/user/sunshine.service`，使用 store 中生成的 sunshine.conf；不能将 `~/.config/sunshine/sunshine.conf` 当成实际服务配置。用户目录另有 apps.json、配对状态、portal token 和备份；需区分使用中的静态 app 定义、旧配置与私有证书。
- [ ] **NetworkManager**：sudo 仅盘点文件，发现 2 个连接 profile；未读密码。此前非 root 目录扫描的 0 不代表没有 profile。新机器上网前提需私有恢复或重新连接。
- [ ] **其他秘密**：`.ssh`、`.gnupg`、`.password-store`、keyrings、Git 凭据、Pi auth/provider 文件存在；这里只记类别，不读取或复制秘密值。

### D-11 游戏、硬件与其他本地状态（待范围决定）

- [ ] **Steam 游戏**：本地有 Steam 运行时、Proton 和游戏的生成 desktop 项；程序启用不等于游戏、存档、Steam 设置和插件自动恢复。用户决定是否排除，不盲目固定下载缓存。
- [ ] **SteamOS/CEC/Gamescope**：本地 cecd 设置、steamos-manager 状态、gamescope edid.bin 存在；modes.cfg 为空。先查上游服务是否自动生成，不能仅因普通文件就认定需要纳管。
- [ ] **Weylus**：程序受管，本地 `weylus.toml` 存在，需在用户选择纳管前脱敏检查；访问口令不提交。
- [ ] **htop / Qt / 文件选择器**：存在本地设置，但未全部确认是用户定制；低优先级盘点，不直接把自动保存状态当缺陷。
- [ ] **`/opt/containerd`**：root 路径下有 bin/lib 目录，当前 PATH 无 docker/containerd，所扫描 systemd 目录无本地单元。是否残留、是否被其他脚本调用尚未确认；不删除。
- [ ] **旧备份/目录**：旧 Niri 配置、Downloads/deck.kdl、ranger、旧 Flatpak/Firefox 等目录存在。当前 Niri 加载的是 store 配置；残留文件本身不是复现阻断，不擅自清理。

### D-12 当前字体结果不能代表新方案

- [ ] 旧系统实际以 `/home/keke/.local/share/fonts/MonoLisaNasyNormal.ttf` 渲染西文；`sans-serif:charset=4e2d` 和 `:charset=9ad4` 都匹配用户目录 PingFang；等宽中文匹配 Nix 的 Noto CJK KR。
- `lang=zh-*` 单独查询仍可能返回不含目标汉字的西文字体；本轮改用 charset 验证，避免将语言偏好查询当作字符覆盖证明。
- 新 flake 的 MonoLisa/文楷方案未部署；未来要验证“去掉旧字体目录的影响后”仍然正确，而不只是看到相同 family 名。不得为验证擅自删除用户字体。

## 6. 每项关闭记录模板

```text
ID：
用户选择：纳管 / 固定资源 / 私有恢复 / 接受例外 / 删除依赖
改动文件与提交：
外部资源版本、来源、哈希或授权方式：
私有数据备份/恢复步骤（不含秘密值）：
macOS 验证：求值 / 构建 / 激活 / 实际行为
Linux 验证：求值 / 构建 / 激活 / 实际行为
干净环境验证：
剩余限制：
关闭依据：
```

## 7. 本轮操作记录

- 初始阶段：只读检查仓库引用、macOS 应用/cask 名单、部分配置/字体/插件和启动项目录；创建本 checklist。
- 用户批准后：修改 bar.wezterm 为固定源码本地加载、将 mpv 配置移入共享层、删除 Zellij；尚未将配置修改等同于激活验收。
- 已验证：bar 插件单独 `nix build` 成功；独立 WezTerm 配置从 Nix 输出加载插件成功；macOS / Deck 完整系统 derivation 求值成功；mpv 生成文本包含两项预期设置；配置树除本追踪文档外无 Zellij / zjstatus 引用；`git diff --check` 通过。
- 尚未验证：本轮修改未激活；Deck 尚未做本轮完整构建与边界检查。
- 未做：未安装应用、未删除用户数据；未部署尚未批准的审计建议。
- 未读取/未复制：认证文件的秘密内容、私钥、密码、订阅凭据、应用账户数据库内容。
- 子检查的结果尚未全部汇总；后续将补充证据位置及新发现，不把等待中的结果当已完成。
