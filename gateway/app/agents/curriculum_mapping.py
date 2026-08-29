"""IA-008 — CurriculumMappingAgent (AIA-AGT-017, docs/CAHIER_DES_CHARGES_AGENTS_IA.md §7/§22).

Mission du cahier : « Proposer le rattachement d'un contenu aux pays/versions/classes/séries/
matières/chapitres/leçons/compétences. » Tools attendus : Curriculum Graph, semantic search, taxonomy
matcher — implémentés ici avec ce qui existe réellement : `match_rag_chunks` (IA-004, recherche
sémantique sur le corpus déjà ingéré) + un matcher lexical simple sur `chapters`/`skills` (échelle
réelle du projet aujourd'hui : 3 chapitres, 3 compétences — un matcher plein texte/pg_trgm serait de
l'ingénierie prématurée à ce volume, à revoir si le catalogue grossit).

Ne modifie jamais un rattachement existant lui-même — produit des candidats + confiance + preuve,
HITL (`needs_human_review`) explicite quand c'est ambigu, conformément à la règle du cahier.
"""
import re
import unicodedata

import httpx
from ..config import settings
from ..rag.embeddings_client import generate_embeddings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

_WORD_RE = re.compile(r"[a-zA-ZÀ-ÖØ-öø-ÿ]{4,}")


def _strip_accents(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")


# Normalisés sans accent au chargement (voir _strip_accents ci-dessus) pour rester cohérents avec la
# normalisation appliquée à tout texte comparé — sinon "être" (accentué ici) ne matcherait plus jamais
# "etre" (texte d'entrée normalisé), ce qui aurait réintroduit le même bug que "theoremes"/"théorèmes".
_STOPWORDS = {
    _strip_accents(w) for w in (
        "les", "des", "une", "un", "le", "la", "de", "du", "et", "ou", "dans", "pour", "avec", "sur",
        "au", "aux", "est", "sont", "que", "qui", "ce", "ces", "cette", "son", "sa", "ses", "leur",
        "leurs", "être", "avoir", "plus", "tout", "tous", "toute", "toutes", "comme", "sans", "vers",
    )
}

# Sous ce seuil de confiance (ou un écart trop faible entre le 1er et le 2e candidat), le mapping est
# considéré ambigu — HITL obligatoire (§ CurriculumMappingAgent : "Mapping ambigu ou à fort impact
# soumis au responsable pédagogique"). Non benchmarké (comme les seuils de mastery IA-007/quotas
# IA-006) : à ajuster avec de vraies données de correction humaine plus tard.
_CONFIDENCE_THRESHOLD = 0.3
_AMBIGUITY_GAP = 0.1


def _significant_words(text: str) -> set[str]:
    """Sans repli sans accent, 'theoremes' (saisie élève typique) ne matcherait jamais 'théorèmes'
    (nom réel de la compétence en base) — bug trouvé en testant IA-008 avec une vraie requête."""
    normalized = _strip_accents(text.lower())
    return {w for w in _WORD_RE.findall(normalized) if w not in _STOPWORDS}


def _keyword_score(input_words: set[str], candidate_text: str) -> float:
    cand_words = _significant_words(candidate_text)
    if not cand_words:
        return 0.0
    return len(input_words & cand_words) / len(cand_words)


async def _fetch_chapters() -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/chapters",
            params={"select": "id,title,subject_id,class_node_id"},
            headers=_service_headers,
        )
    return res.json() if res.status_code == 200 else []


async def _fetch_skills() -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/skills",
            params={"select": "id,name,subject_id"},
            headers=_service_headers,
        )
    return res.json() if res.status_code == 200 else []


async def _semantic_chapter_candidates(text: str, top_k: int = 5) -> list[dict]:
    """Recherche sémantique sur le corpus RAG déjà ingéré (IA-004) — match_rag_chunks ne renvoie pas
    subject_id/class_node_id par chunk (contrat existant de rag_search, non modifié ici), donc résolus
    séparément depuis ai_rag_chunks, comme rag_search résout déjà les titres de source."""
    embeddings = await generate_embeddings([text[:2000]])
    query_embedding = embeddings[0]
    async with httpx.AsyncClient(timeout=15.0) as client:
        res = await client.post(
            f"{settings.rest_url}/rpc/match_rag_chunks",
            json={"query_embedding": query_embedding, "match_class_node_id": None, "match_subject_id": None, "match_count": top_k},
            headers=_service_headers,
        )
    matches = res.json() if res.status_code == 200 else []
    if not matches:
        return []
    chunk_ids = [m["id"] for m in matches]
    async with httpx.AsyncClient(timeout=15.0) as client:
        chunks_res = await client.get(
            f"{settings.rest_url}/ai_rag_chunks",
            params={"id": f"in.({','.join(chunk_ids)})", "select": "id,subject_id,class_node_id"},
            headers=_service_headers,
        )
    scope_by_chunk = {c["id"]: c for c in chunks_res.json()} if chunks_res.status_code == 200 else {}

    candidates = []
    for m in matches:
        scope = scope_by_chunk.get(m["id"], {})
        if scope.get("subject_id"):
            candidates.append({
                "chapter_id": None, "subject_id": scope["subject_id"], "class_node_id": scope.get("class_node_id"),
                "confidence": round(m["similarity"], 3),
                "evidence": f"Similarité sémantique avec un contenu déjà validé : « {m['content'][:150]}… »",
                "method": "semantic_rag",
            })
    return candidates


async def map_content(text: str) -> dict:
    if not text or not text.strip():
        return {"chapter_candidates": [], "skill_candidates": [], "needs_human_review": True, "reason": "Texte vide."}

    input_words = _significant_words(text)
    chapters = await _fetch_chapters()
    skills = await _fetch_skills()

    chapter_candidates = [
        {
            "chapter_id": ch["id"], "subject_id": ch["subject_id"], "class_node_id": ch["class_node_id"],
            "confidence": round(score, 3), "evidence": f"Chevauchement lexical avec le titre « {ch['title']} ».",
            "method": "keyword",
        }
        for ch in chapters
        if (score := _keyword_score(input_words, ch["title"])) > 0
    ]
    chapter_candidates += await _semantic_chapter_candidates(text)
    chapter_candidates.sort(key=lambda c: c["confidence"], reverse=True)

    skill_candidates = [
        {
            "skill_id": sk["id"], "subject_id": sk["subject_id"], "confidence": round(score, 3),
            "evidence": f"Chevauchement lexical avec la compétence « {sk['name']} ».", "method": "keyword",
        }
        for sk in skills
        if (score := _keyword_score(input_words, sk["name"])) > 0
    ]
    skill_candidates.sort(key=lambda c: c["confidence"], reverse=True)

    top = chapter_candidates[0]["confidence"] if chapter_candidates else 0.0
    second = chapter_candidates[1]["confidence"] if len(chapter_candidates) > 1 else 0.0
    needs_human_review = (not chapter_candidates) or top < _CONFIDENCE_THRESHOLD or (top - second) < _AMBIGUITY_GAP

    return {
        "chapter_candidates": chapter_candidates[:5],
        "skill_candidates": skill_candidates[:5],
        "needs_human_review": needs_human_review,
    }
