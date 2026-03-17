# Cursor IDE Setup

One-time setup instructions to get this Cursor configuration on any Windows PC. Clone this repo and follow the steps below.
This repo also bundles:

- a local Cursor skill, `master-voip-engineer`, for telecom-grade VoIP troubleshooting and PBX design
- a bundled `deep-thinking-multi-model` skill for parallel frontier-model analysis
- global Cursor rules for a self-improvement loop and stricter task completion proof
- global Cursor rules for GUI-first admin workflows, plan review, and pause-and-ask implementation discipline
- a persistent `Tasks/Lessons.md` file
- [context-mode](https://github.com/mksglu/context-mode) MCP and hooks for context saving and session continuity
- `browser-devtools` MCP so the agent can use web UIs and admin dashboards when that is the right path
- an automated post-setup verification script so a new machine can self-check the installed Cursor state

## Prerequisites

- **Cursor IDE** (v0.48.0+ recommended for MCP)
- **Git** — [git-scm.com](https://git-scm.com/)
- **Node.js 18+** (includes npm/npx) — [nodejs.org](https://nodejs.org/)
- **Python 3.10+** (optional, for `uv`/Windows-MCP) — [python.org](https://www.python.org/)

---

## 1. Cursor directories

Create the folders Cursor uses for skills, rules, and persistent lessons (if they don't exist):

```powershell
$cursor = "$env:USERPROFILE\.cursor"
New-Item -ItemType Directory -Path "$cursor\skills" -Force
New-Item -ItemType Directory -Path "$cursor\rules" -Force
New-Item -ItemType Directory -Path "$env:USERPROFILE\Tasks" -Force
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

The repo-local bundled skills, bundled global Cursor rules, `hooks.json`, and `Tasks\Lessons.md` are copied into place by `setup.ps1`.

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
npm install -g vibe-tools context-mode
```

`setup.ps1` runs this for you automatically.

**Optional – Windows-MCP (Windows automation):**  
Install [uv](https://docs.astral.sh/uv/getting-started/installation/) so `uvx` is on PATH, then the config below will work. Or skip the `windows-mcp` block in `mcp.json` if you don't need it.

---

## 5. MCP configuration

`setup.ps1` now configures MCP interactively in one run. It:

- writes or updates `%USERPROFILE%\.cursor\mcp.json`
- always enables `browser-devtools` and `context-mode`
- prompts for optional GitHub, Firecrawl, OpenAI, and deep-thinking provider keys using hidden input
- resolves the `awesome-cursor-mpc-server\build\index.js` path from the actual Cursor skills directory

`mcp.json.example` remains in the repo as a reference template.

If you want to configure it manually instead, edit `%USERPROFILE%\.cursor\mcp.json` and replace:

   | Placeholder | Where to get it |
   |-------------|------------------|
   | `YOUR_GITHUB_PAT` | [GitHub → Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens) (e.g. `repo`, `read:org`) |
   | `YOUR_FIRECRAWL_API_KEY` | [Firecrawl → API keys](https://www.firecrawl.dev/app/api-keys) |
   | `YOUR_OPENAI_API_KEY` | [OpenAI → API keys](https://platform.openai.com/api-keys) (for awesome-cursor-mpc-server) |

`context-mode` and `browser-devtools` require no API key.

If you are editing the file manually, `awesome-cursor-mpc-server` still needs the correct path to `build\index.js`, e.g.:

   `C:\Users\YOUR_USERNAME\.cursor\skills\awesome-cursor-mpc-server\build\index.js`

After setup, restart Cursor. In **Settings → Tools & Integrations → MCP** you should see the enabled servers (green when connected).

---

## 6. Global rules, hooks, and lessons

This setup also installs:

- `%USERPROFILE%\.cursor\hooks.json` with native Cursor hooks for `context-mode`
- `%USERPROFILE%\.cursor\rules\*.mdc` with always-apply rules for:
  - reading `Tasks\Lessons.md` at the start of every session
  - logging corrections and reusable lessons
  - requiring tests, log checks, and a senior-engineer approval check before marking tasks complete
  - preferring `context-mode` when available for large artifacts and long sessions
  - preferring official web UIs or admin dashboards for GUI-managed systems such as FreePBX, GoIP, and Yeastar
  - pausing and asking for guidance when implementation hits decisions not already resolved in the accepted plan
  - reviewing every plan thoroughly and asking unresolved questions as multiple-choice prompts before implementation begins
- `%USERPROFILE%\Tasks\Lessons.md` as the persistent lesson ledger

If `%USERPROFILE%\Tasks\Lessons.md` already exists, `setup.ps1` keeps the existing file instead of overwriting it.
It also refreshes bundled rules and skills on rerun and merges any missing baseline lessons into the existing `Lessons.md`.

---

## 7. What you get

| Category | Contents |
|----------|----------|
| **Skills** | antigravity-awesome-skills, cursor-skills, araguaci-cursor-skills, openskills, awesome-cursorrules, awesome-cursor-rules, awesome-cursor-rules-mdc, bundled `master-voip-engineer`, bundled `deep-thinking-multi-model` |
| **MCP servers** | `browser-devtools`, `context-mode`, GitHub (optional), Firecrawl (optional), Windows-MCP (optional), awesome-cursor-mpc-server (optional, requires OpenAI key) |
| **Global CLI** | vibe-tools, `context-mode` |
| **Global guidance** | bundled Cursor rules, native hooks, persistent `Tasks\Lessons.md`, and repo-sync expectations for future improvements |
| **Dependencies** | Python requirements for `deep-thinking-multi-model` are installed automatically when Python is available |

---

## Quick setup script (optional)

From the repo root (where this README lives), you can run:

```powershell
.\setup.ps1
```

It will create directories, clone the skill repos, copy all bundled repo-local skills into `%USERPROFILE%\.cursor\skills`, install `context-mode`, install the bundled hooks and rules, create `Tasks\Lessons.md` if missing, prompt interactively for MCP/API configuration, install the Python requirements for `deep-thinking-multi-model` when Python is available, build awesome-cursor-mpc-server, and then run an automated post-setup verification step. In the normal path, there is no separate manual MCP/path editing step after the script finishes. Restart Cursor when it completes.

---

## 8. Automated verification

This repo includes `verify-setup.ps1`, which checks the installed Cursor state after setup. It verifies:

- `%USERPROFILE%\.cursor\mcp.json` and `%USERPROFILE%\.cursor\hooks.json` exist and parse as JSON
- required MCP entries like `browser-devtools` and `context-mode` are present
- bundled rules and skills were copied into the expected Cursor directories
- `%USERPROFILE%\Tasks\Lessons.md` exists
- required commands such as `npm`, `npx`, and `context-mode` are available
- optional bundled components such as `awesome-cursor-mpc-server` and `deep-thinking-multi-model` look usable when they are enabled

`setup.ps1` runs this automatically at the end and fails the setup if required checks fail.

You can rerun it manually any time:

```powershell
.\verify-setup.ps1
```

---

## Files in this repo

| File | Purpose |
|------|--------|
| `README.md` | This setup guide |
| `mcp.json.example` | Example MCP config (placeholders only; copy to `~/.cursor/mcp.json` and fill in keys) |
| `hooks.json` | Global Cursor native hooks, including `context-mode` routing |
| `rules/` | Always-apply global Cursor rules copied into `%USERPROFILE%\.cursor\rules` |
| `Tasks/Lessons.md` | Persistent lesson ledger copied to `%USERPROFILE%\Tasks\Lessons.md` if missing |
| `setup.ps1` | Optional script to clone skills and build awesome-cursor-mpc-server |
| `verify-setup.ps1` | Automated post-setup verification for MCP, hooks, rules, skills, lessons, and dependencies |
| `skills/master-voip-engineer/` | Bundled master telecom skill for VoIP troubleshooting and PBX design |
| `deep-thinking-multi-model/` | Bundled multi-model analysis skill copied into Cursor skills during setup |

---

## Troubleshooting

- **MCP servers red / not connecting**  
  Restart Cursor. Ensure JSON in `mcp.json` is valid. For Firecrawl/OpenAI, check the values entered during setup. For Windows-MCP, ensure `uvx` is on PATH. For `context-mode`, confirm `npm install -g context-mode` succeeded and `%USERPROFILE%\.cursor\hooks.json` exists. For `browser-devtools`, confirm `npx` is available.

- **Need a quick health check after setup or later changes**  
  Run `.\verify-setup.ps1` from the repo root. It reports pass, warning, and failure states for the installed Cursor bootstrap.

- **awesome-cursor-mpc-server path**  
  `setup.ps1` now resolves the path automatically from the current `%USERNAME%`. If you edit `mcp.json` manually later, make sure the full path still points to `build\index.js`.

- **GitHub MCP**  
  Requires Cursor v0.48.0+ for Streamable HTTP. Use a PAT with at least `repo` (and `read:org` if you use orgs).

- **deep-thinking-multi-model**  
  The skill is copied into Cursor automatically. To make it fully useful, provide `OPENROUTER_API_KEY` during setup or configure the optional provider-specific keys when prompted. If Python is missing, install Python 3 and rerun the setup script so the requirements can be installed.

- **Secrets**  
  Don't commit real keys. `setup.ps1` prompts for them locally during setup; keep your real `mcp.json` and user environment variables only on your machine.
