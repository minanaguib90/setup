# Cursor setup script (Windows)
# Run from this repo root. Creates .cursor\skills, clones repos, builds awesome-cursor-mpc-server.

$ErrorActionPreference = "Stop"
$cursor = "$env:USERPROFILE\.cursor"
$skills = "$cursor\skills"

Write-Host "Creating Cursor directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $skills -Force | Out-Null
New-Item -ItemType Directory -Path "$cursor\rules" -Force | Out-Null

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

# Build awesome-cursor-mpc-server
$mcpServer = "$skills\awesome-cursor-mpc-server"
if (-not (Test-Path "$mcpServer\src\env\keys.ts")) {
    Write-Host "Creating src\env\keys.ts for awesome-cursor-mpc-server..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path "$mcpServer\src\env" -Force | Out-Null
    "export const OPENAI_API_KEY = process.env.OPENAI_API_KEY || 'your_openai_key_here';" | Out-File -FilePath "$mcpServer\src\env\keys.ts" -Encoding utf8
}
Write-Host "Building awesome-cursor-mpc-server..." -ForegroundColor Cyan
Set-Location $mcpServer
npm install
npm run build

Write-Host "`nDone. Next steps:" -ForegroundColor Green
Write-Host "1. Copy mcp.json.example to $cursor\mcp.json"
Write-Host "2. Replace YOUR_GITHUB_PAT, YOUR_FIRECRAWL_API_KEY, YOUR_OPENAI_API_KEY"
Write-Host "3. In mcp.json, replace YOUR_USERNAME with $env:USERNAME in the awesome-cursor-mpc-server path"
Write-Host "4. Restart Cursor"
