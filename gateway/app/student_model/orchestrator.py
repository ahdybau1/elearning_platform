"""Learning Orchestrator (IA-007, U9 du cahier maître) : recommande la prochaine compétence à
travailler, à partir du Competency Graph (`skills`/`skill_prerequisites`) et du Student Model réel
(`get_mastery_snapshot`). Règle déterministe, pas de LLM — le cahier autorise explicitement une
« sélection mécanique déterministe » (§ RevisionAgent) et aucun Agent Orchestrator (LangGraph) n'existe
encore (différé, voir docs/CONTENT_FACTORY_GAP_ANALYSIS.md) pour justifier davantage ici.
"""
import httpx
from ..config import settings
from .mastery import get_mastery_snapshot

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

MASTERY_THRESHOLD = 0.7  # seuil de "compétence acquise" — pas de justification par benchmark encore
# disponible (aucune donnée réelle en volume), à revoir avec de vraies données comme le reste des
# constantes non benchmarkées de ce projet (voir ai_policies.allowance_units, IA-006).


async def _fetch_skills(subject_id: str) -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/skills",
            params={"subject_id": f"eq.{subject_id}", "select": "id,code,name"},
            headers=_service_headers,
        )
    return res.json() if res.status_code == 200 else []


async def _fetch_prerequisites(skill_ids: list[str]) -> list[dict]:
    if not skill_ids:
        return []
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/skill_prerequisites",
            params={"skill_id": f"in.({','.join(skill_ids)})", "select": "skill_id,prerequisite_skill_id"},
            headers=_service_headers,
        )
    return res.json() if res.status_code == 200 else []


async def recommend_next_skill(profile_id: str, subject_id: str) -> dict | None:
    """Retourne la compétence recommandée ({id, code, name, reason}) ou None si tout est déjà
    maîtrisé (mastery_level >= seuil) ou s'il n'y a aucune compétence enregistrée pour cette matière —
    les deux sont des états honnêtes, jamais une compétence inventée pour ne pas renvoyer None."""
    skills = await _fetch_skills(subject_id)
    if not skills:
        return None

    skill_ids = [s["id"] for s in skills]
    prereqs = await _fetch_prerequisites(skill_ids)
    prereq_map: dict[str, list[str]] = {}
    for p in prereqs:
        prereq_map.setdefault(p["skill_id"], []).append(p["prerequisite_skill_id"])

    mastery_rows = await get_mastery_snapshot(profile_id, subject_id)
    mastery_by_skill = {r["skill_id"]: r for r in mastery_rows}

    def is_mastered(skill_id: str) -> bool:
        row = mastery_by_skill.get(skill_id)
        return bool(row and row.get("mastery_level") is not None and row["mastery_level"] >= MASTERY_THRESHOLD)

    candidates = []
    for sk in skills:
        if is_mastered(sk["id"]):
            continue
        prereq_ids = prereq_map.get(sk["id"], [])
        if all(is_mastered(p) for p in prereq_ids):
            candidates.append(sk)

    if not candidates:
        return None

    # Priorité aux compétences jamais tentées, puis les moins tentées — évite de faire re-travailler
    # sans fin une compétence déjà beaucoup pratiquée pendant qu'une autre attend au même niveau.
    candidates.sort(key=lambda sk: (mastery_by_skill.get(sk["id"], {}).get("attempts_count", 0), sk["code"]))
    chosen = candidates[0]
    prereq_ids = prereq_map.get(chosen["id"], [])
    reason = (
        "Aucun prérequis." if not prereq_ids
        else f"Prérequis {'déjà maîtrisés' if prereq_ids else ''} validés."
    )
    return {"skill_id": chosen["id"], "code": chosen["code"], "name": chosen["name"], "reason": reason}
