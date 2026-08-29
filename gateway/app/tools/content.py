"""Tool content (§12, "search_validated_content" du cahier §7 AIA-AGT-001). Ne retourne QUE du
contenu réellement publié (`is_published = true`) et actif (`is_active = true`) — jamais un
brouillon, conforme à la règle RAG §10 "documents non fiables isolés" même si ceci n'est pas encore
branché sur le RAG vectoriel (IA-004 partie 2, pas fait).
"""
import httpx
from ..config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
}

MAX_LIMIT = 20


class ContentToolError(ValueError):
    pass


def _excerpt(content_json: dict, max_chars: int = 400) -> str:
    """Même repli que Lesson.blocks côté student_app (CF-001) : body direct, sinon résumé de la
    structuration IA, sinon un texte honnête plutôt qu'un extrait vide."""
    body = content_json.get("body")
    if isinstance(body, str) and body.strip():
        return body.strip()[:max_chars]
    structured = content_json.get("ai_structured")
    if isinstance(structured, dict):
        summary = structured.get("summary")
        if isinstance(summary, str) and summary.strip():
            return summary.strip()[:max_chars]
    return "(contenu structuré en blocs, pas de résumé texte disponible)"


async def search_validated_content(
    subject_id: str | None = None,
    chapter_id: str | None = None,
    keyword: str | None = None,
    limit: int = 5,
) -> dict:
    if not subject_id and not chapter_id:
        raise ContentToolError("subject_id ou chapter_id requis.")
    limit = max(1, min(limit, MAX_LIMIT))

    async with httpx.AsyncClient(timeout=10.0) as client:
        chapter_ids: list[str] | None = [chapter_id] if chapter_id else None
        if subject_id and not chapter_id:
            res = await client.get(
                f"{settings.rest_url}/chapters",
                params={"subject_id": f"eq.{subject_id}", "select": "id"},
                headers=_service_headers,
            )
            if res.status_code != 200:
                raise ContentToolError("Impossible de résoudre les chapitres de cette matière.")
            chapter_ids = [c["id"] for c in res.json()]
            if not chapter_ids:
                return {"results": []}

        params = {
            "chapter_id": f"in.({','.join(chapter_ids)})",
            "is_published": "eq.true",
            "is_active": "eq.true",
            "select": "id,title,content_json,chapter_id,chapters(title,subjects(name))",
            "limit": str(limit),
        }
        if keyword:
            params["title"] = f"ilike.*{keyword}*"

        res = await client.get(f"{settings.rest_url}/lessons", params=params, headers=_service_headers)
    if res.status_code != 200:
        raise ContentToolError(f"Erreur de lecture des leçons publiées : HTTP {res.status_code}")

    results = []
    for row in res.json():
        chapter = row.get("chapters") or {}
        subject = chapter.get("subjects") or {}
        results.append({
            "lesson_id": row["id"],
            "title": row["title"],
            "chapter_title": chapter.get("title"),
            "subject_name": subject.get("name"),
            "excerpt": _excerpt(row.get("content_json") or {}),
        })
    return {"results": results}
