"""IA-006 "Quota Engine" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §6, migration 63).

Résout l'entitlement réel d'un profil et journalise l'usage dans ai_usage_ledger — AUCUNE valeur de
quota n'est appliquée en dur ici (allowance_units est NULL tant qu'aucun benchmark réel n'a fixé de
chiffre, conformément à la règle explicite du cahier). Ce module trace l'usage réel dès maintenant
pour qu'un vrai benchmark soit possible plus tard ; il ne bloque encore aucune requête.
"""
import httpx
from .config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}


async def get_entitlement(profile_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/ai_entitlements",
            params={
                "profile_id": f"eq.{profile_id}",
                "select": "policy_key,source,ai_policies(name,max_model_tier,priority,allowance_units,allowance_period)",
            },
            headers=_service_headers,
        )
    if res.status_code != 200 or not res.json():
        return None
    return res.json()[0]


async def _lookup_tokens_used(edge_function_request_id: str | None) -> int:
    """Va chercher les tokens réellement consommés dans ai_agent_calls (déjà journalisés par
    l'Edge Function elle-même, CF-004) — jamais une estimation inventée côté Gateway."""
    if not edge_function_request_id:
        return 0
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/ai_agent_calls",
            params={"request_id": f"eq.{edge_function_request_id}", "select": "tokens_used"},
            headers=_service_headers,
        )
    if res.status_code == 200 and res.json():
        return res.json()[0].get("tokens_used") or 0
    return 0


async def record_usage(
    *,
    profile_id: str | None,
    agent_type: str,
    edge_function_request_id: str | None,
    compute_class: str = "server",
) -> None:
    """N'échoue jamais la requête appelante si la journalisation échoue — même principe que
    log_gateway_call (observability.py)."""
    if not profile_id:
        return
    try:
        entitlement = await get_entitlement(profile_id)
        policy_key = entitlement["policy_key"] if entitlement else None
        units_consumed = await _lookup_tokens_used(edge_function_request_id)
        async with httpx.AsyncClient(timeout=10.0) as client:
            await client.post(
                f"{settings.rest_url}/ai_usage_ledger",
                json={
                    "request_id": edge_function_request_id,
                    "beneficiary_profile_id": profile_id,
                    "policy_key": policy_key,
                    "agent_type": agent_type,
                    "compute_class": compute_class,
                    "units_consumed": units_consumed,
                    "reason": "agent_invoke",
                },
                headers=_service_headers,
            )
    except httpx.HTTPError:
        pass
