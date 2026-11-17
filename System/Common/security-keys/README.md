# 共享公开 FIDO 凭据

`credentials.json` 是用户已批准的两只 Key 的公开凭据，用户名 `keke`、RP/AppID
`pam://keke-flakes`。移动到共享层时未改动凭据字节，也没有重新登记硬件。

`default.nix` 只校验和生成只读映射，不启用 PAM、systemd、GUI 或任何平台服务。
Linux 策略在 `NixOS/server/security-keys.nix`；macOS 策略在 `macOS/private/security.nix`。
不按厂商、型号、序列号自动授权新设备；身份检查不能代替凭据签名验证。

这些不是私钥，也不是 LUKS/FileVault/PIV 解锁材料。每个加密卷仍需单独登记。
新增/撤销需用户授权、逐只实测，再明确更新此表并部署所有使用端；旧系统版本可能恢复旧授权。
