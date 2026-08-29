"""Retrieval filtré + citations (§10 du cahier). Interroge le RPC `match_rag_chunks` (migration 59)
— jamais de SQL construit à la main pour ce filtrage."""
import httpx
from fastapi import HTTPException

from ..config import settings
from .embeddings_client import generate_embeddings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}


async def rag_search(
    query: str,
    class_node_id: str | None = None,
    subject_id: str | None = None,
    top_k: int = 5,
) -> dict:
    if not query or not query.strip():
        raise HTTPException(status_code=422, detail="query manquante.")

    embeddings = await generate_embeddings([query])
    query_embedding = embeddings[0]

    async with httpx.AsyncClient(timeout=15.0) as client:
        res = await client.post(
            f"{settings.rest_url}/rpc/match_rag_chunks",
            json={
                "query_embedding": query_embedding,
                "match_class_node_id": class_node_id,
                "match_subject_id": subject_id,
                "match_count": top_k,
            },
            headers=_service_headers,
        )
    if res.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Échec de la recherche RAG : HTTP {res.status_code} — {res.text[:300]}")

    matches = res.json()
    if not matches:
        return {"citations": []}

    # Résout le titre de la source (§10 : "citation liée à version/source") pour chaque match.
    source_ids = list({m["source_id"] for m in matches})
    async with httpx.AsyncClient(timeout=15.0) as client:
        sources_res = await client.get(
            f"{settings.rest_url}/ai_rag_sources",
            params={"id": f"in.({','.join(source_ids)})", "select": "id,title,source_type"},
            headers=_service_headers,
        )
    sources_by_id = {s["id"]: s for s in sources_res.json()} if sources_res.status_code == 200 else {}

    citations = [
        {
            "chunk_id": m["id"],
            "source_id": m["source_id"],
            "source_title": sources_by_id.get(m["source_id"], {}).get("title"),
            "source_type": sources_by_id.get(m["source_id"], {}).get("source_type"),
            "content": m["content"],
            "similarity": m["similarity"],
        }
        for m in matches
    ]
    return {"citations": citations}
