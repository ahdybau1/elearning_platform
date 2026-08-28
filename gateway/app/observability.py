"""Observabilité (IA-002). Réutilise ai_agent_calls (déjà enrichie par CF-004, migration 53) au lieu
de créer une table de logs séparée pour ce premier work package — évite de dupliquer un mécanisme qui
fonctionne déjà et donne une vue de coûts unifiée, Edge Functions + Gateway confondues.
"""
import httpx
from .config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}


async def log_gateway_call(
    *,
    request_id: str,
    agent_type: str,
    status: str,
    duration_ms: int,
    error_message: str | None = None,
) -> None:
    payload = {
        "request_id": request_id,
        "agent_type": agent_type,
        "provider": "gateway",
        "model": None,
        "tokens_used": 0,
        "cost_estimate": 0,
        "duration_ms": duration_ms,
        "status": status,
        "error_message": error_message,
    }
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            await client.post(
                f"{settings.rest_url}/ai_agent_calls",
                json=payload,
                headers=_service_headers,
            )
    except httpx.HTTPError:
        # Ne jamais faire échouer une requête agent à cause d'un problème de journalisation —
        # même règle que les Edge Functions Deno existantes (try/catch autour de l'insert).
        pass
