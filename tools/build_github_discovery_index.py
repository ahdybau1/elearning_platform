#!/usr/bin/env python3
"""Build a compact, non-executable GitHub discovery index and shortlist."""

from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "implementation" if (ROOT / "implementation").is_dir() else ROOT
SOURCE = ROOT / "tmp/github_ecosystem_candidates.json"
CATALOG = PROJECT / "gateway/config/capability_catalog.json"
INDEX = PROJECT / "gateway/config/github_discovery_index.json"
SHORTLIST = PROJECT / "gateway/config/github_expansion_shortlist.json"

EXCLUDED_OWNERS = {"ahdybau1"}
PERMISSIVE = {
    "Apache-2.0",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "CC0-1.0",
    "ISC",
    "MIT",
    "MIT-0",
    "PostgreSQL",
    "Unlicense",
}
COPYLEFT = {
    "AGPL-3.0",
    "EPL-2.0",
    "EUPL-1.2",
    "GPL-2.0",
    "GPL-3.0",
    "LGPL-2.1",
    "LGPL-3.0",
    "MPL-2.0",
}

SHORTLIST_ENTRIES = {
    "agents_rag": [
        "langchain-ai/langchain",
        "infiniflow/ragflow",
        "browser-use/browser-use",
        "Mintplex-Labs/anything-llm",
        "mem0ai/mem0",
        "crewAIInc/crewAI",
        "HKUDS/LightRAG",
        "microsoft/graphrag",
        "getzep/graphiti",
        "topoteretes/cognee",
        "milvus-io/milvus",
    ],
    "documents_ocr": [
        "ocrmypdf/OCRmyPDF",
        "JaidedAI/EasyOCR",
        "naptha/tesseract.js",
        "hiroi-sora/Umi-OCR",
        "clovaai/donut",
        "deepdoctection/deepdoctection",
    ],
    "speech_audio": [
        "m-bain/whisperX",
        "modelscope/FunASR",
        "PaddlePaddle/PaddleSpeech",
        "speechbrain/speechbrain",
        "pyannote/pyannote-audio",
        "coqui-ai/TTS",
        "myshell-ai/OpenVoice",
        "QwenAudio/CosyVoice",
        "open-mmlab/Amphion",
    ],
    "image_video_vision": [
        "invoke-ai/InvokeAI",
        "AUTOMATIC1111/stable-diffusion-webui",
        "Wan-Video/Wan2.2",
        "HKUDS/ViMax",
        "m87-labs/moondream",
        "Blaizzy/mlx-vlm",
        "deepseek-ai/DeepSeek-VL2",
        "NVlabs/VILA",
    ],
    "translation_math_science": [
        "argosopentech/argos-translate",
        "OpenNMT/CTranslate2",
        "davidedc/Algebrite",
        "asc-community/AngouriMath",
        "flintlib/flint",
        "K-Dense-AI/scientific-agent-skills",
        "gonum/gonum",
        "stdlib-js/stdlib",
    ],
    "evaluation_tools_sandbox": [
        "comet-ml/opik",
        "evidentlyai/evidently",
        "Giskard-AI/giskard-oss",
        "open-compass/VLMEvalKit",
        "judge0/judge0",
        "bytedance/deer-flow",
        "upstash/context7",
        "ChromeDevTools/chrome-devtools-mcp",
    ],
}


def licence_class(spdx: str) -> str:
    if spdx in PERMISSIVE:
        return "permissive"
    if spdx in COPYLEFT:
        return "copyleft-review"
    return "unknown-or-special-review"


def compact(item: dict) -> dict:
    return {
        "full_name": item["full_name"],
        "repository": item["html_url"],
        "license_spdx": item["license_spdx"],
        "license_class": licence_class(item["license_spdx"]),
        "stars_snapshot": item["stars"],
        "archived": item["archived"],
        "pushed_at": item["pushed_at"],
        "families": item["discovery_families"],
        "already_in_registry": item["already_in_registry"],
        "trust_state": "discovery-only",
    }


def main() -> None:
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    registry_urls = {
        provider["repository"].rstrip("/")
        for provider in catalog["providers"]
    }
    candidates = [
        {**item, "already_in_registry": item["html_url"].rstrip("/") in registry_urls}
        for item in source["candidates"]
        if item["full_name"].split("/", 1)[0].casefold() not in EXCLUDED_OWNERS
    ]
    compact_candidates = [compact(item) for item in candidates]
    licences = Counter(item["license_spdx"] for item in candidates)
    families = Counter(
        family
        for item in candidates
        for family in item["discovery_families"]
    )

    index = {
        "schema_version": "1.0.0",
        "generated_at": source["generated_at"],
        "scope": "GitHub repository discovery snapshot; never a runtime allowlist",
        "excluded_owners": sorted(EXCLUDED_OWNERS),
        "method": {
            "search_families": len(source["queries"]),
            "returned_results_before_deduplication": sum(
                query["returned"] for query in source["queries"]
            ),
            "reported_total_matches_across_queries": sum(
                query["total_count"] for query in source["queries"]
            ),
            "limit_per_query": 100,
            "limitations": [
                "GitHub Search returns a ranked snapshot, not every repository.",
                "Repositories can appear in several search families.",
                "Topic and keyword search contains false positives.",
                "Repository licence metadata does not validate model weights, datasets or voices.",
                "No candidate is downloaded or executed from this index.",
            ],
            "queries": source["queries"],
        },
        "statistics": {
            "unique_repositories": len(candidates),
            "outside_runtime_registry": sum(
                not item["already_in_registry"] for item in candidates
            ),
            "archived": sum(item["archived"] for item in candidates),
            "unknown_or_noassertion_licence": sum(
                item["license_spdx"] in {"UNKNOWN", "NOASSERTION"}
                for item in candidates
            ),
            "licences": dict(sorted(licences.items())),
            "families": dict(sorted(families.items())),
        },
        "candidates": compact_candidates,
    }
    INDEX.write_text(
        json.dumps(index, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )

    by_name = {item["full_name"].casefold(): item for item in candidates}
    groups = []
    for category, names in SHORTLIST_ENTRIES.items():
        items = []
        for name in names:
            candidate = by_name.get(name.casefold())
            if candidate is None:
                raise SystemExit(f"shortlist repository missing from snapshot: {name}")
            item = compact(candidate)
            item["review_requirements"] = [
                "verify current repository licence at pinned commit",
                "audit every model, dataset, voice and plugin licence separately",
                "run SBOM, malware, secret, network and prompt-injection checks",
                "benchmark French quality, RAM/VRAM, latency and offline behaviour",
            ]
            items.append(item)
        groups.append({"category": category, "repositories": items})

    shortlist = {
        "schema_version": "1.0.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "decision": (
            "Preliminary expansion shortlist only. Every entry remains disabled "
            "until a pinned-version licence, security and benchmark review passes."
        ),
        "groups": groups,
    }
    SHORTLIST.write_text(
        json.dumps(shortlist, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"index: {len(candidates)} repositories; "
        f"shortlist: {sum(len(group['repositories']) for group in groups)}"
    )


if __name__ == "__main__":
    main()
