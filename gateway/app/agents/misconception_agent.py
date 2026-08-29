"""IA-010 "Learning intelligence" — MisconceptionAgent (AIA-AGT-009).

Mission du cahier : « Détecter des erreurs conceptuelles récurrentes et proposer une remédiation. »
Règle : « Une hypothèse n'est jamais stockée comme vérité définitive ; version/confidence
obligatoires. »

N'invente rien : agrège les `ai_misconceptions` déjà produits par CorrectionAgent (IA-009) sur les
vraies tentatives du profil, groupe les libellés identiques (comparaison textuelle simple — à
l'échelle réelle du projet aujourd'hui, un vrai clustering sémantique serait prématuré, comme le
matcher lexical de CurriculumMappingAgent). `status` reste toujours 'candidate' à l'écriture — la
confirmation/le rejet n'est possible que par un admin (RLS, migration 70), jamais l'agent lui-même.
"""
import httpx
from ..config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

# Nombre de récurrences pour atteindre confidence=1.0 — pas benchmarké (même statut que les autres
# seuils non calibrés de ce projet, IA-006/IA-007/DiagnosticAgent).
_RECURRENCE_FOR_FULL_CONFIDENCE = 3


async def _fetch_attempts_with_misconceptions(profile_id: str) -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/exercise_attempts",
            params={"profile_id": f"eq.{profile_id}", "select": "id,exercise_id,ai_misconceptions"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    return [r for r in rows if r.get("ai_misconceptions")]


async def _resolve_exercise_skills(exercise_ids: list[str], subject_id: str) -> dict[str, str]:
    """exercice -> premier skill_id trouvé DANS la matière demandée (une même erreur, tentée sur un
    exercice hors matière, ne serait de toute façon jamais retournée par le filtre subject_id ici)."""
    if not exercise_ids:
        return {}
    async with httpx.AsyncClient(timeout=10.0) as client:
        links_res = await client.get(
            f"{settings.rest_url}/exercise_skills",
            params={"exercise_id": f"in.({','.join(exercise_ids)})", "select": "exercise_id,skill_id"},
            headers=_service_headers,
        )
    links = links_res.json() if links_res.status_code == 200 else []
    skill_ids = list({l["skill_id"] for l in links})
    if not skill_ids:
        return {}
    async with httpx.AsyncClient(timeout=10.0) as client:
        skills_res = await client.get(
            f"{settings.rest_url}/skills",
            params={"id": f"in.({','.join(skill_ids)})", "subject_id": f"eq.{subject_id}", "select": "id"},
            headers=_service_headers,
        )
    valid_skill_ids = {s["id"] for s in skills_res.json()} if skills_res.status_code == 200 else set()
    exercise_to_skill: dict[str, str] = {}
    for link in links:
        if link["skill_id"] in valid_skill_ids and link["exercise_id"] not in exercise_to_skill:
            exercise_to_skill[link["exercise_id"]] = link["skill_id"]
    return exercise_to_skill


async def _upsert_misconception(profile_id: str, skill_id: str | None, description: str, confidence: float, attempt_ids: list[str]) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.post(
            f"{settings.rest_url}/student_misconceptions",
            params={"on_conflict": "profile_id,skill_id,description"},
            json={
                "profile_id": profile_id, "skill_id": skill_id, "description": description,
                "confidence": confidence, "evidence_attempt_ids": attempt_ids, "status": "candidate",
            },
            headers={**_service_headers, "Prefer": "resolution=merge-duplicates,return=representation"},
        )
    rows = res.json() if res.status_code in (200, 201) else []
    return rows[0] if rows else {
        "profile_id": profile_id, "skill_id": skill_id, "description": description,
        "confidence": confidence, "evidence_attempt_ids": attempt_ids, "status": "candidate",
    }


async def detect_misconceptions(profile_id: str, subject_id: str) -> list[dict]:
    attempts = await _fetch_attempts_with_misconceptions(profile_id)
    if not attempts:
        return []

    exercise_ids = list({a["exercise_id"] for a in attempts})
    exercise_to_skill = await _resolve_exercise_skills(exercise_ids, subject_id)

    groups: dict[tuple[str | None, str], dict] = {}
    for attempt in attempts:
        skill_id = exercise_to_skill.get(attempt["exercise_id"])
        if skill_id is None:
            continue  # tentative hors du périmètre de la matière demandée
        for raw_text in attempt["ai_misconceptions"]:
            key = (skill_id, raw_text.strip().lower())
            group = groups.setdefault(key, {"skill_id": skill_id, "description": raw_text.strip(), "attempt_ids": []})
            group["attempt_ids"].append(attempt["id"])

    results = []
    for group in groups.values():
        confidence = round(min(len(group["attempt_ids"]) / _RECURRENCE_FOR_FULL_CONFIDENCE, 1.0), 3)
        row = await _upsert_misconception(profile_id, group["skill_id"], group["description"], confidence, group["attempt_ids"])
        results.append(row)
    return results
