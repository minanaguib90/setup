# Cursor IDE Setup

One-time setup instructions to get this Cursor configuration on any Windows PC. Clone this repo and follow the steps below.

## Prerequisites

- **Cursor IDE** (v0.48.0+ recommended for MCP)
- **Git** — [git-scm.com](https://git-scm.com/)
- **Node.js 18+** (includes npm/npx) — [nodejs.org](https://nodejs.org/)
- **Python 3.10+** (optional, for `uv`/Windows-MCP) — [python.org](https://www.python.org/)

---

## 1. Cursor directories

Create the folders Cursor uses for skills and config (if they don't exist):

```powershell
$cursor = "$env:USERPROFILE\.cursor"
New-Item -ItemType Directory -Path "$cursor\skills" -Force
New-Item -ItemType Directory -Path "$cursor\rules" -Force
```

---

## 2. Clone skills & rules collections

Run from PowerShell (adjust `$cursor` if you use a different Cursor home):

```powershell
$cursor = "$env:USERPROFILE\.cursor\skills"
cd $cursor

git clone https://github.com/sickn33/antigravity-awesome-skills.git antigravity-awesome-skills
git clone https://github.com/chrisboden/cursor-skills.git cursor-skills
git clone https://github.com/araguaci/cursor-skills.git araguaci-cursor-skills
git clone https://github.com/numman-ali/openskills.git openskills
git clone https://github.com/PatrickJS/awesome-cursorrules.git awesome-cursorrules
git clone https://github.com/blefnk/awesome-cursor-rules.git awesome-cursor-rules
git clone https://github.com/sanjeed5/awesome-cursor-rules-mdc.git awesome-cursor-rules-mdc
git clone https://github.com/kleneway/awesome-cursor-mpc-server.git awesome-cursor-mpc-server
```

---

## 3. Build awesome-cursor-mpc-server

This MCP server provides architect, screenshot, and code-review tools.

```powershell
cd "$env:USERPROFILE\.cursor\skills\awesome-cursor-mpc-server"
```

Create the env file (required for build):

```powershell
New-Item -ItemType Directory -Path "src\env" -Force
@"
export const OPENAI_API_KEY = process.env.OPENAI_API_KEY || 'your_openai_key_here';
"@ | Out-File -FilePath "src\env\keys.ts" -Encoding utf8
```

Install and build:

```powershell
npm install
npm run build
```

---

## 4. Install global tools

```powershell
npm install -g vibe-tools
```

**Optional – Windows-MCP (Windows automation):**  
Install [uv](https://docs.astral.sh/uv/getting-started/installation/) so `uvx` is on PATH, then the config below will work. Or skip the `windows-mcp` block in `mcp.json` if you don't need it.

---

## 5. MCP configuration

1. Copy the example config to Cursor's global MCP file:

   ```powershell
   $cursor = "$env:USERPROFILE\.cursor"
   Copy-Item "mcp.json.example" "$cursor\mcp.json"
   ```

   Or create `%USERPROFILE%\.cursor\mcp.json` manually.

2. Edit `%USERPROFILE%\.cursor\mcp.json` and replace:

   | Placeholder | Where to get it |
   |-------------|------------------|
   | `YOUR_GITHUB_PAT` | [GitHub → Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens) (e.g. `repo`, `read:org`) |
   | `YOUR_FIRECRAWL_API_KEY` | [Firecrawl → API keys](https://www.firecrawl.dev/app/api-keys) |
   | `YOUR_OPENAI_API_KEY` | [OpenAI → API keys](https://platform.openai.com/api-keys) (for awesome-cursor-mpc-server) |

3. **Fix the path** in `awesome-cursor-mpc-server` → `args`: use your actual path to `build\index.js`, e.g.:

   `C:\Users\YOUR_USERNAME\.cursor\skills\awesome-cursor-mpc-server\build\index.js`

4. Restart Cursor. In **Settings → Tools & Integrations → MCP** you should see the servers (green when connected).

---

## 6. What you get

| Category | Contents |
|----------|----------|
| **Skills** | antigravity-awesome-skills, cursor-skills, araguaci-cursor-skills, openskills, awesome-cursorrules, awesome-cursor-rules, awesome-cursor-rules-mdc |
| **MCP servers** | GitHub (repos, issues, PRs), Firecrawl (web scrape/search), Windows-MCP (optional), awesome-cursor-mpc-server (architect, screenshot, code review) |
| **Global CLI** | vibe-tools (AI team: web search, GitHub, Perplexity/Gemini) |

---

## Quick setup script (optional)

From the repo root (where this README lives), you can run:

```powershell
.\setup.ps1
```

It will create directories, clone the skill repos, and build awesome-cursor-mpc-server. You still need to copy `mcp.json.example` to `%USERPROFILE%\.cursor\mcp.json`, add your API keys, fix the path to `build\index.js`, and restart Cursor.

---

## Files in this repo

| File | Purpose |
|------|--------|
| `README.md` | This setup guide |
| `mcp.json.example` | Example MCP config (placeholders only; copy to `~/.cursor/mcp.json` and fill in keys) |
| `setup.ps1` | Optional script to clone skills and build awesome-cursor-mpc-server |

---

## Troubleshooting

- **MCP servers red / not connecting**  
  Restart Cursor. Ensure JSON in `mcp.json` is valid. For Firecrawl/OpenAI, check env keys. For Windows-MCP, ensure `uvx` is on PATH.

- **awesome-cursor-mpc-server path**  
  Must be the **full path** to `build\index.js` on your machine (replace `YOUR_USERNAME` or run from your home dir).

- **GitHub MCP**  
  Requires Cursor v0.48.0+ for Streamable HTTP. Use a PAT with at least `repo` (and `read:org` if you use orgs).

- **Secrets**  
  Don't commit real keys. Use `mcp.json.example` in the repo; keep your real `mcp.json` only on your machine (or use Cursor's secret inputs if available).
