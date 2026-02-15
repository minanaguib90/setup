# Setup Guide -- Deep Thinking Multi-Model

## Option A: OpenRouter (Recommended)

One API key gives access to GPT, Claude Opus, and Kimi K2 through a single endpoint.

1. **Get an API key**: Sign up at [openrouter.ai](https://openrouter.ai/) and create an API key
2. **Add credits**: Add a small amount of credit (the three queries + merge typically cost $0.05-0.30 per run depending on prompt/response length)
3. **Set the environment variable**:

**Windows (permanent -- run in PowerShell as Administrator):**
```powershell
[System.Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", "sk-or-v1-your-key-here", "User")
```

**Windows (current session only):**
```powershell
$env:OPENROUTER_API_KEY = "sk-or-v1-your-key-here"
```

**Linux / macOS (add to ~/.bashrc or ~/.zshrc):**
```bash
export OPENROUTER_API_KEY="sk-or-v1-your-key-here"
```

4. **Restart Cursor** after setting permanent environment variables

## Option B: Individual API Keys

Use separate keys from each provider. You only need keys for the models you want to query.

| Provider | Env Variable | Sign Up |
|----------|-------------|----------|
| OpenAI (GPT) | `OPENAI_API_KEY` | [platform.openai.com](https://platform.openai.com/) |
| Anthropic (Opus) | `ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com/) |
| Moonshot (Kimi K2) | `KIMI_API_KEY` | [platform.moonshot.cn](https://platform.moonshot.cn/) |

Set each key the same way as shown in Option A.

## Install Python Dependency

```bash
pip install requests
```

Or using the requirements file:

```bash
pip install -r ~/.cursor/skills/deep-thinking-multi-model/scripts/requirements.txt
```

## Verify Setup

Run a quick test:

```bash
python ~/.cursor/skills/deep-thinking-multi-model/scripts/query_models.py "What is 2+2? Reply in one sentence."
```

You should see responses from all three models plus a merged answer.

## Customizing Models

If you want to use different model versions (e.g., a newer GPT or Opus release), set these environment variables:

```powershell
# OpenRouter model IDs (see https://openrouter.ai/models)
$env:DEEP_THINK_GPT_MODEL = "openai/gpt-4o"
$env:DEEP_THINK_OPUS_MODEL = "anthropic/claude-3-opus"
$env:DEEP_THINK_KIMI_MODEL = "moonshotai/kimi-k2"

# Model used to merge the three answers
$env:DEEP_THINK_MERGE_MODEL = "openai/gpt-4o"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `ERROR: No API keys configured` | Set `OPENROUTER_API_KEY` or individual provider keys |
| `HTTP ERROR 401` | API key is invalid or expired -- regenerate it |
| `HTTP ERROR 402` | Insufficient credits -- add funds to your account |
| `HTTP ERROR 429` | Rate limited -- wait a moment and try again |
| `requests` not found | Run `pip install requests` |
| Timeout errors | Increase timeout: `$env:DEEP_THINK_TIMEOUT = "300"` |
| Wrong model version | Override with `DEEP_THINK_*_MODEL` env vars (see above) |
