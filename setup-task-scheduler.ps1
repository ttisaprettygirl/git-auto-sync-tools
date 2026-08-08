# Task Scheduler Setup Script for Auto Git Push
# Run this script to install or uninstall the Windows scheduled task

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Install', 'Uninstall', 'Status')]
    [string]$Action = 'Install'
)

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptPath = Join-Path $ScriptDir "auto-git-push.ps1"
$TaskName = "AutoGitPush"

function Show-Status {
    Write-Host "=== Current Status ===" -ForegroundColor Cyan

    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        Write-Host "Task Name: $($task.TaskName)" -ForegroundColor Green
        Write-Host "State: $($task.State)" -ForegroundColor Green
        Write-Host "Description: $($task.Description)" -ForegroundColor Green

        Write-Host "`n=== Triggers ===" -ForegroundColor Cyan
        foreach ($trigger in $task.Triggers) {
            Write-Host "  - $($trigger.Frequency): $($trigger.StartBoundary)" -ForegroundColor Yellow
        }

        Write-Host "`n=== Action ===" -ForegroundColor Cyan
        Write-Host "  Execute: $($task.Action.Execute)" -ForegroundColor Yellow
        Write-Host "  Arguments: $($task.Action.Arguments)" -ForegroundColor Yellow

    } catch {
        Write-Host "Task '$TaskName' not found" -ForegroundColor Red
    }
}

function Install-Task {
    Write-Host "=== Installing Scheduled Task ===" -ForegroundColor Cyan

    # Check if script exists
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "ERROR: Script not found at: $ScriptPath" -ForegroundColor Red
        exit 1
    }

    # Remove existing task
    try {
        Unregister-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue -Confirm:$false
        Write-Host "Removed existing task" -ForegroundColor Yellow
    } catch {}

    # Create action
    $Action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""

    # Create trigger (every hour)
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)

    # Create settings (wake on retry, etc)
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -WakeToRun -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5) -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    # Register task
    try {
        Register-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -TaskName $TaskName -Description '每小时自动推送 git 更改到 GitHub' -User 'SYSTEM' | Out-Null
        Write-Host "Task installed successfully!" -ForegroundColor Green
        Write-Host "  Task Name: $TaskName" -ForegroundColor Green
        Write-Host "  Trigger: Every hour" -ForegroundColor Green
        Write-Host "  Script: $ScriptPath" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to register task: $_" -ForegroundColor Red
        exit 1
    }

    # Test run
    Write-Host "`nDo you want to test run the script now? (Y/N)" -ForegroundColor Yellow
    $answer = Read-Host
    if ($answer -eq 'Y' -or $answer -eq 'y') {
        Write-Host "Running test..." -ForegroundColor Cyan
        & $ScriptPath
    }
}

function Uninstall-Task {
    Write-Host "=== Uninstalling Scheduled Task ===" -ForegroundColor Cyan

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host "Task uninstalled successfully!" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to uninstall task: $_" -ForegroundColor Red
        exit 1
    }
}

# Main
switch ($Action) {
    'Install' {
        Install-Task
    }
    'Uninstall' {
        Uninstall-Task
    }
    'Status' {
        Show-Status
    }
}

Write-Host "`nDone!" -ForegroundColor Green
