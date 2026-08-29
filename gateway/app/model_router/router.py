"""IA-005 "Model Router" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §22, §5) : « Les agents ne choisissent
pas directement un fournisseur. Ils demandent une capability [...] Le Model Router choisit le moteur
autorisé. »

Le choix réel du moteur vit dans l'Edge Function `ai-generate-text` (secret Gemini uniquement
là-bas — même principe que embeddings_client.py) ; ce module est le point d'entrée côté Gateway que
les agents/outils appelleront, pas un second endroit qui réinvente le routage.

Claude retiré le 2026-08-29 (demande explicite du porteur de projet) : `ANTHROPIC_API_KEY` n'était
pas configurée comme secret sur ce projet (vérifié via `supabase secrets list`), la préférence
"reasoning_strong -> Claude" n'a donc jamais été exercée en pratique — voir le même constat côté
`ai-generate-text/index.ts`. Les 3 capabilities routent aujourd'hui toutes vers Gemini.
"""
from typing import Literal

import httpx
from fastapi import HTTPException

from ..config import settings

Capability = Literal["reasoning_strong", "pedagogy_small", "classification_small"]

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_anon_key,
    "Content-Type": "application/json",
}


async def route_generate(
    capability: Capability,
    user_prompt: str,
    system_prompt: str | None = None,
    max_tokens: int = 1024,
) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        res = await client.post(
            f"{settings.functions_url}/ai-generate-text",
            json={
                "capability": capability,
                "system_prompt": system_prompt,
                "user_prompt": user_prompt,
                "max_tokens": max_tokens,
            },
            headers=_service_headers,
        )
    body = res.json() if res.headers.get("content-type", "").startswith("application/json") else {}
    if res.status_code != 200:
        raise HTTPException(status_code=502, detail=body.get("error", "Échec du Model Router."))

    return {
        "text": body["text"],
        "provider": body.get("_provider"),
        "model": body.get("_model"),
        "capability": capability,
    }
