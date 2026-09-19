"""Typed contracts for the PQ Open Capability Registry.

The catalogue separates source-code licensing from model/checkpoint licensing.
A GitHub repository being open source never proves that every downloadable
weight can be used commercially.
"""
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, HttpUrl, model_validator

CommercialUse = Literal["allowed", "conditional", "blocked", "review"]
ProviderStatus = Literal["approved", "conditional", "watch", "blocked"]
IntegrationTier = Literal["core", "optional", "experimental", "rejected"]
AdapterKind = Literal[
    "library",
    "native_python",
    "openai_compatible_http",
    "ollama_http",
    "comfyui_http",
    "mcp",
    "cli_sidecar",
    "wasm",
]
ExecutionTarget = Literal[
    "browser",
    "android",
    "ios",
    "desktop",
    "server_cpu",
    "server_gpu",
]
DeviceTier = Literal["L0", "L1", "L2", "L3"]
ActorRole = Literal["student", "admin"]


class ZeroCostPolicy(BaseModel):
    mandatory_cost_eur: int = 0
    paid_api_allowed: bool = False
    payment_card_allowed: bool = False
    paid_trial_as_dependency: bool = False
    external_free_tier_critical: bool = False


class CapabilityDefinition(BaseModel):
    id: str
    label: str
    input_modalities: list[str]
    output_modalities: list[str]
    degraded_strategy: list[str] = Field(default_factory=list)
    allowed_roles: list[ActorRole] = Field(
        default_factory=lambda: ["student", "admin"]
    )
    pipeline_stages: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def enforce_role_and_pipeline_metadata(self) -> "CapabilityDefinition":
        if not self.allowed_roles:
            raise ValueError("A capability must allow at least one authenticated role")
        if len(self.allowed_roles) != len(set(self.allowed_roles)):
            raise ValueError("Duplicate capability role")
        if len(self.pipeline_stages) != len(set(self.pipeline_stages)):
            raise ValueError("Duplicate capability pipeline stage")
        return self


class ProviderDefinition(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    name: str
    repository: HttpUrl
    project_kind: str
    capabilities: list[str]
    capability_stages: dict[str, list[str]] = Field(default_factory=dict)
    code_license: str
    artifact_license: str
    commercial_use: CommercialUse
    status: ProviderStatus
    integration_tier: IntegrationTier
    adapter: AdapterKind
    execution_targets: list[ExecutionTarget]
    minimum_device_tier: DeviceTier = "L0"
    offline: bool
    requires_gpu: bool
    mandatory_paid_api: bool = False
    card_required: bool = False
    default_enabled: bool = False
    notes: str = ""

    @model_validator(mode="after")
    def enforce_zero_cost_metadata(self) -> "ProviderDefinition":
        if self.integration_tier == "core" and self.status in ("watch", "blocked"):
            raise ValueError("A core provider cannot be watch-only or blocked")
        if self.default_enabled and self.status != "approved":
            raise ValueError("Only approved providers may be enabled by default")
        return self


class CapabilityCatalog(BaseModel):
    schema_version: str
    reviewed_at: str
    policy: ZeroCostPolicy
    capabilities: list[CapabilityDefinition]
    providers: list[ProviderDefinition]


class CapabilityPlanRequest(BaseModel):
    capability_id: str
    available_targets: list[ExecutionTarget]
    device_tier: DeviceTier = "L0"
    online: bool = True
    commercial_use: bool = True
    allow_conditional_licenses: bool = False
    allow_gpu: bool = False


class ProviderDecision(BaseModel):
    provider_id: str
    name: str
    eligible: bool
    reasons: list[str] = Field(default_factory=list)
    adapter: AdapterKind
    execution_targets: list[ExecutionTarget]
    stages: list[str] = Field(default_factory=list)


class CapabilityPlan(BaseModel):
    capability_id: str
    eligible: list[ProviderDecision]
    rejected: list[ProviderDecision]
    degraded_strategy: list[str]
    uncovered_stages: list[str] = Field(default_factory=list)
    zero_cost_enforced: bool = True
