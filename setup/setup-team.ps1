<#
.SYNOPSIS
  One-time setup of ONE bot (Claude account + Discord bot) for a 2-bot team workspace.
  Run it once per bot: -Bot 1, then -Bot 2. Safe to re-run (skips what already exists).

.DESCRIPTION
  code  mode: each bot works in its own git worktree (<parent>\<Name>-bot1 / -bot2),
              shared board/log live in <Project>\_team (git-excluded), rules go into <Project>\CLAUDE.md.
  video mode: both bots share the project folder itself (no worktrees); project keeps its own rules.

  What it does (per bot):
    1. account config dir (bot 2 = separate login) + shared memory junction
    2. installs the Discord plugin for that account + allows its tools (otherwise the bot reads but never replies)
    3. Discord state dir: allowlist (your Discord user ID) + .env token from clipboard, written with LF line endings
    4. team board/log, team rules + skills (code mode), git worktree (code mode)
    5. ASCII-only launcher .bat (+ optional Windows Startup shortcut, minimized)
  It never prints or uploads the token.

.EXAMPLE
  # Bot 1 = the account you are already logged in with
  .\setup-team.ps1 -Project D:\Apps\myapp -Bot 1 -DiscordUserId 123456789012345678 -TokenFromClipboard -Startup
.EXAMPLE
  # Bot 2 = second account (log in when the script tells you to, then run it again)
  .\setup-team.ps1 -Project D:\Apps\myapp -Bot 2 -DiscordUserId 123456789012345678 -TokenFromClipboard -Startup
.EXAMPLE
  # Video project that keeps its team files in _bots and reuses existing Discord bots
  .\setup-team.ps1 -Project D:\ProjectStory -Bot 2 -Mode video -TeamDir D:\ProjectStory\_bots -StateDir $env:USERPROFILE\.claude\channels\discord2
#>
param(
  [Parameter(Mandatory = $true)][string]$Project,
  [Parameter(Mandatory = $true)][ValidateSet(1, 2)][int]$Bot,
  [ValidateSet('code', 'video')][string]$Mode = 'code',
  [string]$Name,              # short ASCII name for folders/titles (default: project folder name)
  [string]$ConfigDir,         # Claude account config (default: bot1 = ~\.claude, bot2 = ~\.claude-acc2)
  [string]$StateDir,          # Discord bot state (default: ~\.claude\channels\discord-<Name>-bot<N>)
  [string]$TeamDir,           # shared board/log (default: <Project>\_team)
  [string]$DiscordUserId,     # your Discord user ID -> allowlist (Developer Mode > right-click yourself > Copy User ID)
  [string]$AccessFrom,        # or copy an existing access.json
  [switch]$TokenFromClipboard,# copy the bot token first; it is read from the clipboard, never echoed
  [switch]$Startup,           # start this bot minimized when you log in to Windows
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$Kit = Split-Path -Parent $PSScriptRoot
$Utf8 = New-Object System.Text.UTF8Encoding $false
function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Info($m) { Write-Host "   $m" }
function Warn($m) { Write-Host "   ! $m" -ForegroundColor Yellow; $script:Todo += $m }
function Run($desc, [scriptblock]$a) { if ($DryRun) { Write-Host "   [dry-run] $desc" -ForegroundColor DarkGray } else { Info $desc; & $a } }
function IsAscii($s) { return ($s -match '^[\x20-\x7E]*$') }
function WriteText($path, $text) { [System.IO.File]::WriteAllText($path, $text, $Utf8) }
$script:Todo = @()

# ---------- resolve paths ----------
$Project = (Resolve-Path $Project).Path
if (-not $Name) { $Name = Split-Path $Project -Leaf }
if ($Name -notmatch '^[A-Za-z0-9._-]+$') { throw "-Name '$Name' must be ASCII letters/digits/._- (pass -Name myapp)" }
$DefaultConfig = Join-Path $env:USERPROFILE '.claude'
if (-not $ConfigDir) { if ($Bot -eq 1) { $ConfigDir = $DefaultConfig } else { $ConfigDir = Join-Path $env:USERPROFILE '.claude-acc2' } }
if (-not $StateDir) { $StateDir = Join-Path $DefaultConfig "channels\discord-$Name-bot$Bot" }
if (-not $TeamDir) { $TeamDir = Join-Path $Project '_team' }
if ($Mode -eq 'code') { $WorkDir = Join-Path (Split-Path $Project -Parent) "$Name-bot$Bot" } else { $WorkDir = $Project }
$IsDefaultConfig = ($ConfigDir.TrimEnd('\') -ieq $DefaultConfig)
$Launcher = Join-Path $TeamDir "bot$Bot.bat"

Write-Host "2BOT setup  bot=$Bot  mode=$Mode  name=$Name" -ForegroundColor Green
Info "project : $Project"
Info "workdir : $WorkDir"
Info "config  : $ConfigDir"
Info "discord : $StateDir"
Info "team    : $TeamDir"
foreach ($p in @($WorkDir, $ConfigDir, $StateDir, $TeamDir)) {
  if (-not (IsAscii $p)) { throw "Path must be ASCII-only (cmd.exe garbles non-ASCII in .bat files): $p" }
}

# ---------- 0. tools ----------
Step '0. tools'
foreach ($t in 'claude', 'git', 'bun') {
  if (Get-Command $t -ErrorAction SilentlyContinue) { Info "$t ok" } else { Warn "'$t' not found on PATH (bun is required by the Discord plugin: npm i -g bun)" }
}

# ---------- 1. account ----------
Step '1. Claude account'
if (-not $IsDefaultConfig) {
  if (-not (Test-Path $ConfigDir)) { Run "create $ConfigDir" { New-Item -ItemType Directory -Force $ConfigDir | Out-Null } }
  $proj = Join-Path $ConfigDir 'projects'
  if (-not (Test-Path $proj)) {
    Run "share memory: junction $proj -> $DefaultConfig\projects" {
      New-Item -ItemType Directory -Force (Join-Path $DefaultConfig 'projects') | Out-Null
      cmd /c mklink /J "$proj" "$DefaultConfig\projects" | Out-Null
    }
  } elseif (-not ((Get-Item $proj).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    Warn "$proj is a real folder, so memory is NOT shared with bot 1 (it existed before this script). Leave it, or move its contents into $DefaultConfig\projects and re-run."
  }
}
if ($IsDefaultConfig) { $cfgJson = Join-Path $env:USERPROFILE '.claude.json' } else { $cfgJson = Join-Path $ConfigDir '.claude.json' }
$email = $null
if (Test-Path $cfgJson) { try { $email = (Get-Content $cfgJson -Raw -Encoding UTF8 | ConvertFrom-Json).oauthAccount.emailAddress } catch {} }
if ($email) { Info "logged in as $email" }
else {
  if ($IsDefaultConfig) { $how = 'claude' } else { $how = "set CLAUDE_CONFIG_DIR=$ConfigDir && claude" }
  Warn "Not logged in. In cmd run:  $how   then /login with this bot's account (use a private browser window if your browser is signed in to the other account), /exit, and re-run this script."
}

# ---------- 2. plugin + permission ----------
Step '2. Discord plugin'
$saved = $env:CLAUDE_CONFIG_DIR
if ($IsDefaultConfig) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:CLAUDE_CONFIG_DIR = $ConfigDir }
try {
  $list = ''
  try { $list = (claude plugin list 2>&1 | Out-String) } catch {}
  if ($list -match 'discord@claude-plugins-official') { Info 'discord plugin already installed' }
  else { Run 'claude plugin install discord@claude-plugins-official' { claude plugin install discord@claude-plugins-official } }
} finally { if ($saved) { $env:CLAUDE_CONFIG_DIR = $saved } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } }

$settingsPath = Join-Path $ConfigDir 'settings.json'
$settings = New-Object PSObject
if (Test-Path $settingsPath) { $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if (-not $settings.permissions) { $settings | Add-Member -NotePropertyName permissions -NotePropertyValue (New-Object PSObject) -Force }
if (-not $settings.permissions.allow) { $settings.permissions | Add-Member -NotePropertyName allow -NotePropertyValue @() -Force }
if (@($settings.permissions.allow) -contains 'mcp__plugin_discord_discord') { Info 'Discord tools already allowed' }
else {
  Run "allow mcp__plugin_discord_discord in $settingsPath (otherwise the bot reads but never replies)" {
    $settings.permissions.allow = @($settings.permissions.allow) + 'mcp__plugin_discord_discord'
    WriteText $settingsPath ($settings | ConvertTo-Json -Depth 32)
  }
}

# ---------- 3. Discord bot state ----------
Step '3. Discord bot'
Run "create $StateDir" { New-Item -ItemType Directory -Force $StateDir | Out-Null }
$access = Join-Path $StateDir 'access.json'
if (Test-Path $access) { Info 'access.json exists (allowlist kept)' }
elseif ($AccessFrom) { Run "copy allowlist from $AccessFrom" { Copy-Item $AccessFrom $access } }
elseif ($DiscordUserId) {
  if ($DiscordUserId -notmatch '^\d{15,21}$') { throw "-DiscordUserId must be the numeric Discord user ID" }
  Run 'write allowlist (DMs from you only)' {
    WriteText $access ("{`n  ""dmPolicy"": ""allowlist"",`n  ""allowFrom"": [""$DiscordUserId""],`n  ""groups"": {},`n  ""pending"": {}`n}`n")
  }
} else { Warn "No allowlist. Re-run with -DiscordUserId <your id> (do NOT use /discord:access for a non-default bot: it writes into the default bot's folder)." }

$envFile = Join-Path $StateDir '.env'
if ($TokenFromClipboard) {
  $tok = ''
  try { $tok = ((Get-Clipboard) -join '').Trim() } catch {}
  if ($tok -notmatch '^[\w-]+\.[\w-]+\.[\w-]+$') { throw 'Clipboard does not contain a Discord bot token (Developer Portal > Bot > Reset Token > Copy).' }
  Run "write token to $envFile (LF line ending, not shown)" { [System.IO.File]::WriteAllText($envFile, "DISCORD_BOT_TOKEN=$tok`n", [System.Text.Encoding]::ASCII) }
  $tok = $null
} elseif (Test-Path $envFile) {
  $raw = [System.IO.File]::ReadAllText($envFile)
  if ($raw.Contains("`r")) { Run 'fix .env: CRLF -> LF (the plugin cannot read CRLF)' { [System.IO.File]::WriteAllText($envFile, $raw.Replace("`r", ''), [System.Text.Encoding]::ASCII) } }
  if ($raw -match 'DISCORD_BOT_TOKEN=[\w-]+\.[\w-]+\.[\w-]+') { Info 'token present' } else { Warn "No token in $envFile. Copy the bot token, re-run with -TokenFromClipboard." }
} else {
  Warn "No token yet. Copy the bot token (Developer Portal > Bot > Reset Token), re-run with -TokenFromClipboard."
}

# ---------- 4. team files, rules, worktree ----------
Step '4. team workspace'
Run "create $TeamDir" { New-Item -ItemType Directory -Force $TeamDir | Out-Null }
foreach ($f in 'BOARD.md', 'LOG.md') {
  $dst = Join-Path $TeamDir $f
  if (-not (Test-Path $dst)) { Run "add $f" { Copy-Item (Join-Path $Kit "templates\team\$f") $dst } }
}
if ($Mode -eq 'code') {
  if (-not (Test-Path (Join-Path $Project '.git'))) { throw "code mode needs a git repository: $Project" }
  $exclude = Join-Path $Project '.git\info\exclude'
  $rel = '/' + (Split-Path $TeamDir -Leaf) + '/'
  if ((Split-Path $TeamDir -Parent) -ieq $Project -and -not ((Test-Path $exclude) -and (Select-String -Path $exclude -SimpleMatch $rel -Quiet))) {
    Run "git-exclude $rel (live team state is not committed)" { Add-Content -Path $exclude -Value $rel -Encoding ASCII }
  }
  # rules + skills into the repo (committed once, so both worktrees get them)
  $claudeMd = Join-Path $Project 'CLAUDE.md'
  $marker = '<!-- 2BOT-TEAM -->'
  $hasRules = (Test-Path $claudeMd) -and ([System.IO.File]::ReadAllText($claudeMd, $Utf8).Contains($marker))
  $changed = @()
  if (-not $hasRules) {
    Run "append team rules to CLAUDE.md" {
      $tpl = [System.IO.File]::ReadAllText((Join-Path $Kit 'templates\CLAUDE.team-code.md'), $Utf8).Replace('{{TEAM_DIR}}', $TeamDir).Replace('{{NAME}}', $Name)
      $pre = ''; if (Test-Path $claudeMd) { $pre = [System.IO.File]::ReadAllText($claudeMd, $Utf8).TrimEnd() + "`n`n" }
      WriteText $claudeMd ($pre + $tpl)
    }
    $changed += 'CLAUDE.md'
  } else { Info 'team rules already in CLAUDE.md' }
  foreach ($sk in 'two-bot-dev', 'two-bot-setup') {
    $dst = Join-Path $Project ".claude\skills\$sk"
    if (-not (Test-Path $dst)) { Run "add skill .claude/skills/$sk" { New-Item -ItemType Directory -Force $dst | Out-Null; Copy-Item (Join-Path $Kit "skills\$sk\*") $dst -Recurse }; $changed += ".claude/skills/$sk" }
  }
  if ($changed.Count -gt 0) {
    Run "commit team rules on the current branch: $($changed -join ', ')" {
      git -C $Project add -- $changed
      git -C $Project commit -m "[setup] add 2-bot team rules and skills" -- $changed | Out-Null
    }
  }
  if (Test-Path $WorkDir) { Info "worktree exists: $WorkDir" }
  else { Run "git worktree add --detach $WorkDir (bot creates its own bot$Bot/<feature> branches)" { git -C $Project worktree add --detach $WorkDir HEAD | Out-Null } }
} else {
  Info 'video mode: bots share the project folder; keep the team rules in the project CLAUDE.md (see skill two-bot-setup)'
}

# ---------- 5. launcher ----------
Step '5. launcher'
$lines = @('@echo off', "title $Name - BOT $Bot", "cd /d ""$WorkDir""")
if (-not $IsDefaultConfig) { $lines += "set ""CLAUDE_CONFIG_DIR=$ConfigDir""" }
$lines += @("set ""DISCORD_STATE_DIR=$StateDir""", "set ""PS_BOT=bot$Bot""", "set ""TEAM_DIR=$TeamDir""",
  'echo Claude config : %CLAUDE_CONFIG_DIR%', 'echo Discord state : %DISCORD_STATE_DIR%',
  'claude --channels plugin:discord@claude-plugins-official --permission-mode auto', 'pause')
Run "write $Launcher" { [System.IO.File]::WriteAllText($Launcher, (($lines -join "`r`n") + "`r`n"), [System.Text.Encoding]::ASCII) }
if ($Startup) {
  $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) "$Name Bot $Bot.lnk"
  Run "Startup shortcut (minimized): $lnk" {
    $ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = $Launcher; $s.WorkingDirectory = $WorkDir; $s.WindowStyle = 7; $s.Save()
  }
}

# ---------- done ----------
Step 'next'
if ($script:Todo.Count -eq 0) { Info "Ready. Start the bot: double-click $Launcher, then DM the bot in Discord." }
else { $i = 1; foreach ($t in $script:Todo) { Write-Host "   $i. $t" -ForegroundColor Yellow; $i++ } }
Info 'If the bot is online but silent: in its window run /mcp (discord must be connected) and /reload-plugins.'
