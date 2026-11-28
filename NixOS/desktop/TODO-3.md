# TODO-#3：Linux 桌面亮暗热切换

状态：`todo-3` 已实现首版，Surface 已通过可回退的会话测试，尚未永久启用。功能属于共享 `NixOS/desktop/`，不按主机名分支，不修改硬件 flake、内核或 macOS 的外观策略。启用和回退不需要重启电脑或注销桌面。

## 控制中心行为

| 选择 | 持久状态 | 立即生效 |
| --- | --- | --- |
| 亮色 | 手动亮色 | Catppuccin Latte |
| 暗色 | 手动暗色 | Catppuccin Mocha |
| 自动 | 定时 | 当地时间 `07:00 ≤ 时间 < 18:00` 用 Latte，其余用 Mocha |

- 在自动模式点亮色或暗色，立即进入对应的手动模式；手动模式不受定时边界影响。
- 切回自动时立即读取当地时间，不能等到下一次边界。登录、唤醒、时区或系统时钟变化后重新计算。用用户级定时/事件，不引入常驻轮询。
- 控制中心同时显示持久模式和当前实际配色，例如「自动 · 亮色」。状态切换串行化；快速连点不能留下混合主题。组件刷新失败要可见、可重试或回退。

## 热切换范围

- [ ] Niri：用经校验的运行时外观片段同步边框、焦点、概览等，不重启合成器、不改变布局或窗口。Home Manager 受管文件保持只读。
- [ ] Waybar、Mako 通知、Rofi、已打开的控制中心、输入法界面：两套配色统一管理；按组件提供热重载或原地重绘。尚未打开的菜单或弹窗在下次出现时使用当前配色。
- [ ] GTK3/GTK4、Qt/Kvantum 及 portal：发布一致的系统外观偏好和可用配色。记录只能在启动时读样式的第三方应用；不为换色强行结束应用。
- [ ] Ghostty：保留原生 Latte/Mocha 双主题，验证同一个已打开的终端窗口响应 Linux 外观信号，不断开会话。Emacs：让正在运行的进程或 daemon 的既有与新 frame 跟随，不重启，不丢缓冲区。
- [ ] 锁屏：新锁会话取当前配色；已经锁定时跨过时间边界，若支持实时刷新，必须在原锁会话内重绘，绝不终止锁屏或绕过密码/Key 认证。Plymouth 开关机动画保持原样、不读时间或会话外观。壁纸选择独立。

## 实现与试用

- `~/.local/bin/keke-appearance auto|light|dark` 切换；`status` 查询，`reconcile` 重试刷新。持久模式与当前资源位于 `$XDG_STATE_HOME/keke-appearance/`（默认 `~/.local/state`）。状态串行更新，核心切换失败恢复旧主题；非核心组件刷新失败后，控制中心显示 `Reload incomplete`，可以重选当前模式。
- `desktop-appearance.service` 在 Niri 图形会话启动时补算。用户级 timer 监听当地 07:00 / 18:00、系统时间和时区变化；挂起中跨过时点则唤醒后补触发。这里没有额外的轮询进程。
- GTK4/libadwaita 和 Qt/Kvantum 的现有窗口不保证重新载入样式；新进程会读取当前配色，不为换色重启应用。Fcitx5 Classic UI 与桌面使用同一个有效配色链接，直接指定 Latte Sky / Mocha Mauve。Surface 实测 portal 报暗色时 Classic UI 仍留在浅色，因此不依赖其独立暗色判定。切换时通知 Classic UI 重读并检查其运行中配置，不重启 Fcitx5 或重新部署 Rime，保留词库和输入状态。已锁定的屏幕不会实时换色；下次正常锁屏取当时的配色。亮暗均使用淡紫色调的半透明圆底来保护时钟对比度，认证和壁纸仍分离。
- Waybar 的托盘与其他模块共用胶囊底色，不覆盖 Telegram 和输入法的动态图标。GTK、Rofi 和托盘按配色使用 Latte 的 `Papirus-Light` 或 Mocha 的 `Papirus-Dark`；品牌应用图标允许保留原色。Niri 焦点环、Rofi 选中项和 Waybar 当前工作区使用 Latte 天蓝 / Mocha 淡紫；Waybar 的浅色时钟和控制中心图标用对比度更高的深蓝。控制中心独立显示持久模式（高亮）与有效主题（文字），Emacs 刷新会核对现有 GUI frame 的实际背景色，不再仅以调用成功为准。用户 Emacs 配置中新建 frame 的主题钩子同样需尊重 `flakes-appearance-apply`，不能在 Linux 上无条件重设 Mocha；独立 dotfiles 试验提交 `3c70d9d` 实现了这个衔接。

### Surface 已验证（未切换系统代）

- 原生 AArch64 构建：两套 Niri 配置都通过 `niri validate`，外观资源、面板及 Home Manager 生成物构建成功；`systemd-analyze --user verify` 通过生成的 timer/service。桌面边界检查已通过 Nix 求值（不是实机验收）。
- 自动测试覆盖四个时间边界、手动保持、切回自动、并发点击串行化，以及刷新失败后回退和重试。运行 `python3 tests/desktop-appearance.py NixOS/desktop/appearance.py`。
- 原会话中可回退测试了 Light → Dark → Auto：Niri 接受配置，Waybar/Mako 重载，Rofi 两套主题可解析，portal 依次返回 `2 → 1 → 2`。原配置、Niri PID、锁屏 PID 和 boot ID 核对不变。用临时 GTK 组件验证了两套面板 CSS 可解析，按钮更新同一个控件；独立 Emacs daemon 的 PID 和缓冲区内容在两次换色间保持不变。没有重启、注销、终止现有锁屏或替换用户的 Emacs 进程。
- 仍待正常启用后目视验收：已打开的控制中心和 Ghostty、用户 Emacs 的 GUI frame、GTK/Qt 新旧窗口、Fcitx 候选框、通知、锁屏对比度以及密码/Key。实际登录和跨边界唤醒仍未试，不为测试主动挂起或改机器时钟。

## 验收

- [ ] 用可注入的时钟测试 `06:59 / 07:00 / 17:59 / 18:00`，不改变机器时间。覆盖手动越界、立即切回自动、登录/唤醒补算、时区/时钟变更和快速切换。
- [ ] 在现有桌面会话实际双向切换，确认 Niri 窗口、已开的控制中心、Ghostty 会话和 Emacs 缓冲区保留；检查通知、Waybar、Rofi、输入法及锁屏的文字对比度和警告状态。分别记录 GTK/Qt 已开窗口与新开窗口的行为。
- [ ] 检查外观状态、用户配置和刷新失败的回退。确认锁屏认证、壁纸、显示布局、音频、Plymouth、无头系统及 macOS 的原行为不变。分开记录构建、会话热切换和手动验收，不以求值代替实机结果。
