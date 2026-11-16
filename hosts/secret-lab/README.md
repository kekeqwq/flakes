# 新电脑安装：LUKS2 加密 + Btrfs 压缩 + YubiKey 触摸解锁

虚拟机只是用来验证这套方案。下面按**刚收到一台新电脑，直接安装到实体硬盘**来写，
不需要先搭虚拟机、SSH、缓存服务器或 Sunshine。

适用范围：UEFI、x86_64、整盘安装。最终是：

- 硬盘使用 **LUKS2** 加密。
- Btrfs 的 `/`、`/nix`、`/home` 开启 **zstd:3 压缩**。
- 开机插入已登记的 YubiKey，闪灯时触摸即可解锁，无日常 PIN。
- 没有 Key 也能用恢复密码进入，输错不会永久锁盘。

**以下分区命令会清空所选硬盘。先备份旧数据，拔掉不相关的硬盘，并插入你指定的 YubiKey。**
恢复密码只在本地隐藏提示输入；不写进配置、Git、命令参数或聊天。
本目录两个 `.sh` 是虚拟机专用保护脚本，**不要在实体机运行或删掉其检查**。

## 1. 制作安装 U 盘并启动

下载 [NixOS 官方 Minimal x86_64 ISO](https://releases.nixos.org/nixos/unstable/nixos-26.11pre1119549.d5cc68339997/nixos-minimal-26.11pre1119549.d5cc68339997-x86_64-linux.iso)。
本轮使用的文件 SHA256：

```text
927b3102d3d1e2e7339803e2055c7511eb693e9869f7cc5202829341dfc0119e
```

校验后用 Etcher 等工具写入 U 盘，以 **UEFI 模式**启动并联网。
这套配置未部署 Secure Boot 签名；不要把它当作已支持 Secure Boot 的安装方案。

进入安装环境后打开 root 终端，准备工具并取得仓库：

```sh
sudo -i
export NIX_CONFIG='experimental-features = nix-command flakes'

# 固定版本的安装工具，避免运行时取 latest。
packages=github:NixOS/nixpkgs/085af13c1607f4f73ab1e7a51071faf6577a7e87
nix shell "$packages#git" "$packages#parted" "$packages#dosfstools" \
  "$packages#btrfs-progs" "$packages#cryptsetup" "$packages#systemd" \
  "$packages#coreutils" "$packages#util-linux" -c bash

git clone https://github.com/kekeqwq/flakes /root/flakes
cd /root/flakes
```

后面的命令都在这台新电脑的 root 安装终端执行。安装时保持这层工具环境，不需要再套 sudo。

## 2. 选对硬盘，建立加密卷

先看型号、容量和序列号，**不要照抄别人的 `/dev/nvme0n1` 或虚拟机 `/dev/vda`**：

```sh
lsblk -d -o NAME,SIZE,MODEL,SERIAL
ls -l /dev/disk/by-id/

# 必须换成刚核对过的目标硬盘，不是安装 U 盘。
disk=/dev/disk/by-id/REPLACE_WITH_YOUR_DISK
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS "$disk"
```

确认整块目标盘允许清空，再继续。下面用 `newpc` 作为示例机器名/分区名，不代表仓库已注册这台机器。

```sh
test ! -e /dev/mapper/cryptroot
test ! -e /dev/disk/by-partlabel/newpc-cryptroot

# 清空目标盘，创建 1 GiB EFI 分区，其余空间留给 LUKS。
parted --script "$disk" -- mklabel gpt \
  mkpart newpc-efi fat32 1MiB 1025MiB set 1 esp on \
  mkpart newpc-cryptroot 1025MiB 100%
udevadm settle

mkfs.fat -F 32 -n NEWPC_EFI /dev/disk/by-partlabel/newpc-efi
luks=/dev/disk/by-partlabel/newpc-cryptroot
cryptsetup luksFormat --type luks2 --pbkdf argon2id "$luks"
cryptsetup open "$luks" cryptroot
```

`luksFormat` 会要求确认并设置恢复密码；使用至少 12 字符的独立密码并私下妥善保存。
`cryptsetup open` 再次输入它。此时只有恢复密码，后面才登记 Key。

## 3. 创建 Btrfs，并在安装前打开压缩

```sh
umask 022
mkfs.btrfs -L newpc-root /dev/mapper/cryptroot
mkdir -p /mnt
mount -o compress=zstd:3,noatime /dev/mapper/cryptroot /mnt
for name in root nix home; do
  btrfs subvolume create "/mnt/@$name"
done
umount /mnt

mount -o subvol=@root,compress=zstd:3,noatime /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{nix,home,boot}
mount -o subvol=@nix,compress=zstd:3,noatime /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@home,compress=zstd:3,noatime /dev/mapper/cryptroot /mnt/home
mount -o umask=0077 /dev/disk/by-label/NEWPC_EFI /mnt/boot
chmod 0755 /mnt /mnt/nix /mnt/home

findmnt -R /mnt -o TARGET,FSTYPE,OPTIONS
```

**压缩要在这里就开启**，再往盘里安装系统；三个 Btrfs 挂载应都能看到 `compress=zstd:3`。
下一步还会把相同选项写进配置，确保重启后保留。只在安装结束后补选项，不会追溯重压旧数据。

## 4. 为这台电脑添加主机配置

只生成本机硬件信息，不让自动生成的文件重复定义下面手写的文件系统：

```sh
cd /root/flakes
mkdir -p hosts/newpc
nixos-generate-config --root /mnt --no-filesystems --show-hardware-config \
  > hosts/newpc/hardware-configuration.nix
```

编辑 `hosts/newpc/default.nix`，写入：

```nix
{ ... }:
let
  btrfs = name: {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@${name}" "compress=zstd:3" "noatime" ];
  };
in
{
  imports = [
    ../../NixOS/desktop/baseline.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "newpc";
  system.stateVersion = "26.11";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  my.luks = {
    enable = true;
    name = "cryptroot";
    device = "/dev/disk/by-partlabel/newpc-cryptroot";
    fido2.enable = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NEWPC_EFI";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };
  fileSystems."/" = btrfs "root";
  fileSystems."/nix" = btrfs "nix";
  fileSystems."/home" = btrfs "home";
  swapDevices = [ ];
  boot.kernelParams = [ "nohibernate" ];
}
```

在仓库 `flake.nix` 的现有 `nixosConfigurations` 注册处加一行：

```nix
nixosConfigurations.newpc = mkNixos { modules = [ ./hosts/newpc ]; };
```

```sh
git add hosts/newpc flake.nix
```

否则 Git flake 看不到新文件。公共用户名仍是 `keke`；显卡等机器差异只补在本机配置里，
不复制桌面包表，不导入 Deck/Jovian 或 `secret-lab` 的虚拟硬件配置。
`stateVersion` 按首次安装版本确定，后续升级不要随便改它。

## 5. 私有备份卷头，然后登记 YubiKey

先确认恢复密码确实可用：

```sh
cryptsetup open --test-passphrase --key-slot 0 "$luks"
```

准备另一个**已挂载的私有备份介质**，最好本身已加密。以下约定挂在 `/run/recovery`；
不要把它当成普通空目录，也不要把备份留在即将断电的安装环境内存盘。

```sh
mountpoint -q /run/recovery || { echo '请先挂载私有备份介质'; exit 1; }
umask 077
backup="/run/recovery/newpc-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cryptsetup luksHeaderBackup "$luks" --header-backup-file "$backup/before.header"

systemd-cryptenroll --fido2-device=list
# 将 /dev/hidrawN 换成已核对的指定 Key；不要按列表第一个猜。
systemd-cryptenroll "$luks" --fido2-device=/dev/hidrawN \
  --fido2-with-client-pin=no \
  --fido2-with-user-presence=yes \
  --fido2-with-user-verification=no

cryptsetup luksHeaderBackup "$luks" --header-backup-file "$backup/after.header"
chmod 600 "$backup/"*.header
```

在本地提示输入恢复密码，**Key 闪灯请求时触摸**；可能请求第二次触摸。
如果要求未知 PIN 就停止，不猜、不改 PIN，不 reset Key，也不动 OTP/PIV/OpenPGP。
保留密码 slot，私下记下 Key 标签与新增 slot 号。第二只 Key 可以日后单独重复登记，不覆盖第一只。

这些头部备份也是私有恢复材料，不能进 Git 或公开 Nix store。
每个新加密卷都要独立登记；sudo/锁屏的公开凭据不能代替它。
以后撤销某只 Key 必须核对具体 slot；旧头部备份仍可能恢复旧授权，需一起管理。

## 6. 安装、设置账户密码并重启

```sh
cd /root/flakes
nixos-install --flake .#newpc --root /mnt --no-root-passwd --no-channel-copy
passwd --root /mnt keke

umount -R /mnt
cryptsetup close cryptroot
# 正常卸载私有备份介质后，再关机。
umount /run/recovery
poweroff
```

`passwd` 设置的是 **keke 的账户登录密码**，与硬盘恢复密码独立；两者都不写进配置。
关机后拔掉安装 U 盘，保留已登记 Key，重新开机。桌面/字体的外部资源限制仍以
[`NixOS/desktop/README.md`](../../NixOS/desktop/README.md) 为准，不把一次安装等同于全桌面资源审计。

## 7. 首次启动只检查这几件事

1. **插 Key 启动**：灯闪时触摸，不输密码或 PIN，应进入桌面。
2. **拔 Key 再启动**：应能用恢复密码进入；错误密码应拒绝但仍可重试。
3. 进入后确认压缩仍启用：

```sh
for path in / /nix /home; do
  findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS "$path"
done
```

当前配置等待 Key 约 **10 秒**：窗口内后插可以触摸解锁；超时转入密码回退后，不会因后插而
自动重新尝试 Key。平时开机前插好即可。只在 LED 请求时触摸，避免 OTP 误输入。

至此就是一台加密、压缩、Key 或恢复密码解锁的新电脑。分区和每卷 Key 登记是一次性私有操作；
引导和压缩选项已在仓库声明，后续正常 rebuild 不需要重新格式化或登记。
未配置 Secure Boot/签名，本方案保护静态数据，不防 ESP/initrd 被恶意替换。

实验的详细证据与遗留问题另见 [`tests/secret-lab-2026-11-16.md`](../../tests/secret-lab-2026-11-16.md)
和 [`tests/HANDOFF-2026-11-16.md`](../../tests/HANDOFF-2026-11-16.md)，不需要为安装新电脑重做那些虚拟机操作。
