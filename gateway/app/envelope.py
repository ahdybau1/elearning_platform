"""Enveloppe standard d'entrée/sortie — §4.1/§4.2 de docs/CAHIER_DES_CHARGES_AGENTS_IA.md, reprise
telle quelle (mêmes noms de champs) plutôt que réinventée.
"""
from typing import Any, Optional
from pydantic import BaseModel, ConfigDict, Field


class Actor(BaseModel):
    account_id: str
    role: str
    scopes: list[str] = Field(default_factory=list)


class AcademicContext(BaseModel):
    country_id: Optional[str] = None
    curriculum_version_id: Optional[str] = None
    class_id: Optional[str] = None
    series_id: Optional[str] = None
    subject_id: Optional[str] = None
    chapter_id: Optional[str] = None
    lesson_id: Optional[str] = None
    skill_ids: list[str] = Field(default_factory=list)


class DeviceContext(BaseModel):
    online: bool = True
    device_tier: str = "unknown"


class EntitlementContext(BaseModel):
    plan_id: Optional[str] = None
    ai_policy_id: Optional[str] = None


class AgentRequest(BaseModel):
    """Enveloppe d'entrée commune (§4.1). `request_id` est généré par la Gateway si absent — le
    client n'a jamais à le fabriquer lui-même."""
    agent_id: str
    profile_id: Optional[str] = None
    academic_context: AcademicContext = Field(default_factory=AcademicContext)
    locale: str = "fr-CM"
    device_context: DeviceContext = Field(default_factory=DeviceContext)
    entitlement_context: EntitlementContext = Field(default_factory=EntitlementContext)
    payload: dict[str, Any] = Field(default_factory=dict)


class SafetyInfo(BaseModel):
    flags: list[str] = Field(default_factory=list)
    human_review_required: bool = False


class UsageInfo(BaseModel):
    route: str  # 'deterministic' | 'cache' | 'device' | 'server'
    compute_units: int = 0


class AgentResponse(BaseModel):
    """Enveloppe de sortie commune (§4.2)."""
    # 'model_version'/'model_policy' déclenchent un avertissement pydantic (namespace "model_"
    # protégé par défaut, pour son propre usage interne) — désactivé, ce ne sont pas des champs
    # pydantic internes ici, juste des noms repris tels quels du cahier.
    model_config = ConfigDict(protected_namespaces=())

    request_id: str
    status: str  # 'success' | 'partial' | 'needs_review' | 'rejected' | 'failed'
    result: dict[str, Any] = Field(default_factory=dict)
    citations: list[dict[str, Any]] = Field(default_factory=list)
    tool_trace_summary: list[dict[str, Any]] = Field(default_factory=list)
    safety: SafetyInfo = Field(default_factory=SafetyInfo)
    usage: UsageInfo
    agent_version: str
    model_version: Optional[str] = None
