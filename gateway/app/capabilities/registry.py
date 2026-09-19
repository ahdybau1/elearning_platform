"""Catalogue loader and deterministic zero-cost capability planner."""
from functools import lru_cache
import json
from pathlib import Path

from .models import (
    CapabilityCatalog,
    CapabilityPlan,
    CapabilityPlanRequest,
    ProviderDecision,
    ProviderDefinition,
)

_TIER_RANK = {"L0": 0, "L1": 1, "L2": 2, "L3": 3}
_TIER_PRIORITY = {"core": 0, "optional": 1, "experimental": 2, "rejected": 3}


class CapabilityRegistryError(ValueError):
    """Raised when the checked-in catalogue is inconsistent."""


class CapabilityRegistry:
    def __init__(self, catalog_path: Path | None = None) -> None:
        self.catalog_path = catalog_path or (
            Path(__file__).resolve().parents[2] / "config" / "capability_catalog.json"
        )
        raw = json.loads(self.catalog_path.read_text(encoding="utf-8"))
        self.catalog = CapabilityCatalog.model_validate(raw)
        self._capabilities = {item.id: item for item in self.catalog.capabilities}
        self._providers = {item.id: item for item in self.catalog.providers}
        self._validate_uniqueness()

    def _validate_uniqueness(self) -> None:
        if len(self._capabilities) != len(self.catalog.capabilities):
            raise CapabilityRegistryError("Duplicate capability id")
        if len(self._providers) != len(self.catalog.providers):
            raise CapabilityRegistryError("Duplicate provider id")
        known = set(self._capabilities)
        for provider in self.catalog.providers:
            unknown = set(provider.capabilities) - known
            if unknown:
                raise CapabilityRegistryError(
                    f"Provider {provider.id} references unknown capabilities: {sorted(unknown)}"
                )

    def list_capabilities(self) -> list[dict]:
        result = []
        for capability in self.catalog.capabilities:
            providers = [
                provider for provider in self.catalog.providers
                if capability.id in provider.capabilities
            ]
            result.append({
                **capability.model_dump(),
                "provider_count": len(providers),
                "approved_provider_count": sum(p.status == "approved" for p in providers),
            })
        return result

    def get_capability(self, capability_id: str) -> dict | None:
        capability = self._capabilities.get(capability_id)
        if capability is None:
            return None
        providers = [
            provider.model_dump(mode="json")
            for provider in self.catalog.providers
            if capability_id in provider.capabilities
        ]
        return {**capability.model_dump(), "providers": providers}

    def _decide(
        self,
        provider: ProviderDefinition,
        request: CapabilityPlanRequest,
    ) -> ProviderDecision:
        reasons: list[str] = []
        policy = self.catalog.policy

        if provider.status in ("blocked", "watch"):
            reasons.append(f"status:{provider.status}")
        if provider.integration_tier == "rejected":
            reasons.append("integration:rejected")
        if provider.mandatory_paid_api or provider.card_required:
            reasons.append("zero-cost:paid-or-card-required")
        if not policy.paid_api_allowed and provider.mandatory_paid_api:
            reasons.append("policy:paid-api-disabled")
        if not policy.payment_card_allowed and provider.card_required:
            reasons.append("policy:payment-card-disabled")
        if request.commercial_use:
            if provider.commercial_use == "blocked":
                reasons.append("license:commercial-use-blocked")
            elif provider.commercial_use in ("conditional", "review") and not request.allow_conditional_licenses:
                reasons.append("license:review-required")
        if not request.online and not provider.offline:
            reasons.append("runtime:online-required")
        if provider.requires_gpu and not request.allow_gpu:
            reasons.append("hardware:gpu-unavailable")
        if _TIER_RANK[request.device_tier] < _TIER_RANK[provider.minimum_device_tier]:
            reasons.append(f"hardware:requires-{provider.minimum_device_tier}")
        if not set(request.available_targets).intersection(provider.execution_targets):
            reasons.append("runtime:no-compatible-target")

        return ProviderDecision(
            provider_id=provider.id,
            name=provider.name,
            eligible=not reasons,
            reasons=reasons,
            adapter=provider.adapter,
            execution_targets=provider.execution_targets,
        )

    def plan(self, request: CapabilityPlanRequest) -> CapabilityPlan:
        capability = self._capabilities.get(request.capability_id)
        if capability is None:
            raise CapabilityRegistryError(f"Unknown capability: {request.capability_id}")

        provider_defs = [
            provider for provider in self.catalog.providers
            if request.capability_id in provider.capabilities
        ]
        decisions = [(provider, self._decide(provider, request)) for provider in provider_defs]
        decisions.sort(key=lambda item: (
            not item[1].eligible,
            _TIER_PRIORITY[item[0].integration_tier],
            not item[0].default_enabled,
            item[0].requires_gpu,
            item[0].name.casefold(),
        ))
        return CapabilityPlan(
            capability_id=request.capability_id,
            eligible=[decision for _, decision in decisions if decision.eligible],
            rejected=[decision for _, decision in decisions if not decision.eligible],
            degraded_strategy=capability.degraded_strategy,
        )


@lru_cache(maxsize=1)
def get_capability_registry() -> CapabilityRegistry:
    return CapabilityRegistry()

