"""Appelle ai-embeddings-generate (Edge Function Deno) plutôt que Gemini directement — GEMINI_API_KEY
reste uniquement dans les secrets Supabase, jamais dupliquée dans gateway/.env.
"""
import httpx
from fastapi import HTTPException
from ..config import settings


async def generate_embeddings(texts: list[str]) -> list[list[float]]:
    if not texts:
        return []
    async with httpx.AsyncClient(timeout=30.0) as client:
        res = await client.post(
            f"{settings.functions_url}/ai-embeddings-generate",
            json={"texts": texts},
            headers={
                "Authorization": f"Bearer {settings.supabase_service_role_key}",
                "apikey": settings.supabase_anon_key,
                "Content-Type": "application/json",
            },
        )
    if res.status_code != 200:
        body = res.json() if res.headers.get("content-type", "").startswith("application/json") else {}
        raise HTTPException(status_code=502, detail=body.get("error", "Échec de génération d'embeddings."))
    return res.json()["embeddings"]
