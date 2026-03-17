# Cursor setup verification script (Windows)
# Verifies that the bundled bootstrap assets, MCP config, hooks, skills, rules,
# lessons, and key dependencies are installed as expected.

param(
    [string]$CursorPath = "$env:USERPROFILE\.cursor",
    [string]$TasksPath = "$env:USERPROFILE\Tasks",
    [string]$RepoRoot = $(Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = "Stop"
$script:Results = @()
$script:HasFailures = $false
$script:HasWarnings = $false

function Add-CheckResult {
    param(
        [string]$Status,
        [string]$Name,
        [string]$Detail
    )

    $script:Results += [pscustomobject]@{
        Status = $Status
        Name = $Name
        Detail = $Detail
    }

    if ($Status -eq "FAIL") {
        $script:HasFailures = $true
    } elseif ($Status -eq "WARN") {
        $script:HasWarnings = $true
    }
}

function Test-RequiredPath {
    param(
        [string]$Path,
        [string]$Name
    )

    if (Test-Path $Path) {
        Add-CheckResult -Status "PASS" -Name $Name -Detail $Path
        return $true
    }

    Add-CheckResult -Status "FAIL" -Name $Name -Detail "Missing: $Path"
    return $false
}

function Load-JsonFile {
    param(
        [string]$Path,
        [string]$Name
    )

    if (-not (Test-RequiredPath -Path $Path -Name $Name)) {
        return $null
    }

    try {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
        Add-CheckResult -Status "PASS" -Name "$Name JSON" -Detail "Parsed successfully"
        return $json
    } catch {
        Add-CheckResult -Status "FAIL" -Name "$Name JSON" -Detail $_.Exception.Message
        return $null
    }
}

function Test-CommandAvailable {
    param(
        [string]$CommandName,
        [bool]$Required = $true
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($command) {
        Add-CheckResult -Status "PASS" -Name "Command $CommandName" -Detail $command.Source
        return $command
    }

    $status = if ($Required) { "FAIL" } else { "WARN" }
    Add-CheckResult -Status $status -Name "Command $CommandName" -Detail "Not found on PATH"
    return $null
}

function Get-RepoRuleNames {
    $rulesRoot = Join-Path $RepoRoot "rules"
    if (-not (Test-Path $rulesRoot)) {
        return @()
    }

    return Get-ChildItem -Path $rulesRoot -File -Filter *.mdc | Select-Object -ExpandProperty Name
}

function Get-RepoSkillNames {
    $skillNames = @()
    $repoSkillsRoot = Join-Path $RepoRoot "skills"

    if (Test-Path $repoSkillsRoot) {
        $skillNames += Get-ChildItem -Path $repoSkillsRoot -Directory | Where-Object {
            Test-Path (Join-Path $_.FullName "SKILL.md")
        } | Select-Object -ExpandProperty Name
    }

    $skillNames += Get-ChildItem -Path $RepoRoot -Directory | Where-Object {
        $_.Name -notin @(".git", "skills", "Tasks", "rules") -and
        (Test-Path (Join-Path $_.FullName "SKILL.md"))
    } | Select-Object -ExpandProperty Name

    return $skillNames | Sort-Object -Unique
}

function Get-AnyEnvironmentValue {
    param([string]$Name)

    foreach ($scope in @("Process", "User", "Machine")) {
        $value = [System.Environment]::GetEnvironmentVariable($Name, $scope)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return ""
}

function Test-ConfiguredServerSecret {
    param(
        [object]$Server,
        [string]$EnvName,
        [string]$ServerName
    )

    if ($null -eq $Server -or $null -eq $Server.env) {
        Add-CheckResult -Status "WARN" -Name "$ServerName secret" -Detail "No env block found"
        return
    }

    $envBlock = $Server.env
    if ($envBlock.PSObject.Properties.Name -notcontains $EnvName) {
        Add-CheckResult -Status "WARN" -Name "$ServerName secret" -Detail "$EnvName is not configured"
        return
    }

    $value = [string]$envBlock.$EnvName
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match "^YOUR_" -or $value -match "your_.*_here") {
        Add-CheckResult -Status "FAIL" -Name "$ServerName secret" -Detail "$EnvName is still blank or placeholder"
    } else {
        Add-CheckResult -Status "PASS" -Name "$ServerName secret" -Detail "$EnvName is configured"
    }
}

Write-Host "Running Cursor setup verification..." -ForegroundColor Cyan

$skillsPath = Join-Path $CursorPath "skills"
$rulesPath = Join-Path $CursorPath "rules"
$mcpPath = Join-Path $CursorPath "mcp.json"
$hooksPath = Join-Path $CursorPath "hooks.json"
$lessonsPath = Join-Path $TasksPath "Lessons.md"

[void](Test-RequiredPath -Path $CursorPath -Name "Cursor root")
[void](Test-RequiredPath -Path $skillsPath -Name "Cursor skills dir")
[void](Test-RequiredPath -Path $rulesPath -Name "Cursor rules dir")
[void](Test-RequiredPath -Path $TasksPath -Name "Tasks dir")
[void](Test-RequiredPath -Path $lessonsPath -Name "Lessons.md")

$mcpConfig = Load-JsonFile -Path $mcpPath -Name "mcp.json"
$hooksConfig = Load-JsonFile -Path $hooksPath -Name "hooks.json"

if ($hooksConfig -and $hooksConfig.version -eq 1) {
    Add-CheckResult -Status "PASS" -Name "hooks.json version" -Detail "version 1"
} elseif ($hooksConfig) {
    Add-CheckResult -Status "FAIL" -Name "hooks.json version" -Detail "Unexpected or missing version"
}

if ($hooksConfig -and $hooksConfig.hooks -and $hooksConfig.hooks.preToolUse -and $hooksConfig.hooks.postToolUse) {
    Add-CheckResult -Status "PASS" -Name "hooks.json contents" -Detail "preToolUse and postToolUse hooks present"
} elseif ($hooksConfig) {
    Add-CheckResult -Status "FAIL" -Name "hooks.json contents" -Detail "Missing preToolUse or postToolUse hooks"
}

if ($mcpConfig -and $mcpConfig.mcpServers) {
    $serverNames = $mcpConfig.mcpServers.PSObject.Properties.Name
    foreach ($requiredServer in @("browser-devtools", "context-mode")) {
        if ($serverNames -contains $requiredServer) {
            Add-CheckResult -Status "PASS" -Name "MCP server $requiredServer" -Detail "Configured"
        } else {
            Add-CheckResult -Status "FAIL" -Name "MCP server $requiredServer" -Detail "Missing from mcp.json"
        }
    }

    if ($serverNames -contains "awesome-cursor-mpc-server") {
        $awesomeBuildPath = Join-Path $skillsPath "awesome-cursor-mpc-server\build\index.js"
        if (Test-Path $awesomeBuildPath) {
            Add-CheckResult -Status "PASS" -Name "awesome-cursor-mpc-server build artifact" -Detail $awesomeBuildPath
        } else {
            Add-CheckResult -Status "FAIL" -Name "awesome-cursor-mpc-server build artifact" -Detail "Missing build\index.js under Cursor skills"
        }
        $awesomeServer = $mcpConfig.mcpServers."awesome-cursor-mpc-server"
        $awesomeArgs = @($awesomeServer.args)
        if ($awesomeArgs.Count -gt 0 -and (Test-Path $awesomeArgs[0])) {
            Add-CheckResult -Status "PASS" -Name "awesome-cursor-mpc-server build path" -Detail $awesomeArgs[0]
        } else {
            Add-CheckResult -Status "FAIL" -Name "awesome-cursor-mpc-server build path" -Detail "Configured path is missing or invalid"
        }
        Test-ConfiguredServerSecret -Server $awesomeServer -EnvName "OPENAI_API_KEY" -ServerName "awesome-cursor-mpc-server"
    } else {
        $awesomeBuildPath = Join-Path $skillsPath "awesome-cursor-mpc-server\build\index.js"
        if (Test-Path $awesomeBuildPath) {
            Add-CheckResult -Status "PASS" -Name "awesome-cursor-mpc-server build artifact" -Detail "Present but MCP is not enabled"
        } else {
            Add-CheckResult -Status "PASS" -Name "awesome-cursor-mpc-server build artifact" -Detail "Optional MCP is not enabled and build artifact is not required"
        }
        Add-CheckResult -Status "PASS" -Name "MCP server awesome-cursor-mpc-server" -Detail "Optional MCP is intentionally not configured"
    }

    if ($serverNames -contains "github") {
        $githubServer = $mcpConfig.mcpServers.github
        $authHeader = if ($githubServer.headers) { [string]$githubServer.headers.Authorization } else { "" }
        if (
            -not [string]::IsNullOrWhiteSpace($authHeader) -and
            $authHeader -like "Bearer *" -and
            $authHeader.Trim() -ne "Bearer" -and
            $authHeader -notmatch "YOUR_GITHUB_PAT"
        ) {
            Add-CheckResult -Status "PASS" -Name "GitHub MCP token" -Detail "Configured"
        } else {
            Add-CheckResult -Status "FAIL" -Name "GitHub MCP token" -Detail "Authorization header is blank or placeholder"
        }
    }

    if ($serverNames -contains "firecrawl-mcp") {
        Test-ConfiguredServerSecret -Server $mcpConfig.mcpServers."firecrawl-mcp" -EnvName "FIRECRAWL_API_KEY" -ServerName "firecrawl-mcp"
    }
}

$ruleNames = Get-RepoRuleNames
foreach ($ruleName in $ruleNames) {
    $installedRule = Join-Path $rulesPath $ruleName
    [void](Test-RequiredPath -Path $installedRule -Name "Rule $ruleName")
}

$skillNames = Get-RepoSkillNames
foreach ($skillName in $skillNames) {
    $installedSkill = Join-Path $skillsPath "$skillName\SKILL.md"
    [void](Test-RequiredPath -Path $installedSkill -Name "Skill $skillName")
}

$lessonsText = if (Test-Path $lessonsPath) { Get-Content $lessonsPath -Raw } else { "" }
if ($lessonsText -match "\| Date \| What went wrong \| Rule for next time \|") {
    Add-CheckResult -Status "PASS" -Name "Lessons.md format" -Detail "Expected lesson table header found"
} else {
    Add-CheckResult -Status "WARN" -Name "Lessons.md format" -Detail "Expected table header not found"
}

[void](Test-CommandAvailable -CommandName "npm" -Required $true)
[void](Test-CommandAvailable -CommandName "npx" -Required $true)
[void](Test-CommandAvailable -CommandName "context-mode" -Required $true)

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    $pythonCommand = Get-Command py -ErrorAction SilentlyContinue
}

if ($pythonCommand) {
    Add-CheckResult -Status "PASS" -Name "Python runtime" -Detail $pythonCommand.Source
    & $pythonCommand.Source -c "import requests" *> $null
    if ($LASTEXITCODE -eq 0) {
        Add-CheckResult -Status "PASS" -Name "deep-thinking Python dependency" -Detail "requests import succeeded"
    } else {
        Add-CheckResult -Status "FAIL" -Name "deep-thinking Python dependency" -Detail "requests import failed"
    }
} else {
    Add-CheckResult -Status "WARN" -Name "Python runtime" -Detail "Not found; deep-thinking dependency checks skipped"
}

$deepThinkingKeyNames = @("OPENROUTER_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "KIMI_API_KEY")
$configuredDeepThinkingKeys = @($deepThinkingKeyNames | Where-Object { -not [string]::IsNullOrWhiteSpace((Get-AnyEnvironmentValue -Name $_)) })
if ($configuredDeepThinkingKeys.Count -gt 0) {
    Add-CheckResult -Status "PASS" -Name "deep-thinking API keys" -Detail ("Configured: " + ($configuredDeepThinkingKeys -join ", "))
} else {
    Add-CheckResult -Status "WARN" -Name "deep-thinking API keys" -Detail "No deep-thinking provider keys are configured yet"
}

Write-Host "`nVerification results:" -ForegroundColor Cyan
foreach ($result in $script:Results) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "White" }
    }
    Write-Host ("[{0}] {1}: {2}" -f $result.Status, $result.Name, $result.Detail) -ForegroundColor $color
}

if ($script:HasFailures) {
    Write-Host "`nCursor setup verification failed." -ForegroundColor Red
    exit 1
}

if ($script:HasWarnings) {
    Write-Host "`nCursor setup verification completed with warnings." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nCursor setup verification passed." -ForegroundColor Green
exit 0
