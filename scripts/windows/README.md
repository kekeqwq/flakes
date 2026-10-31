# Mac → Windows PC Sunshine

## Confirmed cursor fix

On this PC's Windows 11 Insider build, the original Sunshine capture path did not show the host cursor in Moonlight. Pointer trails did not fix it and were restored to the original value (`0`).

The user confirmed that the cursor is visible with the WGC trial. The persistent configuration therefore uses `capture = wgc` in an **interactive desktop session**, not the Windows service. This only affects the Windows PC; it does not alter Mac global mouse preferences or Deck settings.

## Install / rollback

Run `Install-SunshineInteractive.ps1` as administrator under the intended Windows user (the script can also run over that user's SSH connection):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-SunshineInteractive.ps1
```

The installer:

- Creates the `Sunshine-Interactive` Scheduled Task, running at user logon, with restart-on-failure and no execution time limit.
- Disables `SunshineService` to prevent duplicate listeners.
- Generates `%LOCALAPPDATA%\Sunshine\sunshine-interactive.conf` with WGC capture and audio streaming enabled.
- Reuses existing apps, server certificates, paired-client trust and Web UI credentials from `C:\Program Files\Sunshine\config`; no pairing reset or private-key copying is required.
- Saves the original service startup type in `%LOCALAPPDATA%\Sunshine\interactive-install-backup.json`.

It starts when the user signs into the Windows desktop, not before login. Do not separately start the old Windows service while the task is running.

Rollback:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-SunshineInteractive.ps1 -Uninstall
```

This removes the task and restores the original service startup type. The original Sunshine config is left intact.

Restart the interactive instance:

```powershell
Stop-ScheduledTask -TaskName Sunshine-Interactive
Start-ScheduledTask -TaskName Sunshine-Interactive
```

Logs: `%LOCALAPPDATA%\Sunshine\sunshine-interactive.log`.

## Audio verification

`stream_audio = enabled` uses the normal default Windows audio output; no Steam audio driver is required. `C:\Program Files\Sunshine\tools\audio-info.exe` lists available devices.

A real playback test is necessary because a silent desktop may send no audio packets. A Windows notification sound was played in the signed-in session, and the Mac Moonlight log confirmed receipt of the first audio packet with stereo CoreAudio playback.
