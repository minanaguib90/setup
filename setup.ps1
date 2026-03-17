# Cursor setup script (Windows)
# Run from this repo root. Creates Cursor directories, installs bundled rules/hooks/skills,
# configures MCP servers interactively, installs required dependencies, and builds bundled tools.

$ErrorActionPreference = "Stop"
$cursor = "$env:USERPROFILE\.cursor"
$skills = "$cursor\skills"
$rulesDir = "$cursor\rules"
$tasksDir = "$env:USERPROFILE\Tasks"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mcpTarget = "$cursor\mcp.json"

function Prompt-YesNo {
    param(
        [string]$Prompt,
        [bool]$DefaultYes = $true
    )

    $defaultText = if ($DefaultYes) { "Y/n" } else { "y/N" }
    $response = Read-Host "$Prompt [$defaultText]"
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }

    switch ($response.Trim().ToLower()) {
        "y" { return $true }
        "yes" { return $true }
        "n" { return $false }
        "no" { return $false }
        default {
            Write-Host "Please answer yes or no." -ForegroundColor Yellow
            return Prompt-YesNo -Prompt $Prompt -DefaultYes:$DefaultYes
        }
    }
}

function Read-OptionalValue {
    param(
        [string]$Prompt,
        [string]$Hint = "leave blank to skip"
    )

    $value = Read-Host "$Prompt ($Hint)"
    if ($null -eq $value) {
        return ""
    }
    return $value.Trim()
}

function Read-SecretValue {
    param(
        [string]$Prompt,
        [string]$Hint = "leave blank to skip"
    )

    $secureValue = Read-Host "$Prompt ($Hint)" -AsSecureString
    if ($null -eq $secureValue) {
        return ""
    }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
    try {
        $plainText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        if ($null -eq $plainText) {
            return ""
        }
        return $plainText.Trim()
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Load-McpServers {
    param([string]$Path)

    $servers = @{}
    if (-not (Test-Path $Path)) {
        return $servers
    }

    try {
        $existing = Get-Content $Path -Raw | ConvertFrom-Json
        if ($existing -and $existing.mcpServers) {
            foreach ($prop in $existing.mcpServers.PSObject.Properties) {
                $servers[$prop.Name] = $prop.Value
            }
        }
    } catch {
        Write-Host "Warning: Could not parse existing mcp.json. A fresh config will be written." -ForegroundColor Yellow
    }

    return $servers
}

function Save-McpServers {
    param(
        [hashtable]$Servers,
        [string]$Path
    )

    $orderedNames = @(
        "browser-devtools",
        "github",
        "firecrawl-mcp",
        "windows-mcp",
        "context-mode",
        "awesome-cursor-mpc-server"
    )
    $extraNames = $Servers.Keys | Where-Object { $_ -notin $orderedNames } | Sort-Object

    $config = [ordered]@{
        mcpServers = [ordered]@{}
    }

    foreach ($name in ($orderedNames + $extraNames)) {
        if ($Servers.ContainsKey($name)) {
            $config.mcpServers[$name] = $Servers[$name]
        }
    }

    $config | ConvertTo-Json -Depth 30 | Out-File -FilePath $Path -Encoding utf8
}

function Remove-McpServer {
    param(
        [hashtable]$Servers,
        [string]$Name
    )

    if ($Servers.ContainsKey($Name)) {
        [void]$Servers.Remove($Name)
    }
}

function Set-UserEnvVar {
    param(
        [string]$Name,
        [string]$Value
    )

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        [System.Environment]::SetEnvironmentVariable($Name, $Value, "User")
        Write-Host "Saved user environment variable: $Name" -ForegroundColor Cyan
    }
}

function Load-ManifestEntries {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @()
    }

    return Get-Content $Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

function Save-ManifestEntries {
    param(
        [string[]]$Entries,
        [string]$Path
    )

    ($Entries | Sort-Object -Unique) | Out-File -FilePath $Path -Encoding utf8
}

function Get-ExistingServerEnvValue {
    param(
        [hashtable]$Servers,
        [string]$ServerName,
        [string]$EnvName
    )

    if ($Servers.ContainsKey($ServerName)) {
        $server = $Servers[$ServerName]
        if ($null -ne $server -and $null -ne $server.env) {
            $envObject = $server.env
            if ($envObject.PSObject.Properties.Name -contains $EnvName) {
                return [string]$envObject.$EnvName
            }
        }
    }

    return ""
}

function Install-RepoSkill {
    param(
        [string]$SourceDir,
        [string]$SkillsDir
    )

    $skillName = Split-Path $SourceDir -Leaf
    $targetDir = Join-Path $SkillsDir $skillName
    if (Test-Path $targetDir) {
        Remove-Item $targetDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Copy-Item -Path "$SourceDir\*" -Destination $targetDir -Recurse -Force
    Write-Host "Installed bundled skill: $skillName" -ForegroundColor Cyan
}

function Merge-LessonsFile {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )

    if (-not (Test-Path $TargetPath)) {
        Copy-Item $SourcePath $TargetPath -Force
        Write-Host "Creating persistent Lessons.md..." -ForegroundColor Cyan
        return
    }

    $sourceRows = Get-Content $SourcePath | Where-Object {
        $_ -match '^\| ' -and $_ -notmatch '^\| Date ' -and $_ -notmatch '^\| ---'
    }
    $targetLines = Get-Content $TargetPath
    $targetLookup = @{}
    foreach ($line in $targetLines) {
        $targetLookup[$line] = $true
    }

    $missingRows = @($sourceRows | Where-Object { -not $targetLookup.ContainsKey($_) })
    if ($missingRows.Count -gt 0) {
        Add-Content -Path $TargetPath -Value ""
        Add-Content -Path $TargetPath -Value $missingRows
        Write-Host "Merged new baseline lessons into $TargetPath" -ForegroundColor Cyan
    } else {
        Write-Host "Keeping existing Lessons.md: $TargetPath" -ForegroundColor Yellow
    }
}

Write-Host "Creating Cursor directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $skills -Force | Out-Null
New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
New-Item -ItemType Directory -Path $tasksDir -Force | Out-Null

$repos = @(
    @{ url = "https://github.com/sickn33/antigravity-awesome-skills.git"; name = "antigravity-awesome-skills" },
    @{ url = "https://github.com/chrisboden/cursor-skills.git"; name = "cursor-skills" },
    @{ url = "https://github.com/araguaci/cursor-skills.git"; name = "araguaci-cursor-skills" },
    @{ url = "https://github.com/numman-ali/openskills.git"; name = "openskills" },
    @{ url = "https://github.com/PatrickJS/awesome-cursorrules.git"; name = "awesome-cursorrules" },
    @{ url = "https://github.com/blefnk/awesome-cursor-rules.git"; name = "awesome-cursor-rules" },
    @{ url = "https://github.com/sanjeed5/awesome-cursor-rules-mdc.git"; name = "awesome-cursor-rules-mdc" },
    @{ url = "https://github.com/kleneway/awesome-cursor-mpc-server.git"; name = "awesome-cursor-mpc-server" }
)

Set-Location $skills
foreach ($r in $repos) {
    if (Test-Path $r.name) {
        Write-Host "Exists: $($r.name)" -ForegroundColor Yellow
    } else {
        Write-Host "Cloning $($r.name)..." -ForegroundColor Green
        git clone $r.url $r.name
    }
}

Write-Host "Installing global CLI tools..." -ForegroundColor Cyan
npm install -g vibe-tools context-mode

# Install bundled global hooks and rules from this repo
$hooksSource = Join-Path $repoRoot "hooks.json"
$hooksTarget = Join-Path $cursor "hooks.json"
if (Test-Path $hooksSource) {
    Write-Host "Installing bundled hooks.json..." -ForegroundColor Cyan
    Copy-Item $hooksSource $hooksTarget -Force
}

$rulesSource = Join-Path $repoRoot "rules"
if (Test-Path $rulesSource) {
    $rulesManifest = Join-Path $rulesDir ".setup-bundled-rules.txt"
    $previousRuleNames = Load-ManifestEntries -Path $rulesManifest
    $currentRuleNames = Get-ChildItem -Path $rulesSource -File -Filter *.mdc | Select-Object -ExpandProperty Name
    foreach ($oldRule in $previousRuleNames) {
        if ($oldRule -notin $currentRuleNames) {
            $oldRulePath = Join-Path $rulesDir $oldRule
            if (Test-Path $oldRulePath) {
                Remove-Item $oldRulePath -Force
                Write-Host "Removed retired bundled rule: $oldRule" -ForegroundColor Cyan
            }
        }
    }
    Write-Host "Installing bundled Cursor rules..." -ForegroundColor Cyan
    Copy-Item -Path "$rulesSource\*" -Destination $rulesDir -Recurse -Force
    Save-ManifestEntries -Entries $currentRuleNames -Path $rulesManifest
}

$lessonsSource = Join-Path $repoRoot "Tasks\Lessons.md"
$lessonsTarget = Join-Path $tasksDir "Lessons.md"
if (Test-Path $lessonsSource) {
    Merge-LessonsFile -SourcePath $lessonsSource -TargetPath $lessonsTarget
}

# Install bundled skills from skills/ and any top-level repo directories containing SKILL.md
$bundledSkillDirs = @()
$repoSkillsRoot = Join-Path $repoRoot "skills"
if (Test-Path $repoSkillsRoot) {
    $bundledSkillDirs += Get-ChildItem -Path $repoSkillsRoot -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName "SKILL.md")
    } | Select-Object -ExpandProperty FullName
}

$bundledSkillDirs += Get-ChildItem -Path $repoRoot -Directory | Where-Object {
    $_.Name -notin @(".git", "skills", "Tasks", "rules") -and
    (Test-Path (Join-Path $_.FullName "SKILL.md"))
} | Select-Object -ExpandProperty FullName

$bundledSkillDirs = $bundledSkillDirs | Sort-Object -Unique
$skillsManifest = Join-Path $skills ".setup-bundled-skills.txt"
$previousSkillNames = Load-ManifestEntries -Path $skillsManifest
$currentSkillNames = @($bundledSkillDirs | ForEach-Object { Split-Path $_ -Leaf })
foreach ($oldSkill in $previousSkillNames) {
    if ($oldSkill -notin $currentSkillNames) {
        $oldSkillPath = Join-Path $skills $oldSkill
        if (Test-Path $oldSkillPath) {
            Remove-Item $oldSkillPath -Recurse -Force
            Write-Host "Removed retired bundled skill: $oldSkill" -ForegroundColor Cyan
        }
    }
}
foreach ($skillDir in $bundledSkillDirs) {
    Install-RepoSkill -SourceDir $skillDir -SkillsDir $skills
}
Save-ManifestEntries -Entries $currentSkillNames -Path $skillsManifest

# Interactive MCP and environment setup
Write-Host "`nInteractive MCP and environment configuration..." -ForegroundColor Cyan
$mcpServers = Load-McpServers -Path $mcpTarget
$mcpServers["browser-devtools"] = [ordered]@{
    command = "npx"
    args = @("-y", "browser-devtools-mcp@latest")
}
$mcpServers["context-mode"] = [ordered]@{
    command = "context-mode"
}

$hasGithub = $mcpServers.ContainsKey("github")
if (Prompt-YesNo -Prompt "Configure GitHub MCP?" -DefaultYes:$hasGithub) {
    $githubPat = Read-SecretValue -Prompt "GitHub PAT" -Hint "leave blank to keep existing, or skip if none"
    if (-not [string]::IsNullOrWhiteSpace($githubPat)) {
        $mcpServers["github"] = [ordered]@{
            url = "https://api.githubcopilot.com/mcp/"
            headers = [ordered]@{
                Authorization = "Bearer $githubPat"
            }
        }
    } elseif (-not $hasGithub) {
        Write-Host "Skipping GitHub MCP; no token provided." -ForegroundColor Yellow
    }
} else {
    Remove-McpServer -Servers $mcpServers -Name "github"
}

$hasFirecrawl = $mcpServers.ContainsKey("firecrawl-mcp")
if (Prompt-YesNo -Prompt "Configure Firecrawl MCP?" -DefaultYes:$hasFirecrawl) {
    $firecrawlKey = Read-SecretValue -Prompt "Firecrawl API key" -Hint "leave blank to keep existing, or skip if none"
    if (-not [string]::IsNullOrWhiteSpace($firecrawlKey)) {
        $mcpServers["firecrawl-mcp"] = [ordered]@{
            command = "npx"
            args = @("-y", "firecrawl-mcp")
            env = [ordered]@{
                FIRECRAWL_API_KEY = $firecrawlKey
            }
        }
    } elseif (-not $hasFirecrawl) {
        Write-Host "Skipping Firecrawl MCP; no key provided." -ForegroundColor Yellow
    }
} else {
    Remove-McpServer -Servers $mcpServers -Name "firecrawl-mcp"
}

$hasWindowsMcp = $mcpServers.ContainsKey("windows-mcp")
$uvxInstalled = $null -ne (Get-Command uvx -ErrorAction SilentlyContinue)
$defaultWindowsMcp = if ($hasWindowsMcp) { $true } else { $uvxInstalled }
if (Prompt-YesNo -Prompt "Enable Windows-MCP (requires uvx on PATH)?" -DefaultYes:$defaultWindowsMcp) {
    $mcpServers["windows-mcp"] = [ordered]@{
        command = "uvx"
        args = @("windows-mcp")
        env = [ordered]@{
            ANONYMIZED_TELEMETRY = "false"
        }
    }
} else {
    Remove-McpServer -Servers $mcpServers -Name "windows-mcp"
}

$awesomePath = Join-Path $skills "awesome-cursor-mpc-server\build\index.js"
$hasAwesome = $mcpServers.ContainsKey("awesome-cursor-mpc-server")
$openaiKey = ""
if ($hasAwesome -and [string]::IsNullOrWhiteSpace($openaiKey)) {
    $openaiKey = Get-ExistingServerEnvValue -Servers $mcpServers -ServerName "awesome-cursor-mpc-server" -EnvName "OPENAI_API_KEY"
}
if (Prompt-YesNo -Prompt "Configure awesome-cursor-mpc-server?" -DefaultYes:$true) {
    $promptedOpenAiKey = Read-SecretValue -Prompt "OpenAI API key for awesome-cursor-mpc-server" -Hint "leave blank to keep existing, or skip if none"
    if (-not [string]::IsNullOrWhiteSpace($promptedOpenAiKey)) {
        $openaiKey = $promptedOpenAiKey
    }
    if (-not [string]::IsNullOrWhiteSpace($openaiKey)) {
        $mcpServers["awesome-cursor-mpc-server"] = [ordered]@{
            command = "node"
            args = @($awesomePath)
            env = [ordered]@{
                OPENAI_API_KEY = $openaiKey
            }
        }
    } elseif (-not $hasAwesome) {
        Write-Host "Skipping awesome-cursor-mpc-server in mcp.json; no key provided." -ForegroundColor Yellow
    }
} else {
    Remove-McpServer -Servers $mcpServers -Name "awesome-cursor-mpc-server"
}

Save-McpServers -Servers $mcpServers -Path $mcpTarget
Write-Host "Wrote MCP configuration to $mcpTarget" -ForegroundColor Cyan

$configureDeepThinking = Test-Path (Join-Path $skills "deep-thinking-multi-model\SKILL.md")
if ($configureDeepThinking -and (Prompt-YesNo -Prompt "Configure deep-thinking-multi-model environment variables?" -DefaultYes:$true)) {
    $openRouterKey = Read-SecretValue -Prompt "OPENROUTER_API_KEY" -Hint "recommended; leave blank to skip"
    $deepThinkOpenAiKey = if (-not [string]::IsNullOrWhiteSpace($openaiKey)) {
        $openaiKey
    } else {
        Read-SecretValue -Prompt "OPENAI_API_KEY" -Hint "optional direct-model key; leave blank to skip"
    }
    $anthropicKey = Read-SecretValue -Prompt "ANTHROPIC_API_KEY" -Hint "optional; leave blank to skip"
    $kimiKey = Read-SecretValue -Prompt "KIMI_API_KEY" -Hint "optional; leave blank to skip"

    Set-UserEnvVar -Name "OPENROUTER_API_KEY" -Value $openRouterKey
    Set-UserEnvVar -Name "OPENAI_API_KEY" -Value $deepThinkOpenAiKey
    Set-UserEnvVar -Name "ANTHROPIC_API_KEY" -Value $anthropicKey
    Set-UserEnvVar -Name "KIMI_API_KEY" -Value $kimiKey
}

if (-not [string]::IsNullOrWhiteSpace($openaiKey)) {
    Set-UserEnvVar -Name "OPENAI_API_KEY" -Value $openaiKey
}

# Install Python dependencies for bundled skills when Python is available
$deepThinkingRequirements = Join-Path $skills "deep-thinking-multi-model\scripts\requirements.txt"
if (Test-Path $deepThinkingRequirements) {
    $pythonCommand = if (Get-Command py -ErrorAction SilentlyContinue) {
        "py"
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        "python"
    } else {
        $null
    }

    if ($pythonCommand) {
        Write-Host "Installing deep-thinking-multi-model Python dependencies..." -ForegroundColor Cyan
        try {
            & $pythonCommand -m pip install -r $deepThinkingRequirements
        } catch {
            Write-Host "Warning: Could not install Python requirements for deep-thinking-multi-model." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Python not found; skipping deep-thinking-multi-model dependency install." -ForegroundColor Yellow
    }
}

# Build awesome-cursor-mpc-server
$mcpServer = Join-Path $skills "awesome-cursor-mpc-server"
if (Test-Path $mcpServer) {
    if (-not (Test-Path "$mcpServer\src\env\keys.ts")) {
        Write-Host "Creating src\env\keys.ts for awesome-cursor-mpc-server..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path "$mcpServer\src\env" -Force | Out-Null
        "export const OPENAI_API_KEY = process.env.OPENAI_API_KEY || 'your_openai_key_here';" | Out-File -FilePath "$mcpServer\src\env\keys.ts" -Encoding utf8
    }
    Write-Host "Building awesome-cursor-mpc-server..." -ForegroundColor Cyan
    Set-Location $mcpServer
    npm install
    npm run build
} else {
    Write-Host "awesome-cursor-mpc-server repo not found; skipping build." -ForegroundColor Yellow
}

Write-Host "`nDone. Next steps:" -ForegroundColor Green
Write-Host "1. Confirm $cursor\mcp.json, $cursor\hooks.json, $rulesDir, and $tasksDir\Lessons.md are present"
Write-Host "2. Restart Cursor so MCP servers, hooks, rules, and new environment variables are picked up"
Write-Host "3. In Cursor, verify browser-devtools, context-mode, and any optional MCP servers you enabled are green"
