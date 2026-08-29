"""IA-010 "Learning intelligence" — RecommendationAgent (AIA-AGT-010).

Mission du cahier : « Fournir des candidats/recommandations au Learning Orchestrator. » « Le moteur
déterministe doit fonctionner sans LLM. » Sortie : « activités candidates, score, raisons, contraintes
et alternatives. »

Distinct du Learning Orchestrator (IA-007, `student_model/orchestrator.py`) : celui-ci choisit QUELLE
compétence travailler (niveau Competency Graph) ; RecommendationAgent traduit ce choix en ACTIVITÉS
CONCRÈTES réelles (leçons/exercices déjà en base liés à cette compétence), avec les contraintes réelles
du schéma (palier d'abonnement minimum d'un exercice — `exercises.min_subscription_tier`). Aucune
activité inventée : si rien n'est lié à la compétence recommandée, la liste est honnêtement vide.
"""
import httpx
from ..config import settings
from ..student_model.orchestrator import recommend_next_skill

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}


async def _fetch_lessons_for_skill(skill_id: str) -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        skill_res = await client.get(
            f"{settings.rest_url}/skills", params={"id": f"eq.{skill_id}", "select": "chapter_id"}, headers=_service_headers,
        )
    rows = skill_res.json() if skill_res.status_code == 200 else []
    chapter_id = rows[0].get("chapter_id") if rows else None
    if not chapter_id:
        return []
    async with httpx.AsyncClient(timeout=10.0) as client:
        lessons_res = await client.get(
            f"{settings.rest_url}/lessons",
            params={"chapter_id": f"eq.{chapter_id}", "is_published": "eq.true", "is_active": "eq.true", "select": "id,title"},
            headers=_service_headers,
        )
    return lessons_res.json() if lessons_res.status_code == 200 else []


async def _fetch_exercises_for_skill(skill_id: str, subscription_tier: str | None) -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        links_res = await client.get(
            f"{settings.rest_url}/exercise_skills", params={"skill_id": f"eq.{skill_id}", "select": "exercise_id"}, headers=_service_headers,
        )
    exercise_ids = [row["exercise_id"] for row in links_res.json()] if links_res.status_code == 200 else []
    if not exercise_ids:
        return []
    async with httpx.AsyncClient(timeout=10.0) as client:
        ex_res = await client.get(
            f"{settings.rest_url}/exercises",
            params={"id": f"in.({','.join(exercise_ids)})", "select": "id,title,format,difficulty,min_subscription_tier"},
            headers=_service_headers,
        )
    exercises = ex_res.json() if ex_res.status_code == 200 else []
    # Contrainte réelle (§ interdit du cahier : "ne pas contourner les droits d'abonnement") — un
    # exercice au-dessus du palier du profil est exclu, pas juste signalé.
    _TIER_ORDER = {"gratuit": 0, "journalier": 1, "hebdomadaire": 2, "mensuel": 3, "annuel": 4}
    profile_rank = _TIER_ORDER.get(subscription_tier or "gratuit", 0)
    return [e for e in exercises if _TIER_ORDER.get(e.get("min_subscription_tier") or "gratuit", 0) <= profile_rank]


async def _fetch_subscription_tier(profile_id: str) -> str | None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/profiles", params={"id": f"eq.{profile_id}", "select": "subscription_tier"}, headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    return rows[0].get("subscription_tier") if rows else None


async def recommend_activities(profile_id: str, subject_id: str) -> dict:
    skill = await recommend_next_skill(profile_id, subject_id)
    if not skill:
        return {"skill": None, "candidates": [], "reason": "Aucune compétence à recommander (rien enregistré, ou tout déjà maîtrisé)."}

    subscription_tier = await _fetch_subscription_tier(profile_id)
    lessons = await _fetch_lessons_for_skill(skill["skill_id"])
    exercises = await _fetch_exercises_for_skill(skill["skill_id"], subscription_tier)

    candidates = [
        {"type": "lesson", "id": l["id"], "title": l["title"], "score": 1.0, "reason": f"Leçon du chapitre associé à « {skill['name']} »."}
        for l in lessons
    ] + [
        {
            "type": "exercise", "id": e["id"], "title": e.get("title"), "score": 0.9,
            "reason": f"Exercice ({e.get('format')}, {e.get('difficulty')}) lié à « {skill['name']} », accessible au palier de l'élève.",
        }
        for e in exercises
    ]

    return {"skill": skill, "candidates": candidates, "reason": skill["reason"]}
