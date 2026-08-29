"""IA-007 "Premier vertical slice" — TutorAgent (AIA-AGT-001) avec RAG + math tool + Student Model
read + cache + quota + observabilité (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22).

quota et observabilité restent gérés génériquement par main.py (record_usage/log_gateway_call,
IA-002/IA-006) — ce module ajoute ce qui manquait réellement : RAG scopé + citations, un déclenchement
heuristique du tool math, une lecture réelle du Student Model, et un cache de réponses.

Appelle l'Edge Function `ai-tutor-chat` existante (étendue de façon additive, voir son commentaire de
tête) pour l'appel LLM lui-même plutôt que de le dupliquer ici — cohérent avec IA-002 (« la Gateway
route vers les Edge Functions réellement déployées, elle ne les remplace pas »).
"""
import hashlib
import re
from datetime import datetime, timezone

import httpx
from ..config import settings
from ..rag.retrieve import rag_search
from ..tools.math_tools import MathToolError, sympy_solve
from ..student_model.mastery import get_mastery_snapshot, format_mastery_summary

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

# Heuristique de déclenchement du tool math — pas un vrai tool-calling agentique (ça, c'est le rôle de
# l'Agent Orchestrator/LangGraph, explicitement différé, IA-009+). Cherche un fragment SANS espace qui
# ressemble à une expression algébrique (ex: "2x+3=7") quelque part dans le message — volontairement
# sans espace pour ne pas capturer des mots de la phrase environnante comme un faux positif (limite
# heuristique connue : une équation écrite avec des espaces, "2x + 3 = 7", n'est pas détectée telle
# quelle). '=' est inclus ici (équations) mais volontairement absent de l'allowlist de math_tools.py —
# le signe est toujours consommé par _prepare_math_call avant d'atteindre sympy_solve, jamais transmis
# tel quel.
_MATH_CANDIDATE_RE = re.compile(r"[0-9][0-9a-zA-Z_+\-*/^().,=]{1,60}[0-9a-zA-Z)]")


def _extract_math_candidate(message: str) -> str | None:
    for match in _MATH_CANDIDATE_RE.finditer(message):
        candidate = match.group(0).strip()
        if any(op in candidate for op in ("+", "-", "*", "/", "^", "=")) and any(c.isdigit() for c in candidate):
            return candidate
    return None


def _prepare_math_call(candidate: str) -> tuple[str, str]:
    """'solve' résout expr=0 (voir math_tools.py) — une expression avec '=' doit donc être ramenée à
    cette forme avant l'appel, sinon seul le membre de gauche serait résolu."""
    if "=" in candidate:
        left, right = candidate.split("=", 1)
        return f"({left.strip()})-({right.strip()})", "solve"
    return candidate, "evaluate"


def _cache_key(message: str, subject_id: str | None, lesson_id: str | None) -> str:
    raw = f"{message.strip().lower()}|{subject_id or ''}|{lesson_id or ''}"
    return hashlib.sha256(raw.encode()).hexdigest()


async def _cache_lookup(key: str) -> dict | None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/ai_tutor_cache",
            params={"cache_key": f"eq.{key}", "select": "reply,citations,hit_count"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    if not rows:
        return None
    row = rows[0]
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            await client.patch(
                f"{settings.rest_url}/ai_tutor_cache",
                params={"cache_key": f"eq.{key}"},
                json={"hit_count": row.get("hit_count", 0) + 1, "last_hit_at": datetime.now(timezone.utc).isoformat()},
                headers=_service_headers,
            )
    except httpx.HTTPError:
        pass
    return row


async def _cache_store(key: str, subject_id: str | None, class_node_id: str | None, query: str, reply: str, citations: list[dict]) -> None:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            await client.post(
                f"{settings.rest_url}/ai_tutor_cache",
                json={
                    "cache_key": key, "subject_id": subject_id, "class_node_id": class_node_id,
                    "query_text": query, "reply": reply, "citations": citations,
                },
                headers={**_service_headers, "Prefer": "resolution=ignore-duplicates"},
            )
    except httpx.HTTPError:
        pass


async def run_tutor_agent(
    *,
    profile_id: str | None,
    message: str,
    subject_name: str | None,
    class_name: str | None,
    history: list | None,
    subject_id: str | None,
    class_node_id: str | None,
    lesson_id: str | None,
    user_jwt: str,
) -> dict:
    """Retourne un dict prêt à être injecté dans `result` de l'enveloppe standard, plus
    `citations`/`tool_trace_summary`/`usage_route`/`_model`/`_request_id` séparés pour que main.py les
    place aux bons champs de AgentResponse (§4.2)."""
    key = _cache_key(message, subject_id, lesson_id)
    cached = await _cache_lookup(key)
    if cached:
        return {
            "reply": cached["reply"], "citations": cached.get("citations") or [],
            "tool_trace_summary": [], "route": "cache", "model": None, "request_id": None,
        }

    # RAG (§10 : citations obligatoires pour les faits pédagogiques récupérés) — scopé à la
    # matière/classe actives, jamais tout le corpus.
    citations: list[dict] = []
    rag_context_text = None
    if subject_id or class_node_id:
        rag_result = await rag_search(query=message, class_node_id=class_node_id, subject_id=subject_id, top_k=3)
        citations = rag_result.get("citations", [])
        if citations:
            rag_context_text = "\n\n".join(f"[{c.get('source_title') or 'Source'}] {c['content']}" for c in citations)

    # Student Model read (U9) — jamais un chiffre inventé, uniquement ce que get_mastery_snapshot
    # renvoie réellement depuis exercise_attempts.
    student_model_summary = None
    if profile_id and subject_id:
        mastery_rows = await get_mastery_snapshot(profile_id, subject_id)
        student_model_summary = format_mastery_summary(mastery_rows)

    # Tool math (§12 : jamais de calcul exact confié uniquement au LLM) — déclenchement heuristique,
    # échoue silencieusement si le fragment détecté n'est pas une expression valide (c'est attendu :
    # l'heuristique est volontairement large, math_tools.py fait le vrai tri).
    tool_trace_summary: list[dict] = []
    tool_context_text = None
    candidate = _extract_math_candidate(message)
    if candidate:
        expr, mode = _prepare_math_call(candidate)
        try:
            result = sympy_solve(expression=expr, mode=mode)
            tool_context_text = f"Résultat vérifié par calcul exact (SymPy, ne pas recalculer autrement) pour « {candidate} » : {result['result']}"
            tool_trace_summary.append({"tool": "sympy_solve", "input": {"expression": expr, "mode": mode}, "output": result})
        except MathToolError:
            pass

    payload = {
        "message": message, "subject_name": subject_name, "class_name": class_name, "history": history or [],
        "rag_context": rag_context_text, "student_model_summary": student_model_summary, "tool_context": tool_context_text,
    }
    async with httpx.AsyncClient(timeout=60.0) as client:
        res = await client.post(
            f"{settings.functions_url}/ai-tutor-chat",
            json=payload,
            headers={
                "Authorization": f"Bearer {user_jwt}",
                "apikey": settings.supabase_anon_key,
                "Content-Type": "application/json",
            },
        )
    body = res.json() if res.headers.get("content-type", "").startswith("application/json") else {}
    if res.status_code != 200:
        raise RuntimeError(body.get("error", f"HTTP {res.status_code} depuis ai-tutor-chat"))

    reply = body.get("reply", "")
    await _cache_store(key, subject_id, class_node_id, message, reply, citations)

    return {
        "reply": reply, "citations": citations, "tool_trace_summary": tool_trace_summary,
        "route": "server", "model": body.get("_model"), "request_id": body.get("_request_id"),
    }
