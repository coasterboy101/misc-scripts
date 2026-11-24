<#
.SYNOPSIS
    Toggles ASUS ARGB, waits, then applies the default OpenRGB profile.

.DESCRIPTION
    Intended to run at logon via Windows Task Scheduler. Runs ToggleAsusARGB.exe,
    waits a configurable number of seconds, then starts OpenRGB with
    --nodetect -p default, then stops OpenRGB after a configurable number of seconds.

.PARAMETER DelaySeconds
    Seconds to wait between running ToggleAsusARGB and starting OpenRGB. Default: 10.

.PARAMETER ToggleExe
    Path to ToggleAsusARGB.exe.

.PARAMETER OpenRGBExe
    Path to OpenRGB.exe.

.PARAMETER ProfileName
    OpenRGB profile name to load. Default: default.

.PARAMETER KillAfterSeconds
    Seconds to let OpenRGB run before force-stopping it. Default: 5.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\Start-RGB.ps1" -DelaySeconds 15 -KillAfterSeconds 20

.SCHEDULED TASK
    $script = 'C:\Users\Rellis\Applications\RGB-Fix.ps1'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    Register-ScheduledTask -TaskName 'Fix RGB' -Action $action -Trigger $trigger -Principal $principal
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 3600)]
    [int]$DelaySeconds = 5,

    [string]$ToggleExe = 'C:\Users\Rellis\Applications\ToggleAsusARGB.exe',

    [string]$OpenRGBExe = 'C:\Program Files\OpenRGB\OpenRGB.exe',

    [string]$ProfileName = 'default',

    [ValidateRange(1, 3600)]
    [int]$KillAfterSeconds = 5
)

$ErrorActionPreference = 'Stop'

$logFile = Join-Path $env:TEMP 'Start-RGB.log'
function Write-Log([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    Add-Content -Path $logFile -Value $line
    Write-Verbose $line
}

try {
    foreach ($exe in $ToggleExe, $OpenRGBExe) {
        if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
            throw "Executable not found: $exe"
        }
    }

    Write-Log "Running $ToggleExe"
    Start-Process -FilePath $ToggleExe -WorkingDirectory (Split-Path $ToggleExe)

    Write-Log "Waiting $DelaySeconds second(s)"
    Start-Sleep -Seconds $DelaySeconds

    Write-Log "Starting $OpenRGBExe --nodetect -p $ProfileName"
    $openrgb = Start-Process -FilePath $OpenRGBExe `
        -WorkingDirectory (Split-Path $OpenRGBExe) `
        -ArgumentList '--nodetect', '-p', $ProfileName `
        -PassThru

    Write-Log "Waiting up to $KillAfterSeconds second(s) before stopping OpenRGB (PID $($openrgb.Id))"
    if ($openrgb.WaitForExit($KillAfterSeconds * 1000)) {
        Write-Log "OpenRGB exited on its own with code $($openrgb.ExitCode)"
    }
    else {
        Stop-Process -Id $openrgb.Id -Force
        Write-Log 'Stopped OpenRGB'
    }

    Write-Log 'Done'
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
