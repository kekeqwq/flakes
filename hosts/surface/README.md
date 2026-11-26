# Surface 正式安装草案（待确认，不能 switch 到现有测试盘）

- 实例 `flakes#surface`、主机名 `surface`、原生 AArch64。硬件来自锁定的 `surface.nix`，保留 Denali HHKB、触屏、OLED 和已验收的 0 dB FullIO。
- 从公共桌面和 server 配置继承用户 `keke`、SSH、sudo 和 PAM；不保留测试机的无凭据登录、专用 SSH 授权文件与 `NOPASSWD`。新装的 `keke` 登录密码或授权公钥须按公共约定私下配置，不能把 Live 的 root 免密带进目标系统。
- Niri 只配置内置 `eDP-1`（2880×1920、120 Hz、缩放 2）；Sunshine 串流同一块屏幕，不创建虚拟输出、不设 nginx 代理或路由器转发，UPnP 关闭。首装后仍须实测 Sunshine 串流。
- 正式首装用 NixOS **27.05**。安装锁定 `nixos-unstable-small` 的 `aa156634ecca12217a808ff1d8fc2793115923bb`，求值得到 `config.system.nixos.release = "27.05"`；新实例采用 `system.stateVersion = "27.05"`，安装后不随升级改变。

## 磁盘布局

使用 `fdisk` 在明确确认的内置 NVMe 上建立 GPT（Live USB 不是目标）。仅下表第一项是 UEFI 规定的明文启动区，其他所有系统和用户数据放进一个 LUKS2 容器。**没有 LVM，首装不启用 swap 或休眠，不预留独立 swap 分区。**

| GPT 分区名 | 用途 | 挂载 |
| --- | --- | --- |
| `surface-efi` | FAT32 ESP，889 MiB（约 0.87 GiB），`umask=0077` | `/boot` |
| `surface-cryptroot` | 953 GiB，LUKS2 → `/dev/mapper/cryptroot` → Btrfs | `@root` → `/`，`@nix` → `/nix`，`@home` → `/home` |

上述大小适用于这块 953.87 GiB NVMe；另留 GPT 和对齐所需的少量扇区。systemd-boot 最多保留八个启动代，实际容量取决于完整 UKI 的大小。

根卷使用 LUKS2 AES-XTS（`cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512`）。Denali initrd 只纳入此根卷所需的加密模块，不请求通用列表中的旧密码算法和 AF_ALG；保留 `dm_crypt`，用户空间的 cryptsetup 使用 OpenSSL/libargon2。改用其他根卷密码算法时须同步检查 initrd 配置。

文件系统启用 `compress=zstd:3,noatime`。以后需要 swap 时，可在同一个加密 Btrfs 里新建 `@swap` 子卷，用 `btrfs filesystem mkswapfile` 按需创建交换文件，并启用 Denali 内核的 `CONFIG_SWAP`，不必重分区。若再做休眠，initrd 要先解锁 `cryptroot` 再定位休眠镜像；须另行启用内核休眠支持并验证真机恢复。

先创建能独立使用的恢复密码，再为这个 LUKS2 容器逐只登记指定 YubiKey（一次触摸，无 PIN）；sudo/锁屏的公有 PAM 授权不能代替磁盘登记。登记时插入指定 Key，指示灯闪烁后触摸。密码和 LUKS 头备份只私下保存。须分别验证无 Key 密码回退与登记 Key 冷启动解锁。

## 安装顺序（确认后）

1. 用已通过实机检查的私有 Live USB 启动、连接可信网络。记录目标盘身份和备份，确认后才分区并建卷。ESP 与内部数据的备份须存放在目标盘之外。
2. 挂载全部目标子卷与 ESP。将确认过的 `flakes` 和 `surface.nix` 对应提交与输入锁同步并提交后，从 Git 获取 `flakes` 到目标 `/mnt/etc/nixos`，使用其已提交的锁定输入。
3. 从 Live 的 `/iso/surface-install/firmware/` 校验并部署到目标 `/mnt/var/lib/surface-firmware`，再执行 `nixos-install --root /mnt --flake /mnt/etc/nixos#surface`，使安装流程生成含私有固件的 UKI。固件、私有 UKI、恢复密码均不进 Git 或 Nix store。
4. 关机后拔开安装 U 盘，第一次由内置盘启动。检查系统与三个子卷、Key 和密码回退、公共 SSH/sudo、触屏和 HHKB、桌面和 Sunshine、0 dB 扬声器与 MicArray。Live 通过不是空白盘首启通过。

正式启动暂用该 Surface 上一次内置盘日用版本（`bd56d07`）的 FullIO 内核与 OLED DTB；不继承旧系统的分区、用户或认证配置。27.05 仍使用现有 LUKS2/Btrfs。`earlycon=efifb` 让内核尽早向 EFI framebuffer 输出；黑屏是否消失需要实机确认。
