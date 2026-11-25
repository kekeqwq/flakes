# Surface

`nixosConfigurations.surface` is the native AArch64 installation and replaces the old standalone and `secret-lab-surface-test` configurations. The unrelated `secret-lab` instance is unchanged.

- Hardware, kernel, device tree, touch, and zboot UKI lifecycle: the `surface.nix` input.
- Desktop and accounts: the standard NixOS desktop and shared programs in this flake. The host explicitly selects the Denali protected FullIO render module for its internal stereo speakers and MicArray. It does not install experimental audio monitors or tools into the user profile.
- The test install keeps NVMe root `NIXOS_ROOT` (ext4) and ESP `NIXOS_EFI` (VFAT), no swap, NTFS or initrd LVM. The formal install will separately review `secret-lab`'s LUKS2/FIDO2 setup and Btrfs/zstd; this configuration does not repartition, encrypt or enroll keys.
- Provision owner-held firmware at `/var/lib/surface-firmware` as documented in `surface.nix`. Keep firmware, private UKIs and SSH credentials out of Git and the public Nix store. The existing SSH authorized keys are deployed privately.
- Dedicated testing only: `ssh -o BatchMode=yes keke@<Surface-IP>` needs neither a password nor a client key and has no source-IP restriction. Since `keke` also has a host-local `NOPASSWD: ALL` sudo rule, anyone who can reach SSH can become root. Do not expose this test system to an untrusted network. Direct SSH root login remains disabled; remove both the SSH/PAM and sudo exceptions before formal use.

```sh
nix build .#checks.aarch64-linux.surface-boundaries --no-link
sudo nixos-rebuild switch --flake .#surface
```

The regular systemd-boot generation list boots Denali UKIs. Keep the separately archived, verified rescue UKIs and their closures until the new generation passes a real boot and desktop test. Do not add alternate test render profiles to this host.

## Gen21 test checkpoint (2026-11-25)

- `7.4.0-rc4-next-20261124-surface-fullio`, hardware input `d004185`, booted
  `/nix/store/06n33m9l1r5pd27lkgxjkngprxahnsnl-nixos-system-surface-26.11.20261121.56f282a`
  from the regular default Gen21 entry after `nixos-rebuild switch`. The
  two candidate one-shot images were validated separately; the consumed ESP
  entry is removed. Gen20 and the private ESP recovery archive are retained.
- Display/GPU: the desktop reported internal 2880×1920 at 120 Hz, scale 2;
  the headless GLES renderer was Adreno X1-85, with 1024 successful pixel
  readbacks. Pinned SSH, `sudo -n`, greetd and Wi-Fi were verified.
- Audio with a held graph: both WSA884x devices bound, FL→FL/FR→FR links,
  one endpoint arm on the running graph, 20 low-volume play/stop cycles,
  and five one-minute playback windows at about 48 kHz with no matching
  kernel errors. Probe tones were detected by MicArray and 192,000-frame
  duplex capture passed. This was not a long-term listening test.
- **Do not promote Gen21 as audio-stable.** An ordinary graph close reached
  SoundWire runtime suspend with both devices still Attached, then reopened
  and armed a new graph. Playback with capture after that reopen entered
  ALSA recovery: the compact mute readback reported an unmuted endpoint,
  PREPARE failed, and the PCM transfer path warned about a missing DMA area.
  PipeWire repeatedly attempted recovery. Stopped the audio user services
  for the current boot, verified PCM closed and DSP CLOSE/UNMAP ACKs, and
  kept the first-error logs privately. The initial trigger of recovery is
  not established. This result applies to original Gen21 only.

## Gen22 test default: Gen21 audio repair (2026-11-25)

Hardware input `0b5e96b` retains `next-20261124` and the reviewed endpoint
settings, but replaces a previously started DSP graph before re-PREPARE.
Native one-shot `3v4hgqi9…` passed three idle/reopen rounds followed by
192,000-frame playback/MicArray duplex runs. The same-fd ALSA DROP/PREPARE
regression also armed both graph epochs after full two-period priming; the
old graph's CLOSE and UNMAP were acknowledged. The one-shot rechecked
pinned SSH, `sudo -n`, greetd, Niri, FL/FR routing and the Adreno renderer.
After 20 playback cycles and a five-minute continuous playback soak passed,
`nixos-rebuild switch` installed that exact closure as Gen22. It rebooted from
its regular default entry, passed three more idle/reopen and duplex rounds,
and detected all three timed test tones on MicArray. The short runs do not
establish long-term listening stability or formal-use readiness. The test-only
SSH/PAM and sudo exceptions and the endpoint volume settings are unchanged.
