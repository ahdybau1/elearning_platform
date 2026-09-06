"""IA-013 "Operations" — FraudRiskAgent (AIA-AGT-025).

Mission du cahier : « Produire des signaux de risque sur paiements, examens, comptes, promotions ou
usages anormaux. » Sortie : « risk signals + evidence + confidence + recommended review. » Règle :
« Signal ≠ preuve. Pas de sanction automatique lourde sur seul score IA. Features sensibles
limitées, explicabilité et audit obligatoires. »

Scope v1 : UN SEUL signal — partage d'appareil entre comptes distincts (`sessions.device_fingerprint`,
migration 01, dont le commentaire dit explicitement « anti-partage de compte »). Choisi parce que le
schéma le prévoit déjà, pas inventé. Aucun signal de paiement/examen construit ici : ni volume réel
ni schéma dédié pour les calibrer honnêtement (même principe que RevisionAgent — ne pas inventer une
constante non calibrée). `confidence` reste une heuristique déclarée, jamais une probabilité
mesurée ; ce n'est qu'un signal à faire vérifier par un humain, jamais une sanction.
"""
import httpx
from ..config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

SHARED_DEVICE_MIN_ACCOUNTS = 2


async def detect_shared_device_risk(limit: int = 20) -> list[dict]:
    async with httpx.AsyncClient(timeout=15.0) as client:
        res = await client.get(
            f"{settings.rest_url}/sessions",
            params={"is_active": "eq.true", "select": "account_id,device_fingerprint,platform,last_active_at"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []

    by_fingerprint: dict[str, list[dict]] = {}
    for r in rows:
        by_fingerprint.setdefault(r["device_fingerprint"], []).append(r)

    signals = []
    for fingerprint, sess in by_fingerprint.items():
        distinct_accounts = sorted({s["account_id"] for s in sess})
        if len(distinct_accounts) < SHARED_DEVICE_MIN_ACCOUNTS:
            continue
        signals.append({
            "signal_type": "shared_device",
            "device_fingerprint": fingerprint,
            "accounts": distinct_accounts,
            "evidence": [
                {"account_id": s["account_id"], "platform": s["platform"], "last_active_at": s["last_active_at"]}
                for s in sess
            ],
            # Heuristique déclarée, plafonnée — pas une probabilité mesurée (voir docstring).
            "confidence": min(0.5 + 0.1 * (len(distinct_accounts) - 2), 0.9),
            "recommended_review": "Vérifier s'il s'agit d'un appareil familial légitime ou d'un partage d'abonnement.",
        })
    signals.sort(key=lambda s: s["confidence"], reverse=True)
    return signals[:limit]
