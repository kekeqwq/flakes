# secret-lab：从官方 ISO 复现 LUKS2 + Btrfs zstd / YubiKey 回归

> **这是操作手册，不是创建、启动或擦盘授权。** 必须先取得用户对新实验盘的明确授权。
> 只能格式化新 QEMU 客体内完全空白的 `/dev/vda`；绝不转换、加密或格式化 Deck 现有磁盘。
> `lab` / `lab-x86` 仍是未加密 ext4；本手册的 flake 目标是 **`secret-lab`**。

## 0. 今日交接状态与配置边界

2026-11-16 已实际验证：

- LUKS2 + Btrfs `@root` / `@nix` / `@home`，均使用 **`compress=zstd:3`**。
- 无 Key 时错误密码拒绝、正确恢复密码进入桌面；旧尝试失败后重启仍可正常恢复，没有永久锁盘。
- 新 `tries=0` 系统中，日志确认 **六次错密后，第七次成功解锁**。
- 主 Key 预插启动后纯触摸解锁，无恢复密码、无 PIN。
- 主 Key 在设备等待开始后约 **4.3 秒**接入、约 **5.2 秒**被发现并请求触摸；用户确认纯触摸解锁。
- 超过 10 秒已转入密码回退后再插 Key，不会自动重启 FIDO2 认证：这是当前 systemd 262 的实现边界。

不要混淆以下状态：

- **Niri 黄色警告：代码已修、构建检查通过，尚未验证实际更新后的会话启动。**
  警告是 `Calling import-environment without a list of variable names is deprecated.`。
- **Sunshine：锁屏/解锁后冻结、重连阻塞问题尚未修复。** 重启服务只是恢复措施。
- 图形密码界面曾疑似退回文本；后来用户未复现并怀疑误切 TTY。没有确认到 Plymouth 崩溃，
  不把这一怀疑写成“已确认且已修复的 bug”。用户要求停止追加该项测试。
- 第二只 Key 的逐卷登记、未授权第三只 Key 的实物负例、独立增删/撤销等仍未完成。

详细证据：[`tests/secret-lab-2026-11-16.md`](../../tests/secret-lab-2026-11-16.md)；
串流故障：[`tests/desktop-stream-lock-2026-11-16.md`](../../tests/desktop-stream-lock-2026-11-16.md)。

**可以声明式纳管**：引导、crypttab 策略、initrd 驱动、挂载点、Btrfs 压缩、桌面和软件包。
**必须在实例上私有部署**：分区/格式化、实际 LUKS 头部、恢复密码、每卷硬件密钥登记、账户密码。
PAM 的公开凭据注册表不能替代磁盘登记；新卷即使使用同一只 Key，也必须重新登记。
不要把密码、头部备份、硬件解锁秘密、账户数据库放进 Git、Nix store、命令参数或日志。

本手册给出 **宿主预构建 → 签名 loopback cache → 安装目标盘** 路线 A，和私有 SSH 传送
NAR 的替代路线 B，避免在 ISO 内编译整套桌面。本轮实际首次安装采用路线 A；路线 B 依据
当前 `nixos-install` 的目标 store 行为编写，**没有另做一轮全新安装验收**，不能伪称已重跑。

## 1. 准备：宿主、版本、Key 和目录

以下“宿主”命令在 **Deck 的 Bash** 中执行。默认登录 shell 是 fish 时先运行 `bash`。
“客体”命令只在官方 ISO 的本地控制台执行。不要在宿主运行分区/登记脚本。

先提醒用户插入指定的主 Key；本轮主 Key 序列号为 **20452713**。只读核对身份，不自动授权
任何 Yubico 设备。可以先登记第一只，未来再逐只新增，不要求两只同时在场。
宿主必须正常解锁，Key/PAM worker 不得正在认证；登记就绪、LED 闪烁时明确提醒用户触摸。

前提：x86_64 Deck、可用 KVM、现有 Niri 图形会话，以及磁盘空间和网络下载权限。
不需要桥接、额外 LAN 地址、Sunshine 配对或客体串流。

```sh
# 【宿主 / Bash】已有仓库时不要覆盖或清理用户工作；先检查状态。
cd /home/keke/Repos/flakes
repo=$PWD
git status --short
git rev-parse HEAD

# 新机器没有仓库时，另行 clone https://github.com/kekeqwq/flakes。
# 记录本轮实际 commit 和 flake.lock；不要更新 inputs 来“顺便修”安装。
# ff573e3 包含已实测的 tries=0；95357b5 加入 Niri 启动警告修复。

umask 077
id=$(date +%Y%m%d-%H%M%S)
work="$HOME/VMs/secret-lab-$id"
mkdir -m 700 "$work"
test ! -e "$work/disk.qcow2"
printf '%s\n' "仓库：$repo" "本轮目录：$work"
```

不得复用旧实验的 qcow2、NVRAM 或固定 LUKS 头部来伪装“新卷登记”。保留旧实例和私有恢复材料。
本例中 `work`、`repo` 等是公开路径变量；**绝不把恢复密码或 PIN 存进环境变量**。

## 2. 下载并校验官方 ISO

固定 ISO，不使用运行时 `latest`：

- 文件：`nixos-minimal-26.11pre1119549.d5cc68339997-x86_64-linux.iso`
- 来源：`https://releases.nixos.org/nixos/unstable/nixos-26.11pre1119549.d5cc68339997/`
- SHA256：`927b3102d3d1e2e7339803e2055c7511eb693e9869f7cc5202829341dfc0119e`

```sh
# 【宿主】沿用上一步的 Bash 变量。
release=https://releases.nixos.org/nixos/unstable/nixos-26.11pre1119549.d5cc68339997
iso=nixos-minimal-26.11pre1119549.d5cc68339997-x86_64-linux.iso
curl --fail --location --retry 3 "$release/$iso" -o "$work/installer.iso.part"
printf '%s  %s\n' \
  927b3102d3d1e2e7339803e2055c7511eb693e9869f7cc5202829341dfc0119e \
  "$work/installer.iso.part" | sha256sum --check
mv "$work/installer.iso.part" "$work/installer.iso"
```

校验失败就停止，不跳过校验。启动助手还会再次检查这个哈希。

## 3. 宿主构建工具、系统及公开安装载荷

```sh
# 【宿主】从同一个锁定 flake 构建，不使用 build-vm 替代真实磁盘安装。
nix build .#nixosConfigurations.deck.pkgs.qemu --out-link "$work/qemu"
nix build .#nixosConfigurations.deck.pkgs.OVMF.fd --out-link "$work/ovmf"
nix build .#nixosConfigurations.secret-lab.config.system.build.toplevel \
  --out-link "$work/system"
nix build .#checks.x86_64-linux.secret-lab-boundaries --no-link

export QEMU_ROOT=$(readlink -f "$work/qemu")
export OVMF_ROOT=$(readlink -f "$work/ovmf")
system=$(readlink -f "$work/system")
printf '%s\n' "$system" > "$work/system-path.txt"
git archive --format=tar HEAD > "$work/flakes.tar"

# 仅路线 B 需要以下大 NAR；路线 A 可跳过。
# 只导出系统闭包，不打包任何 home、账户状态、密码或私有恢复目录。
mapfile -t closure < <(nix-store --query --requisites "$system")
nix-store --export "${closure[@]}" > "$work/system.nar"
chmod 600 "$work/system.nar"
```

NAR 可能较大，预留宿主和 64 GiB 客体盘空间。静态字体等也可能受授权限制：这不是对整个桌面
所有外部资源“已完全可复现”的保证，见 [`NixOS/desktop/README.md`](../../NixOS/desktop/README.md)。
构建/下载失败须如实处理，不当作安装成功。NAR 不包含运行中的应用数据库或私有 Key 材料。

## 4. 启动官方 ISO：先不传 Key

```sh
# 【宿主】同一个 installer SSH 端口 22323 只允许一个实验占用。
# 此命令会创建新 64 GiB 稀疏 qcow2 和本轮独立的可写 OVMF_VARS。
installer_unit="secret-lab-installer-$id"
systemd-run --user --collect --unit="$installer_unit" \
  --setenv=PATH="$PATH" \
  --setenv=QEMU_ROOT="$QEMU_ROOT" --setenv=OVMF_ROOT="$OVMF_ROOT" \
  /run/current-system/sw/bin/bash "$repo/tests/secret-lab-vm.sh" installer "$work"
```

助手使用 Q35/KVM、4 vCPU、6 GiB RAM、virtio 磁盘和 GTK/VirGL。直接看 Deck 上的 QEMU 窗口。
不要叠加 VNC：它和此 GTK GL 显示不兼容。只给安装阶段创建出站 NAT 和
**127.0.0.1:22323 → 客体 SSH 22**；不绑定 LAN，不增设桥接/端口转发规则。
客体 Sunshine 始终关闭。Moonlight 若卡住，用本机画面/原生窗口截图核对，不能据旧串流帧
判断客体或 Plymouth 已崩溃。

### 4.1 私有安装 SSH（仅复制公开安装载荷及私有备份）

可以全程在本地控制台操作。需要宿主拷贝文件时，显式建立这轮临时 SSH 授权：

```sh
# 【宿主】私钥文件留在 work，提示的私钥保护口令只本地输入。
ssh-keygen -t ed25519 -f "$work/install-key" -C secret-lab-installer
# 只查看/复制 install-key.pub，绝不能查看/复制同名私钥进聊天或 Git。
```

在客体控制台 `sudo -i` 后，建立 `/root/.ssh`（0700），用编辑器将这一个
`install-key.pub` 公钥行放进 `/root/.ssh/authorized_keys`（0600），启动 `sshd`。
本地查看客体 `/etc/ssh/ssh_host_ed25519_key.pub` 的指纹，和宿主首次连接提示核对。

```sh
# 【宿主】首次连接使用默认的指纹确认，不自动关闭主机密钥校验。
ssh -p 22323 -i "$work/install-key" -o IdentitiesOnly=yes \
  -o UserKnownHostsFile="$work/known_hosts" root@127.0.0.1 true
scp -P 22323 -i "$work/install-key" -o IdentitiesOnly=yes \
  -o UserKnownHostsFile="$work/known_hosts" \
  "$work/flakes.tar" root@127.0.0.1:/root/flakes.tar
ssh -n -p 22323 -i "$work/install-key" -o IdentitiesOnly=yes \
  -o UserKnownHostsFile="$work/known_hosts" root@127.0.0.1 \
  'mkdir -p /root/flakes; tar -xf /root/flakes.tar -C /root/flakes'
```

SSH 到另一终端后不要遗失 `work` 等变量。上传脚本时注意嵌套 ssh 会吃父脚本 stdin；
除明确传送数据的管道外使用 `ssh -n`。所有密码仍在客体的本地终端输入，不经 SSH 命令参数、
QMP 键盘注入、截图、日志或助手工具参数传递。

## 5. 在新客体分区、加密并**开启压缩**

下面工具环境来自仓库锁定的 nixpkgs，避免安装 ISO 缺少 Python/realpath/FIDO 工具。
已经 `sudo -i` 的 root 直接运行脚本；不要再经过一个清理 PATH 的 sudo，造成工具丢失。

```sh
# 【客体 / ISO 的本地控制台】
sudo -i
cd /root/flakes
nix shell \
  .#nixosConfigurations.secret-lab.pkgs.coreutils \
  .#nixosConfigurations.secret-lab.pkgs.util-linux \
  .#nixosConfigurations.secret-lab.pkgs.parted \
  .#nixosConfigurations.secret-lab.pkgs.dosfstools \
  .#nixosConfigurations.secret-lab.pkgs.btrfs-progs \
  .#nixosConfigurations.secret-lab.pkgs.cryptsetup \
  .#nixosConfigurations.secret-lab.pkgs.python3 \
  .#nixosConfigurations.secret-lab.pkgs.systemd -c bash

systemd-detect-virt --vm
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS
bash hosts/secret-lab/partition-and-mount.sh --erase-fresh-qemu-vda
```

脚本只接受 QEMU/KVM + QEMU DMI + UEFI、完全无签名/分区/挂载的 `/dev/vda`，且没有现有 mapper、
安装目标或重复标签。拒绝是保护，不要删检查或对宿主运行 `wipefs` 来“让它通过”。
恢复密码必须至少 12 字符，在本地隐藏提示里输入并确认；保留可用恢复路径再登记 Key。
`--key-fd N` 只给已经安全准备的私有继承 FD，正常复现不需要此选项。

脚本创建：

| 项目         | 实际设置                                                           |
| ------------ | ------------------------------------------------------------------ |
| GPT ESP      | `/dev/vda1`，1 MiB–1025 MiB，FAT32，`SECRETEFI`，挂载 `umask=0077` |
| 加密分区     | `/dev/vda2`，其余空间，PARTLABEL `secret-lab-cryptroot`            |
| 磁盘加密     | LUKS2、Argon2id，恢复密码 slot 0 保留，mapper `cryptroot`          |
| 内层文件系统 | Btrfs，`@root` / `@nix` / `@home`                                  |
| **压缩开关** | **三个子卷在安装写入前都以 `compress=zstd:3,noatime` 挂载**        |
| swap / 休眠  | 不创建；目标配置禁用休眠                                           |

验证，必须能看到压缩选项：

```sh
# 【客体】
findmnt -R /mnt -o TARGET,SOURCE,FSTYPE,OPTIONS
stat -c '%a %n' /mnt /mnt/nix /mnt/home
```

`/mnt`、`/mnt/nix`、`/mnt/home` 应为 **0755**。不要因私密操作的 `umask 077` 把这些根目录
留成 0700，否则安装器/普通用户无法遍历；头部备份仍保持 0700/0600。

**压缩不能遗漏的两处**：

1. 安装阶段：上面脚本已经带 `compress=zstd:3`，然后才向 `/mnt/nix` 等写系统文件。
2. 重启以后：`hosts/secret-lab/default.nix` 的 `/`、`/nix`、`/home` 也都声明同样选项。

只配置第 2 处并不会追溯重压之前的数据。`compress=` 对适合压缩的新写入生效，不保证每个文件
都变小；不要随意对已有快照数据运行重写/碎片整理。qcow2 的稀疏分配不是 Btrfs 压缩，
对 LUKS 外部密文再压缩也不能替代**加密层内**的 Btrfs zstd。

## 6. 导入预构建系统并安装引导

### 路线 A：本轮实际采用的签名 loopback cache

使用 `nix-serve-ng`，不要使用本轮已发现 Perl 依赖故障的旧 `nix-serve` 包。
`nix-serve-ng` 的可执行文件名仍是 `nix-serve`；地址必须显式绑定 loopback，默认绑定全部地址不合要求。

```sh
# 【宿主】密钥内容只在 0600 私有文件中，参数/环境里只有文件路径。
nix build .#nixosConfigurations.deck.pkgs.nix-serve-ng --out-link "$work/cache-server"
nix-store --generate-binary-cache-key secret-lab-local-1 "$work/cache.sec" "$work/cache.pub"
chmod 600 "$work/cache.sec"
cache_unit="secret-lab-cache-$id"
systemd-run --user --collect --unit="$cache_unit" \
  --setenv=PATH="$PATH" --setenv=NIX_SECRET_KEY_FILE="$work/cache.sec" \
  "$work/cache-server/bin/nix-serve" --host 127.0.0.1 --port 18081

# 公钥和 store 路径不是秘密；不要把 cache.sec 复制进客体。
scp -P 22323 -i "$work/install-key" -o IdentitiesOnly=yes \
  -o UserKnownHostsFile="$work/known_hosts" \
  "$work/cache.pub" "$work/system-path.txt" root@127.0.0.1:/root/
```

客体通过 QEMU user-mode NAT 的宿主入口 `10.0.2.2` 访问这个 loopback 服务，不新增 LAN 监听、
代理或转发规则。服务只输送公开 Nix store 闭包；cache 私钥和 LUKS 私有备份不在 store。

```sh
# 【客体 / 保持第 5 步的 root 工具环境】
IFS= read -r system < /root/system-path.txt
IFS= read -r cache_public < /root/cache.pub
nixos-install --system "$system" --root /mnt --no-root-passwd --no-channel-copy \
  --option extra-substituters http://10.0.2.2:18081 \
  --option extra-trusted-public-keys "$cache_public"
passwd --root /mnt keke
```

若签名/下载失败就停止检查，不加 `--no-check-sigs` 来掩盖问题。成功后跳到第 7 步。
下面路线 B 是替代方案，不需要先完成路线 A。

### 路线 B：私有 SSH 搬运 NAR（未另做全新安装验收）

大 NAR 放在已挂载的目标盘，不要撑满 6 GiB ISO 的内存临时 store。

```sh
# 【宿主】此时 /mnt 已经是新加密 Btrfs 根。
scp -P 22323 -i "$work/install-key" -o IdentitiesOnly=yes \
  -o UserKnownHostsFile="$work/known_hosts" \
  "$work/system.nar" root@127.0.0.1:/mnt/secret-lab-public-system.nar
# system-path.txt 只有公开 Nix store 路径，可以同样复制或手动粘贴。
scp -P 22323 -i "$work/install-key" -o IdentitiesOnly=yes \
  -o UserKnownHostsFile="$work/known_hosts" \
  "$work/system-path.txt" root@127.0.0.1:/root/system-path.txt
```

```sh
# 【客体 / 保持第 5 步的 root 工具环境】
# --store /mnt 直接导入目标 store，不把整个桌面先导入 ISO 内存盘。
nix-store --store /mnt --import < /mnt/secret-lab-public-system.nar
IFS= read -r system < /root/system-path.txt
nix-store --store /mnt --check-validity "$system"
nixos-install --system "$system" --root /mnt --no-root-passwd --no-channel-copy
passwd --root /mnt keke
rm -- /mnt/secret-lab-public-system.nar
```

`passwd` 设置的是**独立账户登录密码**，不是 LUKS 恢复密码。不把任一个密码写进配置。
如果选择客体自行构建，替代安装命令是
`nixos-install --flake /root/flakes#secret-lab --root /mnt --no-root-passwd --no-channel-copy`；
它会下载/编译目标，不能将其耗时或下载失败混淆为预构建路线成功。

## 7. 明确选择、直通并逐卷登记主 Key

必须在有可用恢复密码后做。不要把 sudo/锁屏的公开凭据 ID 复制进 LUKS，当作已登记。

### 7.1 在宿主授权这一个 USB 设备

先正常解锁宿主。用只读工具核对用户指定 Key 的序列号（例如
`ykman --device 20452713 otp info` 只查询状态，不生成 OTP），再用 `lsusb` / sysfs 查当前 bus/address。
拔插或归还 Key 会改变地址，每次重新确认。**厂商 1050 只是 sanity check，不是授权。**

关闭正在使用智能卡的应用。只有确认连接空闲并获授权后，才运行
`gpgconf --kill scdaemon` 释放用户的 CCID 连接；保留整个 gpg-agent 和现有凭据。
让 `pcscd.service` 自动退出；不要为直通去强杀其他人的工作或重置硬件。
只传 OTP/FIDO 接口仍可能因 CCID 被占而出现 `can't set config #1, error -32`。

初次 installer 未传 Key 时，使用下列公开 QMP 命令热接入。先定义一次通用函数：

```sh
# 【宿主】只用于公开 QMP 控制，不做键盘输入。
qmp() {
  python3 - "$work" "$@" <<'PY'
import json, socket, sys
from pathlib import Path
s = socket.socket(socket.AF_UNIX)
s.settimeout(10)
s.connect(str(Path(sys.argv[1]) / 'qmp.sock'))
f = s.makefile('rb')
json.loads(f.readline())
def command(name, args=None):
    request = {'execute': name}
    if args is not None:
        request['arguments'] = args
    s.sendall((json.dumps(request) + '\n').encode())
    while True:
        reply = json.loads(f.readline())
        if 'error' in reply:
            raise RuntimeError(reply['error'])
        if 'return' in reply:
            return reply['return']
command('qmp_capabilities')
print(json.dumps(command(sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv) > 3 else None)))
PY
}

# 将 1/2 换成本轮已人工批准且有读写权限的真实地址，不自动选第一个 Yubico。
qmp device_add '{"driver":"usb-host","id":"security-key","bus":"xhci.0","hostbus":1,"hostaddr":2}'
qmp human-monitor-command '{"command-line":"info usb"}'
```

直通会暂时移除宿主对整只 Key 的访问。**宿主正在锁屏/Key worker 正在认证时不得接管。**
宿主需要恢复时用账户密码正常解锁，或者先将 Key 归还；不杀 locker，不重启其 cgroup。

### 7.2 在客体只登记已批准的 hidraw

```sh
# 【客体 / 本地 root 控制台】
systemd-cryptenroll --fido2-device=list
# 明确核对 /dev/hidrawN 是这次直通的 Key，而非按数字猜。
bash hosts/secret-lab/enroll-key.sh --fido2-device /dev/hidrawN --label primary
```

助手独立验证 slot 0 的恢复密码，保存私有 before/after 头部，添加一个新 slot，不清除原 slot。
设置 `client-pin=no`、`user-presence=yes`、`user-verification=no`。
**在请求就绪、LED 闪烁时明确提醒用户触摸**，登记可能请求第二次触摸。
出现未知 PIN 要求就停止；不猜 PIN、不清 PIN、不禁用 OTP、不覆盖 PIV/OpenPGP、不做 FIDO reset。

全新卷通常是恢复密码 slot 0、新主 Key slot 1；以助手私有 `inventory.json` 实际结果为准。
登记成功不等于冷启动/锁屏测试通过。第二只 Key 日后使用 `--label secondary` 单独新增，
每次保留已有密码/Key，并再次验证。未完成的第二只 Key 测试不能写成已完成。

### 7.3 头部备份必须在虚拟盘外留一份

头部/库存保存在 `/mnt/var/backups/flakes-luks/`（已启动系统则是 `/var/backups/flakes-luks/`），
目录 0700、头部 0600，属于私有恢复材料，不进入 Git/Nix store/公开日志。

```sh
# 【宿主】SSH 加密管道；不显示头部内容、不放公开临时目录。
mkdir -m 700 "$work/private-recovery"
ssh -n -p 22323 -i "$work/install-key" -o IdentitiesOnly=yes \
  -o UserKnownHostsFile="$work/known_hosts" root@127.0.0.1 \
  'tar -C /mnt/var/backups -cf - flakes-luks' \
  | tar --no-same-owner -xf - -C "$work/private-recovery"
```

再由用户备份到适当的**私有、最好加密且离机**的介质。仅在卷内备份不能修复损坏的卷头；
仅 chmod 也不提供宿主整盘未加密时的防盗保护。不在聊天中展示头部或恢复密码。

## 8. 干净关闭安装器，首次启动必须有人看

```sh
# 【客体 / 本地 root 控制台】
umount -R /mnt
cryptsetup close cryptroot
poweroff
```

```sh
# 【宿主】必须确认安装器 VM 已退出、文件系统已卸载、mapper 已关闭，才能创建标记。
systemctl --user is-active "$installer_unit"   # 应不再 active
# 仅路线 A 启动过这个服务时，关闭本轮临时 cache：
# systemctl --user stop "$cache_unit"
# 确认以上状态，而不是盲目创建标记绕过检查：
touch "$work/installed-and-closed"
chmod 600 "$work/installed-and-closed"
```

**先让用户明确说正在看 Deck 的 QEMU 窗口，再启动已安装盘。**

```sh
# 【宿主】第一次不传 Key，优先验证恢复密码；没有 ISO、没有任何网卡。
desktop_unit="secret-lab-desktop-$id"
systemd-run --user --collect --unit="$desktop_unit" \
  --setenv=PATH="$PATH" --setenv=VIEWING_CONFIRMED=yes \
  --setenv=QEMU_ROOT="$QEMU_ROOT" --setenv=OVMF_ROOT="$OVMF_ROOT" \
  /run/current-system/sw/bin/bash "$repo/tests/secret-lab-vm.sh" desktop "$work"
```

`desktop` 模式是 **`-nic none`**，不是“保留 NAT 但不开端口”；安装 SSH 此时不可用。
不会导入 Sunshine 客户端证书、账户或生产应用数据库。QMP、serial、QGA socket/log 留在 0700 的
`work`；不使用 QMP 输入密码，不录制键盘字符。guest-agent 只有解锁根卷后才可用，未响应不能
单独证明“肯定还在密码框”，响应也不能证明远端看到的是最新帧。

## 9. 回归顺序与判断标准

### A. 无 Key、错误密码及压缩

1. 不接 Key，等待图形恢复密码框；10 秒是设备发现窗口，不是总密码等待时间。
2. 每次只输入错误密码和回车，等明确拒绝后再下一次；不按 Esc、不切 TTY、不点 QEMU 菜单。
3. 测至少六次，再输入正确恢复密码。`tries=0` 不因错密次数停止解锁服务。
4. 正确密码最终进入桌面；输入值不发聊天、不存日志。
5. 客体本地检查：

```sh
for path in / /nix /home; do
  findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS "$path"
done
sudo cryptsetup status cryptroot
sudo journalctl -b -u systemd-cryptsetup@cryptroot.service --no-pager
```

三个挂载必须都是 mapper 内 Btrfs 的对应子卷，并含 **`compress=zstd:3`**。
用实际 `Passphrase incorrect?` 记录核对失败次数，不能只凭敲键次数宣称有六次密码拒绝。
`a start job ... / no limit` 是等待时间，不是重试次数的单独证据。

看到文本提示不等于硬盘永久锁死：Esc 可切换 Plymouth 详细输出，VT 切换也会显示控制台。
真的怀疑异常时保留当前启动，正确密码恢复后只读检查 Plymouth/内核日志，不采集秘密内存转储。
Moonlight 卡住时先取宿主原生的测试窗口画面，不用过期视频帧认定 VM 死机。

### B. Key 预插启动

正常关闭 VM，宿主正常解锁，重新核对 Key、释放空闲 CCID、核对最新地址，再启动：

```sh
# 【宿主】与第一次 desktop 命令相同，额外显式传入以下两项。
# 不要照抄旧地址；用户确认观察后才设置 VIEWING_CONFIRMED。
VIEWING_CONFIRMED=yes USB_BUS=1 USB_ADDR=2 \
  QEMU_ROOT="$QEMU_ROOT" OVMF_ROOT="$OVMF_ROOT" \
  bash "$repo/tests/secret-lab-vm.sh" desktop "$work"
```

不输入恢复密码/PIN。**灯闪时触摸**，验证纯触摸进入桌面，并通过日志核对 FIDO2 请求及成功解锁。
没有闪灯不要反复摸：OTP 接口可能生成键盘字符串。

### C. 在设备等待窗口内后插

此项要和“开机前已经插好”分开。现有记录的做法是：Key 初始不在客体；从一个已正常解锁的
客体发起 OS reboot，同时在 QMP 监听 `RESET`；事件后约 8 秒显式 `device_add` 那一个 Key。
最终必须结合客体日志判断是否确实在**等待开始后 10 秒内**，不能只用“开机后 8 秒”认定。

下列公开控制脚本可保存为 `$work/window-test.py`；不会输入密码，但**会正常重启 VM并接管 Key**。
只在用户再次授权、观察就绪、客体已正常进入系统且主 Key 已核对时运行。
`USB_BUS`/`USB_ADDR` 必须是本轮明确批准的地址；不根据厂商自动抓设备。

```python
import json, os, socket, subprocess, time
from pathlib import Path

w = Path(os.environ['WORK'])
assert os.environ.get('VIEWING_CONFIRMED') == 'yes'
bus, addr = int(os.environ['USB_BUS']), int(os.environ['USB_ADDR'])

def ready():
    assert subprocess.run(['pgrep', '-x', 'swaylock'], stdout=subprocess.DEVNULL).returncode != 0
    assert subprocess.run(['pgrep', '-x', 'scdaemon'], stdout=subprocess.DEVNULL).returncode != 0
    assert subprocess.run(['systemctl', 'is-active', '--quiet', 'pcscd.service']).returncode != 0

ready()
q = socket.socket(socket.AF_UNIX); q.settimeout(45); q.connect(str(w / 'qmp.sock'))
f = q.makefile('rb'); json.loads(f.readline())
def command(name, args=None):
    r = {'execute': name}
    if args is not None: r['arguments'] = args
    q.sendall((json.dumps(r) + '\n').encode())
    while True:
        r = json.loads(f.readline())
        if 'error' in r: raise RuntimeError(r['error'])
        if 'return' in r: return r['return']
command('qmp_capabilities')
assert 'security-key' not in command('human-monitor-command', {'command-line': 'info usb'})

g = socket.socket(socket.AF_UNIX); g.settimeout(8); g.connect(str(w / 'qga.sock'))
gf = g.makefile('rb'); nonce = int(time.time())
g.sendall((json.dumps({'execute':'guest-sync','arguments':{'id':nonce}})+'\n').encode())
while True:
    r = json.loads(gf.readline())
    if 'error' in r: raise RuntimeError(r['error'])
    if r.get('return') == nonce: break
# guest-shutdown 成功时没有回复，不等待回执，也不因超时重复发送。
g.sendall(b'{"execute":"guest-shutdown","arguments":{"mode":"reboot"}}\n'); g.close()
while True:
    event = json.loads(f.readline())
    if event.get('event') == 'RESET': break
reset_wall, reset_mono = time.time(), time.monotonic()
time.sleep(max(0, reset_mono + 8 - time.monotonic()))
ready()
attach_wall = time.time()
command('device_add', {'driver':'usb-host','id':'security-key','bus':'xhci.0',
                       'hostbus':bus,'hostaddr':addr})
(w / 'window-test-times.json').write_text(json.dumps({
    'reset_host_time':reset_wall, 'attach_host_time':attach_wall,
    'delay_seconds':time.monotonic()-reset_mono}, indent=2)+'\n')
print('Key 已接入；只在 LED 闪烁时触摸，不输入任何密码/PIN。')
```

```sh
# 【宿主】明确授权、身份核对及观察确认后才运行；以下地址仅示例。
WORK="$work" VIEWING_CONFIRMED=yes USB_BUS=1 USB_ADDR=2 python3 "$work/window-test.py"
```

解锁后对照 `window-test-times.json` 和
`journalctl -b -u systemd-cryptsetup@cryptroot.service -o short-iso-precise`：
先出现 `Security token not present`，后插入，再 `Asking FIDO2 token` / `confirm presence`，最后成功。
请求触摸前不能出现设备发现超时；用户确认纯触摸、无密码/PIN后才通过。
本轮实际是等待后 4.3 秒接入，5.2 秒请求触摸。

### D. 超时后插入：预期边界，不当作需要定制修复的缺陷

设备发现等待 **10 秒**后进入恢复密码回退，本次 systemd 262 激活流程就不再自动扫描 FIDO2，
包括密码重试也不会恢复标志。本轮在约 124.6 秒后插入无闪灯，符合实现。
不是“后插完全不支持”，也不是“看到密码框后随时插都能转回触摸”。
不要为本实验把设备等待改成无限，从而阻塞密码回退；也不加入并行解锁/自动重试的私有补丁。
10 秒只约束**发现设备**，不等于发现后用户必须在同一个截止点前完成触摸。

### E. 测试结束、归还 Key 和安全关闭

```sh
# 【宿主】仅移除这一只直通设备，不是擦除/撤销其登记。
qmp device_del '{"id":"security-key"}'
qmp human-monitor-command '{"command-line":"info usb"}'
```

确认归还宿主后再进行宿主 Key 认证。客体本地正常关机；也可用 QGA
`guest-shutdown` 的 `mode=powerdown`，它成功时同样没有 JSON 回复。
等待 QEMU/service 真正退出，再关闭宿主。不能将 live 文件系统上的 `kill QEMU` 当成正常关机。
不要为恢复锁屏去 kill/signal locker 或停止包含活动 locker 的 cgroup。

关闭前提交/同步公开仓库；私有 qcow2、NVRAM、SSH 私钥、卷头和库存不进仓库，原地保留。

## 10. 后续新增、撤销与安全边界

- 第二只 Key 必须对本卷单独登记，并保留 slot 0 与已有 Key；不要复制第一只的固定卷头来部署新盘。
- 撤销先实测恢复密码、私有备份当前头部、从私有库存确认准确 slot，然后才对指定卷执行
  `systemd-cryptenroll --wipe-slot=NUMBER DEVICE`。不使用 `--wipe-slot=fido2` 删除所有 Key。
- PAM 公开注册表和各卷登记独立。撤销必须分别部署/核验；旧系统 generation 也可能恢复旧 PAM 授权。
- 旧头部、快照或磁盘副本仍可能恢复旧盘授权；同时管理私有备份，不能声称改当前 slot 就让旧副本失效。
- 未登记的第三只 Key 不应解锁，但尚未做的实物负例不得宣称通过；不能仅凭 USB 厂商/型号/序列号放行。
- 没有配置 Secure Boot、签名或 measured boot。本方案保护静态数据，不防攻击者替换未加密 ESP/initrd。
- 解锁后 autologin 进入桌面；需要后续锁屏保护。`tries=0` 只管 LUKS 恢复密码，不取消 YubiKey PIN 防猜机制。
- 当前 Sunshine 锁屏后失效是独立未解决项；Niri 弃用警告仅源码/检查已修，留待下次实际启动验证。
