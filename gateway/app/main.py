"""Sovereign AI Gateway (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §3).

IA-002 (Gateway minimale) + IA-003 (Tool Gateway) + IA-004 (RAG) + IA-005 (Model Router) faits, dans
cet ordre. PAS encore d'Agent Orchestrator (LangGraph) ni de modèle auto-hébergé (vLLM/Ollama) — la
Gateway route aujourd'hui vers les Edge Functions Deno réellement déployées (via le registre IA-001),
elle ne les remplace pas.

Lancer en local ("machine développeur", légitime en Compute Fabric — §U6 du cahier) :
    cd gateway && pip install -r requirements.txt && uvicorn app.main:app --reload
"""
import time
import uuid
from typing import Any

import httpx
from fastapi import Body, Depends, FastAPI, HTTPException
from pydantic import BaseModel

from .auth import AuthenticatedUser, get_current_user
from .config import settings
from .envelope import AgentRequest, AgentResponse, SafetyInfo, UsageInfo
from .model_router.router import route_generate
from .observability import log_gateway_call
from .rag.ingest import ingest_lesson
from .registry import get_agent_version
from .tools import TOOL_REGISTRY
from .tools.registry import TOOL_ERRORS


class ModelRouterRequest(BaseModel):
    capability: str
    user_prompt: str
    system_prompt: str | None = None
    max_tokens: int = 1024

app = FastAPI(
    title="EDLEARN Sovereign AI Gateway",
    version="0.1.0",
    description="IA-002 — voir docs/CAHIER_DES_CHARGES_AGENTS_IA.md",
)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post("/v1/agents/{agent_id}/invoke", response_model=AgentResponse)
async def invoke_agent(
    agent_id: str,
    request: AgentRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> AgentResponse:
    if request.agent_id != agent_id:
        raise HTTPException(status_code=400, detail="agent_id du corps de requête != agent_id de l'URL.")

    request_id = str(uuid.uuid4())
    started = time.monotonic()

    version = await get_agent_version(agent_id)
    edge_function_name = version["edge_function_name"]

    # Route vers l'Edge Function réelle (voir docstring : pas encore d'orchestrateur/modèles
    # auto-hébergés). Le payload agent-spécifique reste tel quel — chaque agent a aujourd'hui son
    # propre contrat réel (voir ai_agent_versions.input_schema), la Gateway ne le réinvente pas ici.
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            res = await client.post(
                f"{settings.functions_url}/{edge_function_name}",
                json=request.payload,
                headers={
                    "Authorization": f"Bearer {user.raw_token}",
                    "apikey": settings.supabase_anon_key,
                    "Content-Type": "application/json",
                },
            )
    except httpx.HTTPError as exc:
        duration_ms = int((time.monotonic() - started) * 1000)
        await log_gateway_call(
            request_id=request_id, agent_type=agent_id, status="failed",
            duration_ms=duration_ms, error_message=f"Erreur réseau vers {edge_function_name}: {exc}",
        )
        raise HTTPException(status_code=502, detail=f"Agent '{agent_id}' injoignable : {exc}") from exc

    duration_ms = int((time.monotonic() - started) * 1000)
    body = res.json() if res.headers.get("content-type", "").startswith("application/json") else {}

    if res.status_code != 200:
        error_message = body.get("error", f"HTTP {res.status_code} depuis {edge_function_name}")
        await log_gateway_call(
            request_id=request_id, agent_type=agent_id, status="failed",
            duration_ms=duration_ms, error_message=error_message,
        )
        return AgentResponse(
            request_id=request_id, status="failed", result={"error": error_message},
            usage=UsageInfo(route="server", compute_units=0),
            agent_version=version["version"],
            model_version=None,
            safety=SafetyInfo(),
        )

    # Les métadonnées CF-004 (_request_id/_model/_duration_ms/_agent_version) que l'Edge Function
    # a déjà produites sont extraites pour peupler l'enveloppe standard, puis retirées de `result`
    # pour ne pas les dupliquer.
    model_version = body.pop("_model", None)
    body.pop("_request_id", None)
    body.pop("_agent_version", None)
    body.pop("_duration_ms", None)

    await log_gateway_call(request_id=request_id, agent_type=agent_id, status="success", duration_ms=duration_ms)

    return AgentResponse(
        request_id=request_id,
        status="success",
        result=body,
        usage=UsageInfo(route="server", compute_units=0),
        agent_version=version["version"],
        model_version=model_version,
        safety=SafetyInfo(),
    )


@app.get("/v1/tools")
async def list_tools(user: AuthenticatedUser = Depends(get_current_user)) -> dict:
    """IA-003 : liste allowlistée — jamais d'accès SQL générique (§2 du cahier Agents IA)."""
    return {"tools": sorted(TOOL_REGISTRY.keys())}


@app.post("/v1/tools/{tool_key}/call")
async def call_tool(
    tool_key: str,
    payload: dict[str, Any] = Body(default_factory=dict),
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    """IA-003 "Tool Gateway". Chaque tool est une fonction Python à paramètres fixes (voir
    app/tools/registry.py) — `tool_key` hors de l'allowlist est un 404, jamais une exécution
    générique."""
    handler = TOOL_REGISTRY.get(tool_key)
    if handler is None:
        raise HTTPException(status_code=404, detail=f"Tool inconnu ou non allowlisté : {tool_key}")

    request_id = str(uuid.uuid4())
    started = time.monotonic()
    try:
        result = await handler(payload)
    except TOOL_ERRORS as exc:
        duration_ms = int((time.monotonic() - started) * 1000)
        await log_gateway_call(
            request_id=request_id, agent_type=f"tool:{tool_key}", status="failed",
            duration_ms=duration_ms, error_message=str(exc),
        )
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    duration_ms = int((time.monotonic() - started) * 1000)
    await log_gateway_call(request_id=request_id, agent_type=f"tool:{tool_key}", status="success", duration_ms=duration_ms)
    return {"request_id": request_id, "tool_key": tool_key, "result": result, "duration_ms": duration_ms}


@app.post("/v1/rag/ingest/{lesson_id}")
async def rag_ingest(lesson_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> dict:
    """IA-004 partie 2 : ingère une leçon réellement publiée dans le RAG (chunking + embeddings
    réels + pgvector). Réservé admin — ingérer du contenu n'est pas une action élève."""
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Réservé aux comptes admin.")
    request_id = str(uuid.uuid4())
    started = time.monotonic()
    try:
        result = await ingest_lesson(lesson_id)
    except HTTPException as exc:
        duration_ms = int((time.monotonic() - started) * 1000)
        await log_gateway_call(
            request_id=request_id, agent_type="rag_ingest", status="failed",
            duration_ms=duration_ms, error_message=exc.detail,
        )
        raise
    duration_ms = int((time.monotonic() - started) * 1000)
    await log_gateway_call(request_id=request_id, agent_type="rag_ingest", status="success", duration_ms=duration_ms)
    return {"request_id": request_id, **result}


@app.post("/v1/model-router/generate")
async def model_router_generate(
    request: ModelRouterRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    """IA-005 "Model Router". L'appelant demande une capability, jamais un fournisseur (§5 du
    cahier) — le choix réel du moteur vit dans ai-generate-text, pas ici."""
    if request.capability not in ("reasoning_strong", "pedagogy_small", "classification_small"):
        raise HTTPException(status_code=400, detail=f"capability invalide : {request.capability}")
    result = await route_generate(
        capability=request.capability,  # type: ignore[arg-type]
        user_prompt=request.user_prompt,
        system_prompt=request.system_prompt,
        max_tokens=request.max_tokens,
    )
    return result
