# Test Feishu Webhook - Fix signature

$FeishuScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path }
$c = Join-Path $FeishuScriptDir "feishu.config"
$w = ""
$s = ""

if (Test-Path $c) {
    foreach ($l in Get-Content $c) {
        if ($l -match "FEISHU_WEBHOOK_URL=(.+)") { $w = $Matches[1].Trim() }
        if ($l -match "FEISHU_SIGN_KEY=(.+)") { $s = $Matches[1].Trim() }
    }
}

Write-Host "Webhook URL: $w" -ForegroundColor Cyan
Write-Host "Sign Key: $s" -ForegroundColor Cyan

# Test without signature first
Write-Host "`n--- Test 1: Card Message WITHOUT Signature ---" -ForegroundColor Yellow
$BodyNoSign = @{
    msg_type = "interactive"
    card = @{
        header = @{
            title = @{ tag = "plain_text"; content = "Git Auto Push Test" }
            template = "green"
        }
        elements = @(@{
            tag = "div"
            text = @{ tag = "lark_md"; content = "Test WITHOUT sign`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
        })
    }
} | ConvertTo-Json -Depth 10

try {
    $Response = Invoke-RestMethod -Uri $w -Method Post -Body $BodyNoSign -ContentType "application/json" -TimeoutSec 10
    Write-Host "Response: $($Response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# Test with corrected signature (milliseconds timestamp)
Write-Host "`n--- Test 2: Card Message WITH Signature (ms) ---" -ForegroundColor Yellow
$ts = [int64](Get-Date -UFormat %s) * 1000  # Convert to milliseconds
Write-Host "Timestamp (ms): $ts" -ForegroundColor Cyan

$stringToSign = "$ts`n$s"
Write-Host "String to sign: $stringToSign" -ForegroundColor Cyan

$hmac = New-Object Security.Cryptography.HMACSHA256
$hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($s)
$signature = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))
$signBase64 = [System.Convert]::ToBase64String($signature)
Write-Host "Signature: $signBase64" -ForegroundColor Cyan

$BodyWithSign = @{
    msg_type = "interactive"
    timestamp = $ts
    sign = $signBase64
    card = @{
        header = @{
            title = @{ tag = "plain_text"; content = "Git Auto Push Test" }
            template = "green"
        }
        elements = @(@{
            tag = "div"
            text = @{ tag = "lark_md"; content = "Test WITH sign (ms)`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
        })
    }
} | ConvertTo-Json -Depth 10

try {
    $Response = Invoke-RestMethod -Uri $w -Method Post -Body $BodyWithSign -ContentType "application/json" -TimeoutSec 10
    Write-Host "Response: $($Response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# Test with seconds timestamp
Write-Host "`n--- Test 3: Card Message WITH Signature (seconds) ---" -ForegroundColor Yellow
$tsSec = [int64](Get-Date -UFormat %s)
Write-Host "Timestamp (sec): $tsSec" -ForegroundColor Cyan

$stringToSignSec = "$tsSec`n$s"
$hmac2 = New-Object Security.Cryptography.HMACSHA256
$hmac2.Key = [System.Text.Encoding]::UTF8.GetBytes($s)
$signature2 = $hmac2.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSignSec))
$signBase64Sec = [System.Convert]::ToBase64String($signature2)
Write-Host "Signature: $signBase64Sec" -ForegroundColor Cyan

$BodyWithSignSec = @{
    msg_type = "interactive"
    timestamp = $tsSec
    sign = $signBase64Sec
    card = @{
        header = @{
            title = @{ tag = "plain_text"; content = "Git Auto Push Test" }
            template = "green"
        }
        elements = @(@{
            tag = "div"
            text = @{ tag = "lark_md"; content = "Test WITH sign (sec)`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
        })
    }
} | ConvertTo-Json -Depth 10

try {
    $Response = Invoke-RestMethod -Uri $w -Method Post -Body $BodyWithSignSec -ContentType "application/json" -TimeoutSec 10
    Write-Host "Response: $($Response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
