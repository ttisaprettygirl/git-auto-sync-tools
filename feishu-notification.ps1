# Feishu Notification

$FeishuScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path }

function Send-FeishuNotification($R) {
    $c = Join-Path $FeishuScriptDir "feishu.config"
    $w = ""
    $s = ""
    if (Test-Path $c) {
        foreach ($l in Get-Content $c) {
            if ($l -match "FEISHU_WEBHOOK_URL=(.+)") { $w = $Matches[1].Trim() }
            if ($l -match "FEISHU_SIGN_KEY=(.+)") { $s = $Matches[1].Trim() }
        }
    }
    if (-not $w) {
        Write-Host "No webhook" -ForegroundColor Yellow
        return $false
    }
    $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tmp = if ($R.FailedCount -eq 0) { "green" } else { "red" }
    $st = if ($R.FailedCount -eq 0) { "[OK]" } else { "[WARN]" }
    $det = ""
    foreach ($f in $R.Folders) {
        $ic = if ($f.Success) { "[OK]" } else { "[FAIL]" }
        $det += "$ic $($f.Name)`n"
        if ($f.ErrorMessage) { $det += "  Err: $($f.ErrorMessage)`n" }
        elseif ($f.Changed) { $det += "  Pushed: $($f.FilesChanged)`n" }
        else { $det += "  No change`n" }
    }
    $cnt = "Time: $t`n$st Total: $($R.TotalCount) Success: $($R.SuccessCount) Failed: $($R.FailedCount)`n`n$det"
    $b = @{msg_type="interactive";card=@{header=@{title=@{tag="plain_text";content="Git Push"};template=$tmp};elements=@(@{tag="div";text=@{tag="lark_md";content=$cnt}})}}
    if ($s) {
        $ts = [int64](Get-Date -UFormat %s)
        $b.timestamp = $ts
        $h = New-Object Security.Cryptography.HMACSHA256
        $h.Key = [Text.Encoding]::UTF8.GetBytes($s)
        $sig = $h.ComputeHash([Text.Encoding]::UTF8.GetBytes("$ts`n$s"))
        $b.sign = [Convert]::ToBase64String($sig)
    }
    try {
        Invoke-RestMethod -Uri $w -Method Post -Body ($b|ConvertTo-Json -Depth 10) -ContentType "application/json" -TimeoutSec 10 | Out-Null
        Write-Host "Feishu OK" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Feishu Err: $_" -ForegroundColor Red
        return $false
    }
}
