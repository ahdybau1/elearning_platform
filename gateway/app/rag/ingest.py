"""Pipeline d'ingestion réel (§10 du cahier : "SOURCE VALIDÉE -> ingestion versionnée -> nettoyage ->
segmentation structure-aware -> metadata curriculum/permission/version -> embeddings locaux ->
pgvector"). Ne source aujourd'hui QUE des leçons réellement publiées (is_published=true,
is_active=true) — jamais un brouillon, cohérent avec `search_validated_content` (IA-003).
"""
from datetime import datetime, timezone

import httpx
from fastapi import HTTPException

from ..config import settings
from .chunking import chunk_lesson_content
from .embeddings_client import generate_embeddings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}


async def ingest_lesson(lesson_id: str) -> dict:
    async with httpx.AsyncClient(timeout=15.0) as client:
        res = await client.get(
            f"{settings.rest_url}/lessons",
            params={
                "id": f"eq.{lesson_id}",
                "select": "id,title,content_json,is_published,is_active,chapters(subject_id,class_node_id)",
            },
            headers=_service_headers,
        )
    if res.status_code != 200 or not res.json():
        raise HTTPException(status_code=404, detail=f"Leçon introuvable : {lesson_id}")
    lesson = res.json()[0]
    if not lesson.get("is_published") or not lesson.get("is_active"):
        raise HTTPException(status_code=409, detail="Seules les leçons publiées et actives sont ingérées (source non fiable sinon — §10 du cahier).")

    chapter = lesson.get("chapters") or {}
    subject_id = chapter.get("subject_id")
    class_node_id = chapter.get("class_node_id")

    chunks = chunk_lesson_content(lesson.get("content_json") or {})
    if not chunks:
        raise HTTPException(status_code=422, detail="Aucun contenu exploitable à ingérer pour cette leçon.")

    async with httpx.AsyncClient(timeout=15.0) as client:
        # 1. Source (upsert par source_ref pour ne jamais dupliquer une même leçon déjà ingérée).
        existing = await client.get(
            f"{settings.rest_url}/ai_rag_sources",
            params={"source_ref_table": "eq.lessons", "source_ref_id": f"eq.{lesson_id}", "select": "id"},
            headers=_service_headers,
        )
        if existing.status_code == 200 and existing.json():
            source_id = existing.json()[0]["id"]
        else:
            source_res = await client.post(
                f"{settings.rest_url}/ai_rag_sources",
                json={
                    "title": lesson["title"],
                    "source_type": "lesson",
                    "source_ref_table": "lessons",
                    "source_ref_id": lesson_id,
                    "class_node_id": class_node_id,
                    "subject_id": subject_id,
                    "validated": True,  # déjà is_published=true côté lesson — pas un brouillon
                },
                headers={**_service_headers, "Prefer": "return=representation"},
            )
            if source_res.status_code not in (200, 201) or not source_res.json():
                raise HTTPException(status_code=502, detail="Échec de création de la source RAG.")
            source_id = source_res.json()[0]["id"]

        # 2. Ingestion (une par ré-ingestion — §10 : "réindexation contrôlée et observable").
        ingestion_res = await client.post(
            f"{settings.rest_url}/ai_rag_ingestions",
            json={"source_id": source_id, "status": "processing", "embedding_provider": "gemini-embedding-001"},
            headers={**_service_headers, "Prefer": "return=representation"},
        )
        if ingestion_res.status_code not in (200, 201) or not ingestion_res.json():
            raise HTTPException(status_code=502, detail="Échec de création de l'ingestion RAG.")
        ingestion_id = ingestion_res.json()[0]["id"]

        try:
            texts = [c["text"] for c in chunks]
            embeddings = await generate_embeddings(texts)

            rows = [
                {
                    "ingestion_id": ingestion_id,
                    "source_id": source_id,
                    "chunk_index": i,
                    "content": chunk["text"],
                    "embedding": embedding,
                    "class_node_id": class_node_id,
                    "subject_id": subject_id,
                }
                for i, (chunk, embedding) in enumerate(zip(chunks, embeddings))
            ]
            insert_res = await client.post(
                f"{settings.rest_url}/ai_rag_chunks", json=rows, headers=_service_headers,
            )
            if insert_res.status_code not in (200, 201):
                raise HTTPException(status_code=502, detail=f"Échec d'insertion des chunks : HTTP {insert_res.status_code}")

            await client.patch(
                f"{settings.rest_url}/ai_rag_ingestions",
                params={"id": f"eq.{ingestion_id}"},
                json={
                    "status": "completed",
                    "chunk_count": len(rows),
                    "completed_at": datetime.now(timezone.utc).isoformat(),
                },
                headers=_service_headers,
            )
        except Exception as exc:
            await client.patch(
                f"{settings.rest_url}/ai_rag_ingestions",
                params={"id": f"eq.{ingestion_id}"},
                json={"status": "failed", "error_message": str(exc)[:500]},
                headers=_service_headers,
            )
            raise

    return {"source_id": source_id, "ingestion_id": ingestion_id, "chunk_count": len(chunks)}
