# Surface 正式安装（空白盘 Gen 1 已复现）

- 实例 `flakes#surface`、主机名 `surface`、原生 AArch64。硬件来自锁定的 `surface.nix`，保留 Denali HHKB、触屏、OLED 和已验收的 0 dB FullIO。
- 从公共桌面和 server 配置继承用户 `keke`、SSH、sudo 和 PAM；不保留测试机的无凭据登录、专用 SSH 授权文件与 `NOPASSWD`。新装的 `keke` 登录密码或授权公钥须按公共约定私下配置，不能把 Live 的 root 免密带进目标系统。
- Niri 保留内置 `eDP-1`（2880×1920、120 Hz、缩放 2）的原配置。Sunshine 指定实际连接的外接 `DP-1`（当前 1920×1080、60 Hz），不创建虚拟输出、不设 nginx 代理或路由器转发，UPnP 关闭。拔掉外接屏后如需串流内屏，将目标改回 `eDP-1`。
- 正式首装用 NixOS **27.05**。下列空白盘验收实际锁定 `nixos-unstable-small` 的 `5e50e88b70dff025f88e08f2b56de55137a13fe3`，系统版本为 `27.05.20261127.5e50e88`。该实例采用 `system.stateVersion = "27.05"`，安装后不随升级改变。

## 磁盘布局

使用 `fdisk` 在明确确认的内置 NVMe 上建立 GPT（Live USB 不是目标）。仅下表第一项是 UEFI 规定的明文启动区，其他所有系统和用户数据放进一个 LUKS2 容器。**没有 LVM，首装不启用 swap 或休眠，不预留独立 swap 分区。**

| GPT 分区名          | 用途                                             | 挂载                                              |
| ------------------- | ------------------------------------------------ | ------------------------------------------------- |
| `surface-efi`       | FAT32 ESP，889 MiB（约 0.87 GiB），`umask=0077`  | `/boot`                                           |
| `surface-cryptroot` | 953 GiB，LUKS2 → `/dev/mapper/cryptroot` → Btrfs | `@root` → `/`，`@nix` → `/nix`，`@home` → `/home` |

上述大小适用于这块 953.87 GiB NVMe；另留 GPT 和对齐所需的少量扇区。systemd-boot 最多保留八个启动代，实际容量取决于完整 UKI 的大小。

根卷使用 LUKS2 AES-XTS（`cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512`）。Denali initrd 只纳入此根卷所需的加密模块，不请求通用列表中的旧密码算法和 AF_ALG；保留 `dm_crypt`，用户空间的 cryptsetup 使用 OpenSSL/libargon2。改用其他根卷密码算法时须同步检查 initrd 配置。不要强制关闭 `boot.initrd.services.lvm.enable`：NixOS 的 LUKS 默认借它安装 `10-dm.rules` 等 device-mapper 规则。这不会增加 LVM 分区或逻辑卷；缺少规则时，FIDO2 解密成功后仍会无限等待 `/dev/mapper/cryptroot`。

文件系统启用 `compress=zstd:5,noatime`。以后需要 swap 时，可在同一个加密 Btrfs 里新建 `@swap` 子卷，用 `btrfs filesystem mkswapfile` 按需创建交换文件，并启用 Denali 内核的 `CONFIG_SWAP`，不必重分区。若再做休眠，initrd 要先解锁 `cryptroot` 再定位休眠镜像；须另行启用内核休眠支持并验证真机恢复。

先创建能独立使用的恢复密码，再为这个 LUKS2 容器逐只登记指定 YubiKey（一次触摸，无 PIN）；sudo/锁屏的公有 PAM 授权不能代替磁盘登记。登记时插入指定 Key，指示灯闪烁后触摸。密码和 LUKS 头备份只私下保存。须分别验证无 Key 密码回退与登记 Key 冷启动解锁。

## 安装顺序（确认后）

1. 用已通过实机检查的私有 Live USB 启动、连接可信网络。记录目标盘身份和备份，确认后才分区并建卷。ESP 与内部数据的备份须存放在目标盘之外。
2. 挂载全部目标子卷与 ESP。将确认过的 `flakes` 和 `surface.nix` 对应提交与输入锁同步并提交后，从 Git 获取 `flakes` 到目标 `/mnt/etc/nixos`，使用其已提交的锁定输入。
3. 从 Live 的 `/iso/surface-install/firmware/` 校验并部署到目标 `/mnt/var/lib/surface-firmware`，再执行 `nixos-install --root /mnt --flake /mnt/etc/nixos#surface`，使安装流程生成含私有固件的 UKI。固件、私有 UKI、恢复密码均不进 Git 或 Nix store。
4. 关机后拔开安装 U 盘，第一次由内置盘启动。检查系统与三个子卷、Key 和密码回退、公共 SSH/sudo、触屏和 HHKB、桌面和 Sunshine、0 dB 扬声器与 MicArray。Live 通过不是空白盘首启通过。

正式启动直接使用硬件仓库 `denaliDailyBoot` 的 FullIO 内核与 OLED DTB；其独立工具链锁用于复现已验证的启动产物，不再引用历史主机 flake。Denali 的 `boot.earlyDisplay` 在 initrd 启用 OLED 所需的显示时钟和桥接驱动，且让 QRTR 先于 PMIC GLINK 加载。走与 `secret-lab` 相同的 Plymouth/FIDO2 路径，不需要 `earlycon`、`keep_bootcon` 或向 ESP 写诊断日志。

在逐代修正后的内置盘 Gen 13 上，已实测 YubiKey 触摸后进入桌面，并确认 `cryptroot`、三子卷及 OLED 120 Hz。Gen 12 先独立证实了未解锁时 `msmdrmfb` 接管控制台。后续日用配置包括启动亮度 100%（桌面仍恢复上次亮度）、共享 Plymouth 10 秒等 Key 倒计时，以及三个独立的壁纸模式。Surface 的 EFI stub 会从 ESP 加载当前选定的启动壁纸；锁屏幻灯片不改启动或桌面壁纸。

冷启动验收时，只插已登记的 Key，优先使用已实测可预插解锁的 USB‑C 口（`a600000.usb`，不依赖动态的 USB 总线编号）。另一口 `a800000.usb` 有冷启动时 USB 地址分配失败（`error -71`）的实机记录，拔插后可重新枚举。更换 USB 枚举顺序没有解决，不带入正式配置；这不是 LUKS 登记问题，尚不能判定接口硬件损坏。

## 空白盘首启验收（2026-11-27）

- 从新 GPT、新 LUKS2 和空白 Btrfs 开始，直连 GitHub 克隆当时的 `flakes/master` `5875f0ee29608388f7942a87fe98b6403b64a6c7`，保持原始 `flake.lock`（SHA-256 `4f817c08b96abd4a068a228baf75700dbf93f824dfe6bf2002e7288f1789622e`）；硬件输入为 `812fedca35d72adf604dcb51284acaa3db5044d1`。原生 AArch64 构建和安装一次完成，没有复用失败轮的 store，也没有补装新代。
- 在 15 GiB RAM、无 swap 的 Live 中，把安装 U 盘插到下方稳定的 `a600000.usb`，从一开始使用 `nix build -L -v --max-jobs 1 --cores 4 --store /mnt` 构建当前 checkout 的 `nixosConfigurations.surface.config.system.build.toplevel`，再用 `nixos-install --root /mnt --system <构建所得闭包>` 安装。限制只作用于安装构建：此前一轮 U 盘断开后 SquashFS 读失败，另一轮全并发时可用内存降至约 1 GiB 后失联，不能据此诊断 RAM 硬件故障。
- 核验 Gen 1 和 45,054,976 字节的 ARM64 UKI 后正常关机，再拔 Live USB。第一次从内置盘开机，Key 预插下方口：约 1.20 s 枚举、1.77 s 提示触摸、4.45 s 解锁，第一次 USB 断开晚于解锁。机主确认 OLED 解锁画面可读，触摸后直接进桌面。SSH 只读核对运行系统即安装的 Gen 1，`/`、`/nix` 和 `/home` 全部为加密 Btrfs `compress=zstd:5,noatime`。

本轮通过的是**空白盘首次启动与预插 Key**。无 Key 的恢复密码启动要另测；服务在线不等于已经完成手势、录音或 Moonlight 串流验收。下次仍从当时最新的正式分支取源码，使用该 checkout 的锁，记录实际版本，不回退到本次提交。
