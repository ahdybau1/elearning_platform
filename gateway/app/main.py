"""Sovereign AI Gateway (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §3).

IA-002 (Gateway minimale) + IA-003 (Tool Gateway) + IA-004 (RAG) + IA-005 (Model Router) + IA-006
(Quota Engine — traçage réel, pas encore d'application de plafond) faits, dans cet ordre. PAS encore
d'Agent Orchestrator (LangGraph) ni de modèle auto-hébergé (vLLM/Ollama) — la Gateway route
aujourd'hui vers les Edge Functions Deno réellement déployées (via le registre IA-001), elle ne les
remplace pas.

Lancer en local ("machine développeur", légitime en Compute Fabric — §U6 du cahier) :
    cd gateway && pip install -r requirements.txt && uvicorn app.main:app --reload
"""
import time
import uuid
from datetime import datetime, timezone
from typing import Any

import httpx
from fastapi import Body, Depends, FastAPI, HTTPException
from pydantic import BaseModel

from .agents.correction_agent import CorrectionAgentError, correct_attempt
from .agents.curriculum_mapping import map_content
from .agents.pedagogical_validation import validate_lesson
from .agents.tutor_agent import run_tutor_agent
from .auth import AuthenticatedUser, get_current_user, verify_profile_access
from .config import settings
from .envelope import AgentRequest, AgentResponse, SafetyInfo, UsageInfo
from .model_router.router import route_generate
from .observability import log_gateway_call
from .quota import record_usage
from .rag.ingest import ingest_lesson
from .registry import get_agent_version
from .student_model.mastery import get_mastery_snapshot
from .student_model.orchestrator import recommend_next_skill
from .tools import TOOL_REGISTRY
from .tools.registry import TOOL_ERRORS


class ModelRouterRequest(BaseModel):
    capability: str
    user_prompt: str
    system_prompt: str | None = None
    max_tokens: int = 1024


class ReviewAttemptRequest(BaseModel):
    official_correct: bool

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
    # IA-007 : un profile_id doit réellement appartenir au compte authentifié — rien ne le vérifiait
    # avant (voir le commentaire de verify_profile_access), et IA-007 lit désormais des données
    # pédagogiques (Student Model) à partir de ce même profile_id.
    await verify_profile_access(user, request.profile_id)

    request_id = str(uuid.uuid4())
    started = time.monotonic()

    version = await get_agent_version(agent_id)
    edge_function_name = version["edge_function_name"]

    # IA-008 : CurriculumMappingAgent et PedagogicalValidationAgent sont "gateway_native" (aucune
    # Edge Function Deno — pure orchestration Python, pas de génération LLM nécessaire). Agents de la
    # chaîne Content Factory, réservés à l'équipe contenu/admin — jamais un appel élève.
    if agent_id in ("AIA-AGT-017", "AIA-AGT-024", "AIA-AGT-005"):
        if not user.is_admin:
            raise HTTPException(status_code=403, detail="Réservé aux comptes admin (agent Content Factory / correction).")
        try:
            if agent_id == "AIA-AGT-017":
                result = await map_content(text=str(request.payload.get("text", "")))
            elif agent_id == "AIA-AGT-024":
                result = await validate_lesson(lesson_id=str(request.payload.get("lesson_id", "")))
            else:
                result = await correct_attempt(attempt_id=str(request.payload.get("attempt_id", "")))
        except CorrectionAgentError as exc:
            duration_ms = int((time.monotonic() - started) * 1000)
            await log_gateway_call(
                request_id=request_id, agent_type=agent_id, status="failed",
                duration_ms=duration_ms, error_message=str(exc),
            )
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except Exception as exc:
            duration_ms = int((time.monotonic() - started) * 1000)
            await log_gateway_call(
                request_id=request_id, agent_type=agent_id, status="failed",
                duration_ms=duration_ms, error_message=str(exc),
            )
            raise HTTPException(status_code=502, detail=f"{agent_id} en échec : {exc}") from exc
        duration_ms = int((time.monotonic() - started) * 1000)
        await log_gateway_call(request_id=request_id, agent_type=agent_id, status="success", duration_ms=duration_ms)
        return AgentResponse(
            request_id=request_id, status="success", result=result,
            usage=UsageInfo(route="server", compute_units=0),
            agent_version=version["version"], model_version=None, safety=SafetyInfo(),
        )

    # IA-007 : TutorAgent (AIA-AGT-001) a une vraie orchestration (RAG + math tool + Student Model +
    # cache) — voir gateway/app/agents/tutor_agent.py. Tous les autres agents restent un simple proxy
    # vers leur Edge Function (voir docstring : pas encore d'orchestrateur générique).
    if agent_id == "AIA-AGT-001":
        try:
            tutor_result = await run_tutor_agent(
                profile_id=request.profile_id,
                message=str(request.payload.get("message", "")),
                subject_name=request.payload.get("subject_name"),
                class_name=request.payload.get("class_name"),
                history=request.payload.get("history"),
                subject_id=request.academic_context.subject_id,
                class_node_id=request.academic_context.class_id,
                lesson_id=request.academic_context.lesson_id,
                user_jwt=user.raw_token,
            )
        except Exception as exc:
            duration_ms = int((time.monotonic() - started) * 1000)
            await log_gateway_call(
                request_id=request_id, agent_type=agent_id, status="failed",
                duration_ms=duration_ms, error_message=str(exc),
            )
            raise HTTPException(status_code=502, detail=f"TutorAgent (IA-007) en échec : {exc}") from exc

        duration_ms = int((time.monotonic() - started) * 1000)
        await log_gateway_call(request_id=request_id, agent_type=agent_id, status="success", duration_ms=duration_ms)
        await record_usage(
            profile_id=request.profile_id, agent_type=agent_id,
            edge_function_request_id=tutor_result.get("request_id"),
        )
        return AgentResponse(
            request_id=request_id, status="success",
            result={"reply": tutor_result["reply"]},
            citations=tutor_result.get("citations", []),
            tool_trace_summary=tutor_result.get("tool_trace_summary", []),
            usage=UsageInfo(route=tutor_result.get("route", "server"), compute_units=0),
            agent_version=version["version"],
            model_version=tutor_result.get("model"),
            safety=SafetyInfo(),
        )

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
    edge_request_id = body.pop("_request_id", None)
    body.pop("_agent_version", None)
    body.pop("_duration_ms", None)

    await log_gateway_call(request_id=request_id, agent_type=agent_id, status="success", duration_ms=duration_ms)
    # IA-006 : journalise l'usage réel (voir app/quota.py). N'échoue jamais la requête si ça rate —
    # ne bloque encore aucune requête, se contente de tracer pour un futur benchmark (§6/U7 du cahier).
    await record_usage(
        profile_id=request.profile_id,
        agent_type=agent_id,
        edge_function_request_id=edge_request_id,
    )

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


@app.get("/v1/student-model/{profile_id}/mastery")
async def student_model_mastery(
    profile_id: str,
    subject_id: str | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    """IA-007/U9 : lecture directe du Student Model (maîtrise réelle par compétence, recalculée à la
    demande — voir get_student_skill_mastery, migration 64)."""
    await verify_profile_access(user, profile_id)
    return {"mastery": await get_mastery_snapshot(profile_id, subject_id)}


@app.get("/v1/student-model/{profile_id}/next-skill")
async def student_model_next_skill(
    profile_id: str,
    subject_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    """Learning Orchestrator (U9) : recommandation déterministe de la prochaine compétence à
    travailler, depuis le Competency Graph + le Student Model réel. `recommendation: null` est un état
    honnête (aucune compétence enregistrée pour cette matière, ou tout est déjà maîtrisé) — jamais une
    compétence inventée pour éviter de renvoyer null."""
    await verify_profile_access(user, profile_id)
    recommendation = await recommend_next_skill(profile_id, subject_id)
    return {"recommendation": recommendation}


@app.post("/v1/exercise-attempts/{attempt_id}/review")
async def review_exercise_attempt(
    attempt_id: str,
    review: ReviewAttemptRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    """IA-009 : la "validation humaine" exigée par le cahier pour CorrectionAgent (AIA-AGT-005) —
    `official_correct` (la note qui compte réellement) ne peut être écrite QUE par un admin ici, jamais
    par l'agent lui-même (voir gateway/app/agents/correction_agent.py, qui n'écrit que les champs
    `ai_*`). Réservé admin, RLS de la migration 68 l'impose aussi côté base (défense en profondeur)."""
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Réservé aux comptes admin.")
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.patch(
            f"{settings.rest_url}/exercise_attempts",
            params={"id": f"eq.{attempt_id}"},
            json={
                "official_correct": review.official_correct,
                "reviewed_by": user.admin_user_id,
                "reviewed_at": datetime.now(timezone.utc).isoformat(),
            },
            headers={
                "Authorization": f"Bearer {settings.supabase_service_role_key}",
                "apikey": settings.supabase_service_role_key,
                "Content-Type": "application/json",
                "Prefer": "return=representation",
            },
        )
    if res.status_code not in (200, 204):
        raise HTTPException(status_code=502, detail=f"Échec de l'enregistrement de la revue : HTTP {res.status_code}")
    return {"attempt_id": attempt_id, "official_correct": review.official_correct}
