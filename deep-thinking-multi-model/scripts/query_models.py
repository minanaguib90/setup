#!/usr/bin/env python3
"""
Multi-Model Deep Thinking Agent
================================
Queries GPT, Claude Opus, and Kimi K2 in parallel, then merges their responses
into a single comprehensive answer.

Supports two modes:
  - OpenRouter (recommended): Single OPENROUTER_API_KEY for all models
  - Direct APIs: Individual keys (OPENAI_API_KEY, ANTHROPIC_API_KEY, KIMI_API_KEY)
"""

import os
import sys
import json
import argparse
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    import requests
except ImportError:
    print("ERROR: 'requests' package is required. Install with: pip install requests")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Configuration -- override via environment variables
# ---------------------------------------------------------------------------
OPENROUTER_BASE = "https://openrouter.ai/api/v1/chat/completions"

MODEL_CONFIG = {
    "gpt": {
        "label": "GPT",
        "openrouter_id": os.environ.get("DEEP_THINK_GPT_MODEL", "openai/gpt-4o"),
        "direct_model": os.environ.get("DEEP_THINK_GPT_MODEL_DIRECT", "gpt-4o"),
        "direct_url": "https://api.openai.com/v1/chat/completions",
        "env_key": "OPENAI_API_KEY",
        "api_style": "openai",
    },
    "opus": {
        "label": "Claude Opus",
        "openrouter_id": os.environ.get("DEEP_THINK_OPUS_MODEL", "anthropic/claude-3-opus"),
        "direct_model": os.environ.get("DEEP_THINK_OPUS_MODEL_DIRECT", "claude-3-opus-20240229"),
        "direct_url": "https://api.anthropic.com/v1/messages",
        "env_key": "ANTHROPIC_API_KEY",
        "api_style": "anthropic",
    },
    "kimi": {
        "label": "Kimi K2",
        "openrouter_id": os.environ.get("DEEP_THINK_KIMI_MODEL", "moonshotai/kimi-k2"),
        "direct_model": os.environ.get("DEEP_THINK_KIMI_MODEL_DIRECT", "kimi-k2"),
        "direct_url": "https://api.moonshot.cn/v1/chat/completions",
        "env_key": "KIMI_API_KEY",
        "api_style": "openai",  # Moonshot uses OpenAI-compatible API
    },
}

MERGE_MODEL_OPENROUTER = os.environ.get("DEEP_THINK_MERGE_MODEL", "openai/gpt-4o")
REQUEST_TIMEOUT = int(os.environ.get("DEEP_THINK_TIMEOUT", "180"))
MAX_TOKENS = int(os.environ.get("DEEP_THINK_MAX_TOKENS", "4096"))

# ---------------------------------------------------------------------------
# API Query Functions
# ---------------------------------------------------------------------------

def _query_openai_style(url: str, model: str, api_key: str, prompt: str) -> str:
    """Query an OpenAI-compatible API endpoint."""
    resp = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        json={
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.7,
            "max_tokens": MAX_TOKENS,
        },
        timeout=REQUEST_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"]


def _query_anthropic_style(url: str, model: str, api_key: str, prompt: str) -> str:
    """Query the Anthropic Messages API."""
    resp = requests.post(
        url,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        },
        json={
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.7,
            "max_tokens": MAX_TOKENS,
        },
        timeout=REQUEST_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()["content"][0]["text"]


def get_available_models() -> list:
    """Return list of model names that have API keys configured."""
    openrouter_key = os.environ.get("OPENROUTER_API_KEY")
    if openrouter_key:
        return list(MODEL_CONFIG.keys())  # All models available via OpenRouter

    available = []
    for name, cfg in MODEL_CONFIG.items():
        if os.environ.get(cfg["env_key"]):
            available.append(name)
    return available


def query_model(name: str, prompt: str) -> tuple:
    """
    Query a single model. Returns (name, response_text, elapsed_seconds).
    Prefers OpenRouter if OPENROUTER_API_KEY is set; otherwise uses direct API.
    """
    cfg = MODEL_CONFIG[name]
    openrouter_key = os.environ.get("OPENROUTER_API_KEY")
    start = time.time()

    try:
        if openrouter_key:
            result = _query_openai_style(
                OPENROUTER_BASE, cfg["openrouter_id"], openrouter_key, prompt
            )
        else:
            direct_key = os.environ.get(cfg["env_key"])
            if not direct_key:
                return (name, None, 0)  # Skipped -- no key

            if cfg["api_style"] == "anthropic":
                result = _query_anthropic_style(
                    cfg["direct_url"], cfg["direct_model"], direct_key, prompt
                )
            else:
                result = _query_openai_style(
                    cfg["direct_url"], cfg["direct_model"], direct_key, prompt
                )

        elapsed = round(time.time() - start, 1)
        return (name, result, elapsed)

    except requests.exceptions.HTTPError as e:
        elapsed = round(time.time() - start, 1)
        body = ""
        try:
            body = e.response.text[:500]
        except Exception:
            pass
        return (name, f"[HTTP ERROR {e.response.status_code}] {body}", elapsed)
    except Exception as e:
        elapsed = round(time.time() - start, 1)
        return (name, f"[ERROR] {type(e).__name__}: {e}", elapsed)


def merge_responses(prompt: str, responses: dict) -> str:
    """Use a model to synthesize available responses into one merged answer."""
    successful = {k: v for k, v in responses.items() if v and not v.startswith("[ERROR") and not v.startswith("[HTTP ERROR")}

    if len(successful) == 0:
        return "[ERROR] No successful model responses to merge."
    if len(successful) == 1:
        only_name = list(successful.keys())[0]
        return f"(Only one model responded -- returning {MODEL_CONFIG[only_name]['label']}'s answer as-is)\n\n{successful[only_name]}"

    model_count = len(successful)
    answer_sections = []
    for name, text in successful.items():
        label = MODEL_CONFIG[name]["label"]
        answer_sections.append(f"--- {label}'s ANSWER ---\n{text}")
    answers_block = "\n\n".join(answer_sections)

    merge_prompt = f"""You are an expert synthesizer tasked with merging answers from {model_count} AI models into one definitive response.

ORIGINAL QUESTION/TASK:
{prompt}

{answers_block}

INSTRUCTIONS:
1. Create a single comprehensive answer that combines the best insights from all responding models.
2. Where the models agree, state the consensus confidently.
3. Where they disagree, note the different perspectives and provide your reasoned judgment.
4. Preserve unique valuable points that only one model raised.
5. Use clear structure with headings if the answer is long.
6. Do NOT mention the models by name or say "Model X said...". Write as a unified answer.
7. Provide the merged answer directly -- no preamble or meta-commentary."""

    openrouter_key = os.environ.get("OPENROUTER_API_KEY")

    try:
        if openrouter_key:
            return _query_openai_style(
                OPENROUTER_BASE, MERGE_MODEL_OPENROUTER, openrouter_key, merge_prompt
            )
        else:
            for name, style, url, model_key in [
                ("gpt", "openai", "https://api.openai.com/v1/chat/completions", "gpt-4o"),
                ("opus", "anthropic", "https://api.anthropic.com/v1/messages", "claude-3-opus-20240229"),
                ("kimi", "openai", "https://api.moonshot.cn/v1/chat/completions", "kimi-k2"),
            ]:
                key = os.environ.get(MODEL_CONFIG[name]["env_key"])
                if key:
                    if style == "anthropic":
                        return _query_anthropic_style(url, model_key, key, merge_prompt)
                    else:
                        return _query_openai_style(url, model_key, key, merge_prompt)

            return "[ERROR] No API key available for the merge step."

    except Exception as e:
        return f"[ERROR merging responses] {type(e).__name__}: {e}"


# ---------------------------------------------------------------------------
# Output Formatting
# ---------------------------------------------------------------------------

def format_output(prompt: str, responses: dict, timings: dict, merged: str) -> str:
    """Format all results into a readable report."""
    SEP = "=" * 72
    THIN = "-" * 72
    lines = []

    lines.append(SEP)
    lines.append("  MULTI-MODEL DEEP THINKING ANALYSIS")
    lines.append(SEP)
    lines.append("")

    for key in ["gpt", "opus", "kimi"]:
        if key not in responses:
            continue
        cfg = MODEL_CONFIG[key]
        t = timings.get(key, 0)
        lines.append(THIN)
        lines.append(f"  {cfg['label']}  ({t}s)")
        lines.append(THIN)
        lines.append("")
        lines.append(responses[key])
        lines.append("")

    lines.append(SEP)
    lines.append("  MERGED FINAL ANSWER")
    lines.append(SEP)
    lines.append("")
    lines.append(merged)
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Query GPT, Claude Opus, and Kimi K2 in parallel, then merge."
    )
    parser.add_argument("prompt", nargs="?", help="The question or task to analyze")
    parser.add_argument("--file", "-f", help="Read prompt from a file")
    parser.add_argument("--json", "-j", help="Write structured JSON output to this path")
    args = parser.parse_args()

    # Resolve prompt
    if args.file:
        with open(args.file, encoding="utf-8") as fh:
            prompt = fh.read().strip()
    elif args.prompt:
        prompt = args.prompt
    elif not sys.stdin.isatty():
        prompt = sys.stdin.read().strip()
    else:
        print("Usage: python query_models.py \"Your question here\"")
        print("       python query_models.py --file question.txt")
        print("       echo \"Your question\" | python query_models.py")
        sys.exit(1)

    if not prompt:
        print("ERROR: Prompt is empty.")
        sys.exit(1)

    # Determine which models are available
    available = get_available_models()
    if not available:
        print("ERROR: No API keys configured.")
        print("Set OPENROUTER_API_KEY (recommended) or individual keys:")
        for c in MODEL_CONFIG.values():
            print(f"  - {c['env_key']}")
        sys.exit(1)

    all_models = list(MODEL_CONFIG.keys())
    skipped = [m for m in all_models if m not in available]

    print(f"Models available: {', '.join(MODEL_CONFIG[m]['label'] for m in available)}")
    if skipped:
        print(f"Models skipped (no API key): {', '.join(MODEL_CONFIG[m]['label'] for m in skipped)}")
    print(f"\nQuerying {len(available)} model(s) in parallel...\n")

    # Query available models in parallel
    responses = {}
    timings = {}
    with ThreadPoolExecutor(max_workers=len(available)) as executor:
        futures = {
            executor.submit(query_model, name, prompt): name
            for name in available
        }
        for future in as_completed(futures):
            name, result, elapsed = future.result()
            if result is None:
                continue  # Skipped
            responses[name] = result
            timings[name] = elapsed
            label = MODEL_CONFIG[name]["label"]
            is_err = result.startswith("[ERROR") or result.startswith("[HTTP ERROR")
            status = "x" if is_err else "+"
            print(f"  [{status}] {label} responded in {elapsed}s ({len(result)} chars)")

    if not responses:
        print("\nERROR: No models returned a response.")
        sys.exit(1)

    # Merge (only if more than one successful response)
    successful = {k: v for k, v in responses.items() if v and not v.startswith("[ERROR") and not v.startswith("[HTTP ERROR")}
    if len(successful) > 1:
        print(f"\nMerging {len(successful)} responses...\n")
    else:
        print()
    merged = merge_responses(prompt, responses)

    # Print formatted output
    print(format_output(prompt, responses, timings, merged))

    # Optional JSON export
    if args.json:
        output_data = {
            "prompt": prompt,
            "responses": {
                name: {"text": text, "time_seconds": timings.get(name, 0)}
                for name, text in responses.items()
            },
            "merged": merged,
        }
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(output_data, fh, indent=2, ensure_ascii=False)
        print(f"JSON output saved to: {args.json}")


if __name__ == "__main__":
    main()
