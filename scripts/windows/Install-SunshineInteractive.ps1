# Run as administrator. Uses an interactive logon task because WGC capture is
# incompatible with Sunshine's Windows-service launch mode on some builds.
param(
    [string]$SunshineDirectory = 'C:\Program Files\Sunshine',
    [string]$User = [Security.Principal.WindowsIdentity]::GetCurrent().Name,
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$taskName = 'Sunshine-Interactive'
$directory = Join-Path $env:LOCALAPPDATA 'Sunshine'
$statePath = Join-Path $directory 'interactive-install-backup.json'
New-Item -ItemType Directory -Path $directory -Force | Out-Null

if ($Uninstall) {
    if (-not (Test-Path $statePath)) { throw "Missing rollback state: $statePath" }
    $state = Get-Content $statePath -Raw | ConvertFrom-Json
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    Set-Service SunshineService -StartupType $state.ServiceStartType
    if ($state.ServiceStartType -ne 'Disabled') { Start-Service SunshineService }
    Write-Output 'Restored the original Sunshine service startup mode.'
    return
}

$exe = Join-Path $SunshineDirectory 'sunshine.exe'
$base = Join-Path $SunshineDirectory 'config'
if (-not (Test-Path $exe)) { throw "Sunshine executable not found: $exe" }
if (-not (Test-Path $statePath)) {
    @{ ServiceStartType = (Get-Service SunshineService).StartType.ToString() } |
        ConvertTo-Json | Set-Content -Encoding UTF8 $statePath
}

# Keep the existing apps, certificate, client trust database and UI credentials.
# The generated config contains file paths, never copies private keys into Git.
$text = [IO.File]::ReadAllText((Join-Path $base 'sunshine.conf'))
$settings = [ordered]@{
    capture = 'wgc'
    stream_audio = 'enabled'
    file_state = (Join-Path $base 'sunshine_state.json')
    credentials_file = (Join-Path $base 'sunshine_state.json')
    file_apps = (Join-Path $base 'apps.json')
    pkey = (Join-Path $base 'credentials\cakey.pem')
    cert = (Join-Path $base 'credentials\cacert.pem')
    log_path = (Join-Path $directory 'sunshine-interactive.log')
}
foreach ($key in $settings.Keys) {
    $text = [regex]::Replace($text, '(?m)^\s*' + [regex]::Escape($key) + '\s*=.*\r?\n?', '')
}
$text = $text.TrimEnd() + "`r`n"
foreach ($key in $settings.Keys) { $text += "$key = $($settings[$key])`r`n" }
$configPath = Join-Path $directory 'sunshine-interactive.conf'
[IO.File]::WriteAllText($configPath, $text, [Text.UTF8Encoding]::new($false))

$action = New-ScheduledTaskAction -Execute $exe -Argument ('"' + $configPath + '"') -WorkingDirectory $SunshineDirectory
$principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Highest
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal `
    -Trigger $trigger -Settings $taskSettings -Force | Out-Null
Stop-Service SunshineService -ErrorAction SilentlyContinue
Set-Service SunshineService -StartupType Disabled
Start-ScheduledTask -TaskName $taskName
Write-Output "Interactive Sunshine enabled for $User; config: $configPath"
Write-Output "Rollback: rerun this script with -Uninstall"
