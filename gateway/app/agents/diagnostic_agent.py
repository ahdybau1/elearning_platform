"""IA-010 "Learning intelligence" (docs/CAHIER_DES_CHARGES_AGENTS_IA.md §7/§22) — DiagnosticAgent
(AIA-AGT-008).

Mission du cahier : « Estimer les compétences acquises/manquantes à partir de preuves diagnostiques. »
« LLM non obligatoire pour scoring ; règles/IRT/BKT ou moteur validé privilégiés. » Sortie attendue :
« skill estimates + confidence + evidence IDs + next diagnostic action. »

Implémentation honnête : pas d'IRT/BKT (modèles psychométriques — hors périmètre d'un vertical slice,
aucune donnée réelle en volume pour les calibrer). `estimate` = mastery_level déjà réel
(get_student_skill_mastery, IA-007) ; `confidence` = fonction simple et déclarée du nombre de
tentatives (plus de preuves = plus confiant dans l'estimation) ; `evidence` = les vrais IDs de
`exercise_attempts`, jamais une preuve inventée. `next_diagnostic_action` diffère du Learning
Orchestrator (IA-007, qui recommande quoi PRATIQUER) : ici, quelle compétence manque le plus de
PREUVES pour être diagnostiquée avec confiance.
"""
import httpx
from ..config import settings
from ..student_model.mastery import get_mastery_snapshot

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

# En dessous de ce nombre de tentatives, l'estimation est considérée insuffisamment étayée pour être
# fiable — pas benchmarké (même statut que le seuil de maîtrise IA-007 ou les quotas IA-006 : une
# valeur de départ raisonnable, à ajuster avec de vraies données).
_MIN_EVIDENCE_FOR_CONFIDENCE = 5


async def _fetch_evidence_attempt_ids(profile_id: str, skill_id: str) -> list[str]:
    """exercise_attempts n'a pas de FK directe vers exercise_skills (elles partagent seulement
    exercise_id via exercises) — PostgREST ne peut pas les embarquer en une requête, donc deux appels
    simples plutôt qu'une jointure PostgREST qui ne peut pas s'exprimer ici."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        skills_res = await client.get(
            f"{settings.rest_url}/exercise_skills",
            params={"skill_id": f"eq.{skill_id}", "select": "exercise_id"},
            headers=_service_headers,
        )
    exercise_ids = [row["exercise_id"] for row in skills_res.json()] if skills_res.status_code == 200 else []
    if not exercise_ids:
        return []
    async with httpx.AsyncClient(timeout=10.0) as client:
        attempts_res = await client.get(
            f"{settings.rest_url}/exercise_attempts",
            params={
                "profile_id": f"eq.{profile_id}",
                "exercise_id": f"in.({','.join(exercise_ids)})",
                "select": "id",
            },
            headers=_service_headers,
        )
    return [row["id"] for row in attempts_res.json()] if attempts_res.status_code == 200 else []


async def diagnose(profile_id: str, subject_id: str) -> dict:
    mastery_rows = await get_mastery_snapshot(profile_id, subject_id)

    skill_estimates = []
    for row in mastery_rows:
        evidence_ids = await _fetch_evidence_attempt_ids(profile_id, row["skill_id"])
        attempts_count = row.get("attempts_count") or 0
        confidence = round(min(attempts_count / _MIN_EVIDENCE_FOR_CONFIDENCE, 1.0), 3)
        skill_estimates.append({
            "skill_id": row["skill_id"],
            "skill_name": row["skill_name"],
            "estimate": row.get("mastery_level"),
            "confidence": confidence,
            "evidence_attempt_ids": evidence_ids,
        })

    # Prochaine action diagnostique : la compétence avec le MOINS de preuves (confidence la plus
    # faible) parmi celles déjà tentées au moins une fois — inutile de diagnostiquer une compétence
    # jamais abordée, ce n'est pas un manque de preuve mais une absence d'activité.
    under_evidenced = [s for s in skill_estimates if s["confidence"] < 1.0]
    next_action = None
    if under_evidenced:
        under_evidenced.sort(key=lambda s: s["confidence"])
        target = under_evidenced[0]
        next_action = {
            "skill_id": target["skill_id"], "skill_name": target["skill_name"],
            "reason": f"Seulement {len(target['evidence_attempt_ids'])} tentative(s) — estimation encore peu fiable.",
        }

    return {"skill_estimates": skill_estimates, "next_diagnostic_action": next_action}
