"""IA-013 "Operations" — AdminAssistantAgent (AIA-AGT-021).

Mission du cahier : « Aider un administrateur à comprendre l'état de la plateforme, naviguer dans
les données autorisées et préparer des actions. » Tools : « Read-only analytics par défaut... »
Interdits : « SQL arbitraire, modification RLS directe, remboursement/publication/suppression
massive sans service métier + confirmation/validation. »

Scope v1 : strictement en lecture, zéro mutation (conforme aux interdits ci-dessus) — un agrégat
« ce qui mérite l'attention de l'admin maintenant », qui n'existe nulle part comme vue unique
aujourd'hui (admin_app a des écrans séparés : Agents IA & Coûts, Tickets Support, File de
Validation — jamais assemblés en une seule synthèse). Pas de « search admin docs »/« job status » du
cahier : aucune infra de recherche documentaire ni de file de jobs n'existe sur ce projet (même
constat que pour InfrastructureOpsAgent, différé) — honnêtement omis plutôt que simulé.
"""
import httpx
from ..config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}


async def _fetch_recent_ai_failures(limit: int) -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/ai_agent_calls",
            params={
                "status": "eq.failed", "order": "created_at.desc", "limit": str(limit),
                "select": "agent_type,error_message,created_at",
            },
            headers=_service_headers,
        )
    return res.json() if res.status_code == 200 else []


async def _fetch_open_ticket_categories() -> dict[str, int]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/support_tickets",
            params={"status": "in.(ouvert,en_cours)", "select": "category"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    counts: dict[str, int] = {}
    for r in rows:
        counts[r["category"]] = counts.get(r["category"], 0) + 1
    return counts


async def _fetch_pending_validation_count() -> int:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/validation_queue",
            params={"status": "eq.en_attente", "select": "id"},
            headers=_service_headers,
        )
    return len(res.json()) if res.status_code == 200 else 0


async def build_platform_summary(failure_limit: int = 10) -> dict:
    failures = await _fetch_recent_ai_failures(failure_limit)
    open_tickets = await _fetch_open_ticket_categories()
    pending_validation = await _fetch_pending_validation_count()
    return {
        "recent_ai_failures": failures,
        "open_support_tickets_by_category": open_tickets,
        "pending_content_validation": pending_validation,
    }
