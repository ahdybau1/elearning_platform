#!/usr/bin/env python3
"""Fail fast when the checked-in PQ capability catalogue is unsafe or invalid."""
from collections import Counter

from app.capabilities.registry import CapabilityRegistry


def main() -> None:
    registry = CapabilityRegistry()
    providers = registry.catalog.providers

    if registry.catalog.policy.mandatory_cost_eur != 0:
        raise SystemExit("mandatory_cost_eur must stay at 0")
    if registry.catalog.policy.paid_api_allowed:
        raise SystemExit("paid APIs must stay disabled")
    if registry.catalog.policy.payment_card_allowed:
        raise SystemExit("payment cards must stay disabled")

    for provider in providers:
        if provider.mandatory_paid_api or provider.card_required:
            raise SystemExit(f"{provider.id}: paid API/card dependency is forbidden")
        if provider.default_enabled and provider.commercial_use != "allowed":
            raise SystemExit(f"{provider.id}: default provider is not commercially cleared")

    missing = [
        capability.id
        for capability in registry.catalog.capabilities
        if not any(capability.id in p.capabilities for p in providers)
    ]
    if missing:
        raise SystemExit(f"Capabilities without providers: {', '.join(missing)}")

    admin_only = {
        "audio.generate",
        "music.generate",
        "video.generate",
        "video.edit",
    }
    capabilities = {item.id: item for item in registry.catalog.capabilities}
    for capability_id in admin_only:
        if capabilities[capability_id].allowed_roles != ["admin"]:
            raise SystemExit(f"{capability_id}: must remain admin-only")

    speech = capabilities["audio.read_scientific_text"]
    expected_stages = {"parse_math", "verbalize_math", "synthesize_speech"}
    covered_stages = {
        stage
        for provider in providers
        if speech.id in provider.capabilities and provider.status == "approved"
        for stage in provider.capability_stages.get(speech.id, [])
    }
    if expected_stages - covered_stages:
        raise SystemExit(
            "scientific speech is incomplete: "
            + ", ".join(sorted(expected_stages - covered_stages))
        )

    statuses = Counter(provider.status for provider in providers)
    print(
        "catalogue valide: "
        f"{len(registry.catalog.capabilities)} capacités, "
        f"{len(providers)} providers, "
        + ", ".join(f"{key}={statuses[key]}" for key in sorted(statuses))
    )


if __name__ == "__main__":
    main()
