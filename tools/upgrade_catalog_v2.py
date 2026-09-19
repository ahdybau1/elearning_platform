#!/usr/bin/env python3
"""Apply the role policy and scientific-speech pipeline to the catalogue."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "implementation" if (ROOT / "implementation").is_dir() else ROOT
CATALOG = PROJECT / "gateway/config/capability_catalog.json"

ADMIN_ONLY = {
    "audio.generate",
    "music.generate",
    "video.generate",
    "video.edit",
}

SCIENTIFIC_SPEECH = {
    "id": "audio.read_scientific_text",
    "label": "Lecture vocale scientifique et mathématique",
    "input_modalities": ["text", "latex", "mathml", "formula"],
    "output_modalities": ["audio", "text", "ssml"],
    "degraded_strategy": [
        "afficher l’expression originale",
        "voix système après verbalisation vérifiée",
        "texte verbalisé sans audio",
    ],
    "allowed_roles": ["student", "admin"],
    "pipeline_stages": [
        "parse_math",
        "verbalize_math",
        "synthesize_speech",
    ],
}

SCIENTIFIC_PROVIDERS = [
    {
        "id": "mathjax_src",
        "name": "MathJax Source",
        "repository": "https://github.com/mathjax/MathJax-src",
        "project_kind": "math-accessibility-runtime",
        "capabilities": ["audio.read_scientific_text"],
        "capability_stages": {
            "audio.read_scientific_text": ["parse_math"],
        },
        "code_license": "Apache-2.0",
        "artifact_license": "same-as-code",
        "commercial_use": "allowed",
        "status": "approved",
        "integration_tier": "core",
        "adapter": "library",
        "execution_targets": ["browser", "desktop", "server_cpu"],
        "minimum_device_tier": "L0",
        "offline": True,
        "requires_gpu": False,
        "mandatory_paid_api": False,
        "card_required": False,
        "default_enabled": True,
        "notes": "Normalise TeX, MathML et AsciiMath; aucun service payant requis.",
    },
    {
        "id": "speech_rule_engine",
        "name": "Speech Rule Engine",
        "repository": "https://github.com/Speech-Rule-Engine/speech-rule-engine",
        "project_kind": "math-verbalization-engine",
        "capabilities": ["audio.read_scientific_text"],
        "capability_stages": {
            "audio.read_scientific_text": ["parse_math", "verbalize_math"],
        },
        "code_license": "Apache-2.0",
        "artifact_license": "same-as-code",
        "commercial_use": "allowed",
        "status": "approved",
        "integration_tier": "core",
        "adapter": "library",
        "execution_targets": ["browser", "desktop", "server_cpu"],
        "minimum_device_tier": "L0",
        "offline": True,
        "requires_gpu": False,
        "mandatory_paid_api": False,
        "card_required": False,
        "default_enabled": True,
        "notes": "Règles sémantiques Mathspeak/Clearspeak, locale française et sortie SSML.",
    },
    {
        "id": "mathcat",
        "name": "MathCAT",
        "repository": "https://github.com/daisy/MathCAT",
        "project_kind": "math-accessibility-engine",
        "capabilities": ["audio.read_scientific_text"],
        "capability_stages": {
            "audio.read_scientific_text": ["parse_math", "verbalize_math"],
        },
        "code_license": "MIT",
        "artifact_license": "same-as-code",
        "commercial_use": "allowed",
        "status": "approved",
        "integration_tier": "optional",
        "adapter": "library",
        "execution_targets": ["desktop", "server_cpu"],
        "minimum_device_tier": "L0",
        "offline": True,
        "requires_gpu": False,
        "mandatory_paid_api": False,
        "card_required": False,
        "default_enabled": False,
        "notes": "Fallback Rust pour MathML, parole, braille et navigation structurée.",
    },
]


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    data["schema_version"] = "2.0.0"

    capabilities = {
        capability["id"]: capability
        for capability in data["capabilities"]
        if capability["id"] != SCIENTIFIC_SPEECH["id"]
    }
    for capability in capabilities.values():
        capability["allowed_roles"] = (
            ["admin"] if capability["id"] in ADMIN_ONLY else ["student", "admin"]
        )
        capability.setdefault("pipeline_stages", [])

    # Static diagrams and 3-D views remain available to students; all actual
    # video generation is routed through the admin-only video.generate contract.
    capabilities["diagram.render"]["output_modalities"] = ["image", "svg"]
    capabilities["3d.render"]["output_modalities"] = ["3d", "image"]

    ordered = list(capabilities.values())
    synth_index = next(
        index
        for index, capability in enumerate(ordered)
        if capability["id"] == "audio.synthesize"
    )
    ordered.insert(synth_index + 1, SCIENTIFIC_SPEECH)
    data["capabilities"] = ordered

    providers = [
        provider
        for provider in data["providers"]
        if provider["id"] not in {item["id"] for item in SCIENTIFIC_PROVIDERS}
    ]
    tts_ids = {"kokoro", "melotts", "piper", "sherpa_onnx"}
    for provider in providers:
        provider.setdefault("capability_stages", {})
        if provider["id"] in tts_ids:
            if "audio.read_scientific_text" not in provider["capabilities"]:
                provider["capabilities"].append("audio.read_scientific_text")
            provider["capability_stages"]["audio.read_scientific_text"] = [
                "synthesize_speech"
            ]

    providers.extend(SCIENTIFIC_PROVIDERS)
    data["providers"] = providers
    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
