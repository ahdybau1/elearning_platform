"""IA-012 "Staff/famille" — ParentInsightAgent (AIA-AGT-019).

Mission du cahier : « Transformer les données autorisées d'un enfant lié en synthèse claire et
actionnable. » Sortie : « progrès, forces, points à travailler, recommandations de soutien, alertes
autorisées. » Règles : « Pas de surveillance punitive ; pas d'accès aux conversations/données privées
non autorisées ; langage compréhensible et non stigmatisant. » LLM : « Résumés peuvent être
pré-calculés ; données source déterministes. »

Autorisation vérifiée EN AMONT (gateway/app/auth.py, `verify_parent_child_access`) : le compte
parent appelant doit avoir un lien réel dans `parent_profile_links` vers ce profil — jamais un
profil arbitraire. Aucune conversation (TutorAgent) ni donnée privée hors Student Model n'est lue
ici : le Student Model (maîtrise par compétence, IA-007) est la seule source, déjà déterministe —
même seuil `MASTERY_THRESHOLD` que le reste du projet pour rester cohérent.
"""
from datetime import datetime, timezone

from ..student_model.mastery import get_mastery_snapshot
from ..student_model.orchestrator import MASTERY_THRESHOLD

INACTIVITY_ALERT_DAYS = 14  # heuristique honnête, non calibrée sur un usage réel en volume.


async def build_parent_insight(profile_id: str, subject_id: str | None = None) -> dict:
    mastery_rows = await get_mastery_snapshot(profile_id, subject_id)
    attempted = [r for r in mastery_rows if (r.get("attempts_count") or 0) > 0]

    if not attempted:
        return {
            "progress_summary": "Aucune activité enregistrée pour l'instant.",
            "strengths": [], "areas_to_support": [], "recommendations": [], "alerts": [],
        }

    strengths = [r for r in attempted if r.get("mastery_level") is not None and r["mastery_level"] >= MASTERY_THRESHOLD]
    areas = [r for r in attempted if r.get("mastery_level") is None or r["mastery_level"] < MASTERY_THRESHOLD]
    total_attempts = sum(r["attempts_count"] for r in attempted)

    recommendations = [
        f"Encourager la pratique régulière sur « {r['skill_name']} » (actuellement {round((r['mastery_level'] or 0) * 100)}% de réussite)."
        for r in sorted(areas, key=lambda r: r.get("mastery_level") or 0)[:3]
    ]

    alerts = []
    last_attempts = [r["last_attempt_at"] for r in attempted if r.get("last_attempt_at")]
    if last_attempts:
        most_recent = max(last_attempts)
        days_since = (datetime.now(timezone.utc) - datetime.fromisoformat(most_recent.replace("Z", "+00:00"))).days
        if days_since >= INACTIVITY_ALERT_DAYS:
            alerts.append(f"Aucune activité depuis {days_since} jour(s).")

    return {
        "progress_summary": f"{len(attempted)} compétence(s) travaillée(s), {total_attempts} exercice(s) tenté(s) au total.",
        "strengths": [
            {"skill_id": r["skill_id"], "skill_name": r["skill_name"], "mastery_level": r["mastery_level"]}
            for r in strengths
        ],
        "areas_to_support": [
            {"skill_id": r["skill_id"], "skill_name": r["skill_name"], "mastery_level": r["mastery_level"]}
            for r in areas
        ],
        "recommendations": recommendations,
        "alerts": alerts,
    }
