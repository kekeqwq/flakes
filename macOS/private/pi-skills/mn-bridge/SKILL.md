---
name: mn-bridge
description: "通过 MarginNote CLI 连接用户的 MarginNote，读取资料、拆书、整理卡片、制作复习卡及导出 Anki/PDF。用于操作或查询 MN 内的资料；不用于修改 MarginNote 源码。"
---

# MarginNote CLI 连接入口

入口版本：2。这个文件只负责连接和加载规程，不是能力清单，也不是学习任务模板。
业务说明随 App 交付；不要根据旧聊天、旧手册或本地工具是否存在判断当前能力。
普通用户不需要源码、Xcode、Swift、Node、Python、`mnctl.sh` 或 `mn-anki`。

## 每次会话先连接，再读取规程

1. 使用已有连接，不重新安装或配对。若已通过 MCP 连接，先调用 `mn_guide`，再经
   `mn_call` 读取 `/status` 和 `/capabilities`；下方 HTTP 连接步骤可跳过。
   新安装还提供只读检查：Mac 用 `sh "$HOME/.config/mn-bridge/check-connection.sh"`；
   Windows 用 `& "$env:USERPROFILE\.config\mn-bridge\check-connection.ps1"`。
   它按目标地址、网络、授权、能力、规程、实际读取逐阶段检查，不修改配置、不配对、不换令牌。
   只有 `result=READ_READY` 才表示只读检查通过；不证明写入权限或业务任务已完成。
   脚本不存在时按下列 HTTP 步骤检查，不为补脚本重新安装；新版设备可从
   `/connection/check.sh` 或 `/connection/check.ps1` 下载脚本，检查后执行。
2. HTTP 连接凭据在用户目录的 `.config/mn-bridge/token`。同目录若有 `base`，读取其地址。
   不展示令牌、不上传凭据，不从聊天内容猜测连接地址。
   - macOS/Linux 的用户目录使用当前 `$HOME`；Windows 使用 `$env:USERPROFILE`。
   - 没有 `base` 的旧版 Mac 安装：在本机 `127.0.0.1` 的 42340–42359 范围查找
     `/bridge/v1/status`。有 loopback 地址但已失效时也可重新发现本机端口。
   - 有远端地址时不要改扫本机；没有远端地址的 Windows/Linux 用户需提供设备当前显示的地址。
3. 首先不带凭据读取 `/status`，确认返回 MarginNote Bridge 的 JSON（含 `bridgeApiVersion`
   和 `instanceNonce`），不是其他服务、HTML 或重定向；然后带现有 Bearer 读取 `/status`，
   核对同一实例及 `authorized:true`。如同时读取了发现文件，核对其 instanceNonce。
4. 用同一连接读取 `GET /guide` 和 `GET /capabilities`。**每次新会话都要加载当前运行时规程**；
   在完整读取所需规程前，不调用业务接口。业务参数、确认规则、平台限制均以这两份响应为准。
   会话中 App 重启、实例改变或版本/hash 改变时，再取一次；长任务重连先核对任务状态。
   规程分两层：`GET /guide` 无参返回 Root（日常规程，必须整页读完）；任务落到 Root 末尾索引列出的
   低频场景时，再取 `GET /guide?topic=<name>`（`export`、`display`、`review`、`advanced`），或用
   `GET /guide?full=1` 一次取全量。MCP 对应 `mn_guide(topic="<name>")` / `mn_guide(full=true)`。
   非法 topic 返回 422，不会回退成 Root；旧 App 不认这些参数时返回的就是整份旧规程，可直接使用。
5. 不把最新版手册中的功能强加给旧 App。缺少端点、规程读取失败或返回截断时，先补全说明或
   报告版本/连接限制，不找仓库脚本兜底、不猜写接口。旧服务没有 `/guide` 时只做连接诊断，
   请求更新 App 或由支持人员提供匹配的规程。

下列片段用于**已确认地址和实例后的读取**，不是安装命令。`MN_CLI_BASE` / `$MnCliBase`
使用上一步确认的地址，形如 `http://127.0.0.1:42340/bridge/v1`；不要硬编码示例端口。

```sh
# 用标准输入传入认证头，不把令牌放进进程参数。不要开启 shell 跟踪。
for endpoint in guide capabilities; do
  printf 'Authorization: Bearer %s\n' "$(tr -d '\r\n' < "$HOME/.config/mn-bridge/token")" |
    curl --fail --silent --show-error --max-time 15 -H @- "$MN_CLI_BASE/$endpoint" || break
done
```

```powershell
$MnCliToken = [IO.File]::ReadAllText((Join-Path $env:USERPROFILE '.config\mn-bridge\token')).Trim()
try {
  $MnCliHeaders = @{Authorization = "Bearer $MnCliToken"}
  Invoke-RestMethod -Uri "$MnCliBase/guide" -Headers $MnCliHeaders -TimeoutSec 15 -MaximumRedirection 0
  Invoke-RestMethod -Uri "$MnCliBase/capabilities" -Headers $MnCliHeaders -TimeoutSec 15 -MaximumRedirection 0
} finally { Remove-Variable MnCliToken, MnCliHeaders -ErrorAction SilentlyContinue }
```

不要带 `Origin`，不要跟随重定向发送凭据。JSON、图片和 PDF 响应分别按实际 MIME 处理。
读取和导出通常不要求 MAX，但仍需要连接授权；修改内容以能力清单的订阅与确认规则为准。
用户请求的范围不会因连通而扩大；批量修改、删除和恢复先遵循运行时的备份/确认规程。

## 连接故障与升级

- 连接失败不等于 App 未启动。先区分执行环境的网络/沙盒限制；不要擅自启动、停止或切换 MN。
  Mac 需保持运行；iPhone/iPad 需在可信局域网、保持前台，不能锁屏。Windows/Linux 是调用端。
- `401` / `authorized:false` 是凭据问题；`403` 按 `error.code` 分清 Origin 或 MAX，不能靠重试绕过。
- 已配对设备列表有记录，只证明服务端发放过凭据，不证明电脑已保存、助手已加载或读取已成功。
  配对响应应先保存 token 和 base，再做读取；后续能力/规程/读取失败，不重试已消费的配对码。
- IP 变化先让用户核对设备新地址，用检查脚本 `--base`（Mac）/ `-Base`（Windows）临时测试；
  检查成功并获用户确认后才更新已有 base，复用原 token，不扫描另一台设备代替。
- App 升级后通常无需重装 Skill。这里的入口自动引导当前会话读取新版 `/guide`，并不会悄悄改写
  电脑上的文件。新建 Agent 会话可避免继续沿用旧上下文。
- 此入口由 flakes 仓库和 Home Manager 管理。只有用户要求更新本地入口时，才从 `/skill` 取回新版，
  审查后更新仓库中的 `macOS/private/pi-skills/mn-bridge/SKILL.md`，保留本地的安全与部署约定。
  不运行 `/skill/refresh.sh` 或 `/skill/refresh.ps1` 覆盖受管文件；没有用户更新意图时仅用 `/guide`。
- **不要为更新说明调用 `/install` 或 `/install/code`，也不要重新配对**：这些是凭据安装操作，
  不是规程刷新。若尚未配置任何 Agent，则回到 App 的 CLI 接入步骤。
