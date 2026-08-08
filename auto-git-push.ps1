# Auto Git Push Script with Feishu Notification
# Automatically pushes changes to GitHub every hour and sends notifications

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$configFile = Join-Path $ScriptDir "sync-folders.json"
$logDir = Join-Path $ScriptDir "logs"
$feishuModule = Join-Path $ScriptDir "feishu-notification.ps1"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$logFile = Join-Path $logDir "auto-push-$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry

    switch ($Level) {
        'INFO'    { Write-Host $logEntry -ForegroundColor Cyan }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
    }
}

function Process-Folder {
    param(
        [string]$Path,
        [string]$Name = "Unknown"
    )

    Write-Log "========== Processing: $Name ($Path) ==========" 'INFO'

    $Result = @{
        Name = $Name
        Success = $false
        Changed = $false
        FilesChanged = ""
        ErrorMessage = ""
    }

    try {
        $ResolvedPath = Resolve-Path $Path -ErrorAction Stop
    } catch {
        $ErrorMsgMsg = "Cannot resolve path"
        Write-Log "$ErrorMsgMsg : $Path" 'ERROR'
        $Result.ErrorMessage = $ErrorMsgMsg
        return $Result
    }

    if (-not (Test-Path -LiteralPath $ResolvedPath)) {
        $ErrorMsgMsg = "Folder does not exist"
        Write-Log "$ErrorMsgMsg, skipping" 'ERROR'
        $Result.ErrorMessage = $ErrorMsgMsg
        return $Result
    }

    $gitDir = Join-Path $ResolvedPath ".git"
    if (-not (Test-Path -LiteralPath $gitDir)) {
        $ErrorMsgMsg = "Not a git repository (no .git folder)"
        Write-Log "$ErrorMsgMsg, skipping" 'WARNING'
        $Result.ErrorMessage = $ErrorMsgMsg
        return $Result
    }

    Push-Location -LiteralPath $ResolvedPath

    try {
        $status = git status --porcelain 2>&1

        if ($LASTEXITCODE -ne 0) {
            $ErrorMsg = "Git status failed: $status"
            Write-Log $ErrorMsg 'ERROR'
            $Result.ErrorMessage = $ErrorMsg
            Pop-Location
            return $Result
        }

        if ([string]::IsNullOrWhiteSpace($status)) {
            Write-Log "No changes detected, skipping" 'INFO'
            $Result.Success = $true
            $Result.Changed = $false
            Pop-Location
            return $Result
        }

        Write-Log "Changes detected, preparing to commit..." 'INFO'
        Write-Log "Changed files:`n$status" 'INFO'

        $Result.Changed = $true
        $Result.FilesChanged = ($status -split "`n").Count

        $addResult = git add . 2>&1
        if ($LASTEXITCODE -ne 0) {
            $ErrorMsg = "Git add failed: $addResult"
            Write-Log $ErrorMsg 'ERROR'
            $Result.ErrorMessage = $ErrorMsg
            Pop-Location
            return $Result
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $commitMessage = "Auto commit: $timestamp"
        $commitResult = git commit -m $commitMessage 2>&1

        if ($LASTEXITCODE -ne 0) {
            $ErrorMsg = "Git commit failed: $commitResult"
            Write-Log $ErrorMsg 'ERROR'
            $Result.ErrorMessage = $ErrorMsg
            Pop-Location
            return $Result
        }

        Write-Log "Commit successful: $commitMessage" 'SUCCESS'

        Write-Log "Pushing to remote..." 'INFO'
        $pushResult = git push 2>&1

        if ($LASTEXITCODE -ne 0) {
            $ErrorMsg = "Git push failed: $pushResult"
            Write-Log $ErrorMsg 'ERROR'
            $Result.ErrorMessage = $ErrorMsg
            Pop-Location
            return $Result
        }

        Write-Log "Push successful!" 'SUCCESS'
        $Result.Success = $true
        Pop-Location
        return $Result

    } catch {
        $ErrorMsg = "Exception occurred: $_"
        Write-Log $ErrorMsg 'ERROR'
        $Result.ErrorMessage = $ErrorMsg
        Pop-Location
        return $Result
    }
}

# Main execution
Write-Log "========================================" 'INFO'
Write-Log "Auto Git Push Script Started" 'INFO'
Write-Log "========================================" 'INFO'

if (-not (Test-Path $configFile)) {
    Write-Log "Config file not found: $configFile" 'ERROR'
    exit 1
}

try {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
    Write-Log "Config loaded successfully, $($config.folders.Count) folders" 'SUCCESS'
} catch {
    Write-Log "Config parse failed: $_" 'ERROR'
    exit 1
}

$totalFolders = $config.folders.Count
$successCount = 0
$failedCount = 0

$FolderResults = @()

foreach ($folder in $config.folders) {
    $result = Process-Folder -Path $folder.path -Name $folder.name
    $FolderResults += $result

    if ($result.Success) {
        $successCount++
    } else {
        $failedCount++
    }
}

Write-Log "========================================" 'INFO'
Write-Log "Execution completed!" 'INFO'
Write-Log "Total: $totalFolders | Success: $successCount | Failed: $failedCount" 'INFO'
Write-Log "========================================" 'INFO'

# Send Feishu notification
if (Test-Path $feishuModule) {
    Write-Log "Sending Feishu notification..." 'INFO'

    try {
        . $feishuModule

        $NotificationResult = @{
            TotalCount = $totalFolders
            SuccessCount = $successCount
            FailedCount = $failedCount
            Folders = $FolderResults
        }

        $Sent = Send-FeishuNotification $NotificationResult

        if ($Sent) {
            Write-Log "Feishu notification sent successfully" 'SUCCESS'
        } else {
            Write-Log "Feishu notification failed (non-critical)" 'WARNING'
        }
    } catch {
        Write-Log "Feishu notification error: $_" 'WARNING'
    }
} else {
    Write-Log "Feishu module not found, skipping notification" 'INFO'
}
