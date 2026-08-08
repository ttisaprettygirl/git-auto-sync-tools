# Git Auto Sync Tools

> Automatically push Desktop files to GitHub every hour with Feishu notifications

## Features

- **Auto Push**: Automatically detects and pushes git changes every hour
- **Multiple Folders**: Monitor and sync multiple folders simultaneously
- **Feishu Notifications**: Get instant notifications of push results
- **Cross-Platform Sync**: Use across multiple computers via GitHub
- **Wake-on-LAN**: Handles computer sleep/hibernation gracefully

## Quick Start

### 1. Clone or Download

```bash
git clone https://github.com/YOUR_USERNAME/git-auto-sync-tools.git
cd git-auto-sync-tools
```

### 2. Configure

Copy template files and modify:

```powershell
# Copy sync folders template
copy sync-folders.template.json sync-folders.json

# Copy Feishu config template
copy feishu.config.template feishu.config
```

**Edit `sync-folders.json`**:
```json
{
  "folders": [
    {
      "path": "C:\\Users\\YOUR_USERNAME\\Desktop\\02_工作",
      "name": "工作"
    },
    {
      "path": "C:\\Users\\YOUR_USERNAME\\Desktop\\1991",
      "name": "创业项目"
    }
  ]
}
```

**Edit `feishu.config`**:
```
FEISHU_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_WEBHOOK_URL
FEISHU_SIGN_KEY=YOUR_SIGN_KEY
```

### 3. Install Scheduled Task

Run PowerShell as Administrator:

```powershell
.\setup-task-scheduler.ps1 -Action Install
```

### 4. Test

Run the script manually to test:

```powershell
.\auto-git-push.ps1
```

Check your Feishu group for the notification.

## File Structure

```
git-auto-sync-tools/
├── auto-git-push.ps1              # Main script
├── feishu-notification.ps1       # Feishu notification module
├── setup-task-scheduler.ps1      # Task scheduler installer
├── sync-folders.template.json     # Config template
├── feishu.config.template        # Feishu config template
├── sync-folders.json             # Your config (don't commit)
├── feishu.config                 # Your Feishu config (don't commit)
├── logs/                         # Execution logs
└── README.md
```

## Feishu Setup

### Create Feishu Bot

1. Open Feishu App and go to your target group
2. Group Settings -> Group Bots -> Add Bot -> Custom Bot
3. Set name: `Git Auto Push Notification`
4. Copy the Webhook URL
5. (Optional) Enable signature verification for security

### Test Webhook

```powershell
$WebhookUrl = "YOUR_WEBHOOK_URL"
$Body = @{msg_type="text"; content=@{text="Test"}} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $Body -ContentType "application/json"
```

## Commands

### Install Scheduled Task
```powershell
.\setup-task-scheduler.ps1 -Action Install
```

### Check Status
```powershell
.\setup-task-scheduler.ps1 -Action Status
```

### Uninstall
```powershell
.\setup-task-scheduler.ps1 -Action Uninstall
```

### Manual Run
```powershell
.\auto-git-push.ps1
```

## Adding New Folders

Edit `sync-folders.json`:

```json
{
  "folders": [
    {"path": "C:\\Users\\YourName\\Desktop\\Folder1", "name": "描述1"},
    {"path": "C:\\Users\\YourName\\Desktop\\Folder2", "name": "描述2"},
    {"path": "C:\\Users\\YourName\\Desktop\\NewFolder", "name": "新项目"}
  ]
}
```

## Troubleshooting

### Push Failed

If git push fails:
1. Check git credentials: `git config --list`
2. Configure GitHub credential manager or use Personal Access Token
3. Test manually: `cd your-folder && git push`

### No Feishu Notification

1. Check `feishu.config` exists and has correct URL
2. Check log file in `logs/` directory
3. Test Webhook manually with curl or PowerShell

### Task Not Running

1. Check Task Scheduler: `taskschd.msc`
2. Look for "AutoGitPush" task
3. Check task history for errors

## License

MIT
