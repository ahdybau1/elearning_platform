"""Sovereign AI Gateway — IA-002 "Gateway minimal" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §3).

Portée volontairement minimale, conforme à l'ordre du cahier : auth, permissions, request IDs,
validation structurée (enveloppe §4), observabilité. PAS encore d'Agent Orchestrator (LangGraph),
PAS de RAG branché, PAS de Model Router (IA-005) — la Gateway route aujourd'hui vers les Edge
Functions Deno réellement déployées (via le registre IA-001), elle ne les remplace pas.

Lancer en local ("machine développeur", légitime en Compute Fabric — §U6 du cahier) :
    cd gateway && pip install -r requirements.txt && uvicorn app.main:app --reload
"""
import time
import uuid
from typing import Any

import httpx
from fastapi import Body, Depends, FastAPI, HTTPException

from .auth import AuthenticatedUser, get_current_user
from .config import settings
from .envelope import AgentRequest, AgentResponse, SafetyInfo, UsageInfo
from .observability import log_gateway_call
from .registry import get_agent_version
from .tools import TOOL_REGISTRY
from .tools.registry import TOOL_ERRORS

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
