# Feishu Notification Module
# Sends Git auto-push results to Feishu

function Send-FeishuNotification {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Result,
        [string]$ConfigPath = "C:\Users\jerez\Desktop\git-auto-sync-tools\feishu.config"
    )

    # Read config file
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Feishu config not found at: $ConfigPath" -ForegroundColor Yellow
        return $false
    }

    $config = Get-Content $ConfigPath | Where-Object { $_ -match "FEISHU_WEBHOOK_URL=" }
    if ($config) {
        $webhookUrl = ($config -split "=")[1].Trim()
    } else {
        Write-Host "FEISHU_WEBHOOK_URL not found in config" -ForegroundColor Yellow
        return $false
    }

    # Read sign key if exists
    $signKey = ""
    $signConfig = Get-Content $ConfigPath | Where-Object { $_ -match "FEISHU_SIGN_KEY=" }
    if ($signConfig) {
        $signKey = ($signConfig -split "=")[1].Trim()
    }

    # Build card message
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Determine template color based on success/failure
    $template = if ($Result.FailedCount -eq 0) { "green" } else { "red" }

    # Build status emoji and text
    $statusEmoji = if ($Result.FailedCount -eq 0) { "✅" } else { "⚠️" }
    $statusText = if ($Result.FailedCount -eq 0) { "全部成功" } else { "部分失败" }

    # Build folder details
    $folderDetails = ""
    foreach ($folder in $Result.Folders) {
        $emoji = if ($folder.Success) { "✅" } else { "❌" }
        $folderDetails += "$emoji **$($folder.Name)**`n"
        if (-not $folder.Success -and $folder.Error) {
            $folderDetails += "   └ 错误: $($folder.Error)`n"
        } elseif ($folder.Success -and $folder.Changed) {
            $folderDetails += "   └ 已推送: $($folder.FilesChanged) 个文件`n"
        } elseif ($folder.Success -and -not $folder.Changed) {
            $folderDetails += "   └ 无更改，已跳过`n"
        }
    }

    # Build card content
    $cardContent = @"
**执行时间**：$timestamp
**状态**：$statusEmoji $statusText
**总计**：$($Result.TotalCount) 个文件夹 | **成功**：$($Result.SuccessCount) | **失败**：$($Result.FailedCount)

**文件夹详情**：
$folderDetails
"@

    # Build message body
    $timestampUnix = [int64](Get-Date -UFormat %s)
    $body = @{
        msg_type = "interactive"
        timestamp = $timestampUnix
        sign = if ($signKey) { Generate-Signature -Timestamp $timestampUnix -Key $signKey } else { "" }
        card = @{
            header = @{
                title = @{
                    tag = "plain_text"
                    content = "Git Auto Push Report"
                }
                template = $template
            }
            elements = @(
                @{
                    tag = "div"
                    text = @{
                        tag = "lark_md"
                        content = $cardContent
                    }
                }
            )
        }
    }

    # Remove sign key if empty
    if (-not $signKey) {
        $body.Remove("sign")
        $body.Remove("timestamp")
    }

    $jsonBody = $body | ConvertTo-Json -Depth 10

    # Send request
    try {
        $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $jsonBody -ContentType "application/json" -TimeoutSec 10

        if ($response.StatusCode -eq 0 -or $response.code -eq 0) {
            Write-Host "Feishu notification sent successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Feishu notification failed: $($response | ConvertTo-Json)" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "Feishu notification error: $_" -ForegroundColor Red
        return $false
    }
}

function Generate-Signature {
    param(
        [int64]$Timestamp,
        [string]$Key
    )

    $stringToSign = "$Timestamp`n$Key"
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($Key)
    $signature = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signatureBase64 = [System.Convert]::ToBase64String($signature)

    return $signatureBase64
}
