---
name: deep-thinking-multi-model
description: Performs deep analysis by querying GPT, Claude Opus, and Kimi K2 in parallel, returning each model's answer and a merged final response. Use when the user requests deep thinking, multi-model analysis, consensus answers, or wants multiple AI perspectives on a complex problem.
---

# Deep Thinking Multi-Model Analysis

Queries three frontier AI models (GPT, Claude Opus, Kimi K2) in parallel via a Python script, then merges their outputs into one comprehensive answer.

## When to Use

- User explicitly asks for "deep thinking" or "multi-model" analysis
- Complex problems that benefit from multiple perspectives
- User wants consensus or cross-validated answers
- Tasks where thoroughness and accuracy are critical

## Prerequisites

The script requires:
- Python 3.9+
- `requests` package (`pip install requests`)
- At least one API key configured (see [setup.md](setup.md))

**Recommended**: A single `OPENROUTER_API_KEY` environment variable gives access to all three models.

## Workflow

### Step 1: Prepare the prompt

Take the user's question or task and formulate a clear, detailed prompt. If the task is complex, expand it with context so each model gets the full picture.

### Step 2: Write the prompt to a temp file

Write the prompt to a temporary file to handle multi-line content and special characters:

```bash
python -c "import tempfile; f=tempfile.NamedTemporaryFile(mode='w',suffix='.txt',delete=False,encoding='utf-8'); f.write(PROMPT_TEXT); print(f.name); f.close()"
```

### Step 3: Run the script

```bash
python ~/.cursor/skills/deep-thinking-multi-model/scripts/query_models.py --file <temp_file_path>
```

Or for short single-line prompts:

```bash
python ~/.cursor/skills/deep-thinking-multi-model/scripts/query_models.py "Your question here"
```

The script:
1. Sends the prompt to GPT, Claude Opus, and Kimi K2 **in parallel**
2. Collects all three responses
3. Uses a model to **merge** the three answers into one unified response
4. Prints all four outputs (3 individual + 1 merged)

**Timeout**: Default 180 seconds per model. Override with `DEEP_THINK_TIMEOUT` env var.

### Step 4: Present results to the user

Display the output in this format:

---

**GPT's Response:**
> (paste GPT's answer)

**Claude Opus's Response:**
> (paste Opus's answer)

**Kimi K2's Response:**
> (paste Kimi's answer)

---

**Merged Final Answer:**
> (paste the merged answer)

---

### Optional: JSON export

For structured output, add `--json output.json`:

```bash
python ~/.cursor/skills/deep-thinking-multi-model/scripts/query_models.py --file prompt.txt --json result.json
```

## Error Handling

- If a model fails, the script still returns results from the other models
- Error responses are prefixed with `[ERROR]` or `[HTTP ERROR]`
- If all models fail, check API key configuration (see [setup.md](setup.md))
- If the merge step fails, present the three individual answers without a merge

## Customizing Models

Override default model selections via environment variables:

| Variable | Default | Purpose |
|----------|---------|----------|
| `DEEP_THINK_GPT_MODEL` | `openai/gpt-4o` | OpenRouter model ID for GPT |
| `DEEP_THINK_OPUS_MODEL` | `anthropic/claude-3-opus` | OpenRouter model ID for Opus |
| `DEEP_THINK_KIMI_MODEL` | `moonshotai/kimi-k2` | OpenRouter model ID for Kimi |
| `DEEP_THINK_MERGE_MODEL` | `openai/gpt-4o` | Model used for merging |
| `DEEP_THINK_MAX_TOKENS` | `4096` | Max tokens per response |
| `DEEP_THINK_TIMEOUT` | `180` | Request timeout in seconds |

## Additional Resources

- For setup and API key configuration, see [setup.md](setup.md)
