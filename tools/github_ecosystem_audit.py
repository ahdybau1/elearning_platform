#!/usr/bin/env python3
"""Search GitHub systematically and build a deduplicated candidate snapshot.

This discovery inventory is intentionally separate from the approved runtime
catalogue. Search results are candidates, never automatically trusted or run.
"""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "implementation" if (ROOT / "implementation").is_dir() else ROOT
CATALOG = PROJECT / "gateway/config/capability_catalog.json"
OUTPUT = ROOT / "tmp/github_ecosystem_candidates.json"
EXCLUDED_OWNERS = {"ahdybau1"}

BATCHES = {
    1: [
        ("local_llm", "topic:local-llm stars:>50"),
        ("multimodal", "topic:multimodal-ai stars:>50"),
        ("document_ai", "topic:document-ai stars:>20"),
        ("ocr", "topic:ocr stars:>100"),
        ("tts", "topic:text-to-speech stars:>100"),
        ("asr", "topic:speech-recognition stars:>100"),
        ("image_generation", "topic:image-generation stars:>100"),
        ("video_generation", "topic:video-generation stars:>50"),
        ("music_generation", "topic:music-generation stars:>50"),
        ("agents", "topic:ai-agents stars:>100"),
    ],
    2: [
        ("mcp", "topic:mcp-server stars:>30"),
        ("rag", "topic:rag stars:>100"),
        ("vector", "topic:vector-database stars:>100"),
        ("science", "topic:scientific-computing stars:>100"),
        ("math", "topic:computer-algebra stars:>20"),
        ("audio_generation", "topic:audio-generation stars:>30"),
        ("voice", "topic:voice-cloning stars:>100"),
        ("pdf", "topic:pdf-extraction stars:>20"),
        ("local_api", '"OpenAI-compatible" local AI server stars:>100'),
        ("translation", "topic:machine-translation stars:>100"),
    ],
    3: [
        ("vision_language", '"vision language model" stars:>100'),
        ("image_edit", '"image editing" diffusion stars:>100'),
        ("video_understanding", '"video understanding" AI stars:>50'),
        ("diarization", "topic:speaker-diarization stars:>50"),
        ("tts_multilingual", 'multilingual TTS open-source stars:>100'),
        ("document_parser", 'document parser OCR PDF AI stars:>100'),
        ("sandbox", 'code sandbox open-source stars:>100'),
        ("evaluation", 'LLM evaluation open-source stars:>100'),
        ("workflow", 'AI workflow orchestration open-source stars:>100'),
        ("webgpu", 'WebGPU AI inference stars:>100'),
    ],
}

EXCLUDED_NAME_PARTS = (
    "awesome-",
    "-awesome",
    "roadmap",
    "interview",
    "tutorial",
    "course",
    "papers",
    "paper-list",
)


def github_search(query: str) -> dict:
    url = "https://api.github.com/search/repositories?" + urlencode(
        {"q": query, "sort": "stars", "order": "desc", "per_page": 100}
    )
    request = Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "pq-ai-fabric-audit/1.0",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def normalized_item(item: dict, family: str, query: str) -> dict:
    license_data = item.get("license") or {}
    return {
        "full_name": item["full_name"],
        "html_url": item["html_url"],
        "description": item.get("description") or "",
        "license_spdx": license_data.get("spdx_id") or "UNKNOWN",
        "stars": item.get("stargazers_count", 0),
        "forks": item.get("forks_count", 0),
        "archived": bool(item.get("archived")),
        "fork": bool(item.get("fork")),
        "updated_at": item.get("updated_at"),
        "pushed_at": item.get("pushed_at"),
        "default_branch": item.get("default_branch"),
        "language": item.get("language"),
        "topics": item.get("topics") or [],
        "discovery_families": [family],
        "discovery_queries": [query],
    }


def should_keep(item: dict) -> bool:
    name = item["full_name"].casefold()
    if name.split("/", 1)[0] in EXCLUDED_OWNERS:
        return False
    if item.get("fork"):
        return False
    if any(part in name for part in EXCLUDED_NAME_PARTS):
        return False
    return True


def merge_item(existing: dict, new: dict) -> dict:
    existing["discovery_families"] = sorted(
        set(existing["discovery_families"] + new["discovery_families"])
    )
    existing["discovery_queries"] = sorted(
        set(existing["discovery_queries"] + new["discovery_queries"])
    )
    return existing


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=int, choices=sorted(BATCHES), required=True)
    args = parser.parse_args()

    approved = json.loads(CATALOG.read_text(encoding="utf-8"))
    existing_urls = {p["repository"].rstrip("/") for p in approved["providers"]}
    state = (
        json.loads(OUTPUT.read_text(encoding="utf-8"))
        if OUTPUT.exists()
        else {"searched_batches": [], "queries": [], "candidates": []}
    )
    by_name = {item["full_name"].casefold(): item for item in state["candidates"]}

    for index, (family, query) in enumerate(BATCHES[args.batch], start=1):
        payload = github_search(query)
        state["queries"].append(
            {
                "batch": args.batch,
                "family": family,
                "query": query,
                "total_count": payload.get("total_count", 0),
                "returned": len(payload.get("items", [])),
            }
        )
        for raw in payload.get("items", []):
            item = normalized_item(raw, family, query)
            if not should_keep(item):
                continue
            key = item["full_name"].casefold()
            if key in by_name:
                by_name[key] = merge_item(by_name[key], item)
            else:
                by_name[key] = item
        print(f"[{index:02d}/10] {family}: {len(payload.get('items', []))} résultats")

    state["searched_batches"] = sorted(set(state["searched_batches"] + [args.batch]))
    candidates = list(by_name.values())
    for item in candidates:
        item["already_in_registry"] = item["html_url"].rstrip("/") in existing_urls
    candidates.sort(key=lambda item: (-item["stars"], item["full_name"].casefold()))
    state["candidates"] = candidates
    state["generated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    new_count = sum(not item["already_in_registry"] for item in candidates)
    print(f"snapshot: {len(candidates)} uniques, {new_count} hors registre actuel")


if __name__ == "__main__":
    main()
