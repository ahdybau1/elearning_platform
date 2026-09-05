"""IA-010 "Learning intelligence" — RevisionAgent (AIA-AGT-006).

Mission du cahier : « Construire une séance de révision selon maîtrise, oubli estimé, échéances et
temps disponible. » Tools : « Student Model, spaced-repetition engine, Learning Orchestrator, content
catalog. » LLM facultatif — « sélection mécanique déterministe possible. » Sortie : « Plan ordonné
d'activités avec raison de chaque choix. »

Différé le 2026-08-29 (migration 71) : « nécessite un modèle d'oubli — aucune constante réelle
calibrable sans historique d'usage en volume. » Repris ici avec le même principe déjà accepté ailleurs
dans ce projet pour une contrainte identique (`MASTERY_THRESHOLD` dans `student_model/orchestrator.py`
: un seuil raisonnable, honnêtement documenté comme non calibré sur des données réelles, à revoir
quand l'historique existera) — refuser de livrer une heuristique honnête pour cette seule raison
serait incohérent avec le reste du code déjà en production.

Modèle d'oubli : décroissance exponentielle simple (demi-vie `DECAY_HALFLIFE_DAYS`) appliquée à la
maîtrise réelle (`get_student_skill_mastery`, IA-007) — plus une compétence est ancienne ET peu
maîtrisée, plus son risque d'oubli estimé est élevé. Seules les compétences DÉJÀ tentées au moins une
fois sont éligibles (une compétence jamais travaillée relève du Learning Orchestrator — IA-007 — pas
de la révision, qui suppose un acquis à entretenir, pas un acquis à construire).

« Échéances » (deadlines d'examen) : non intégré ici — dépend d'ExamCoachAgent (AIA-AGT-007,
également construit dans cette passe), qui connaît le calendrier des examens officiels. Composer les
deux agents est une extension naturelle, pas construite dans cette version pour ne pas dupliquer la
connaissance du calendrier d'examen dans deux agents.
"""
import math
from datetime import datetime, timezone

from .recommendation_agent import (
    _fetch_exercises_for_skill,
    _fetch_lessons_for_skill,
    _fetch_subscription_tier,
)
from ..student_model.mastery import get_mastery_snapshot

DECAY_HALFLIFE_DAYS = 7.0  # voir docstring : heuristique honnête, à recalibrer avec de l'usage réel.
MINUTES_PER_EXERCISE = 8  # estimation grossière et documentée comme telle, pas mesurée.
MINUTES_PER_LESSON = 12


def _forgetting_risk(mastery_level: float | None, last_attempt_at: str | None) -> float:
    """0.0 (rien à réviser / pas de preuve) à 1.0 (oubli quasi certain). Jamais calculé pour une
    compétence jamais tentée — voir docstring du module."""
    if mastery_level is None or not last_attempt_at:
        return 0.0
    last = datetime.fromisoformat(last_attempt_at.replace("Z", "+00:00"))
    days_elapsed = max((datetime.now(timezone.utc) - last).total_seconds() / 86400.0, 0.0)
    estimated_retention = float(mastery_level) * math.pow(0.5, days_elapsed / DECAY_HALFLIFE_DAYS)
    return round(1.0 - estimated_retention, 3)


async def build_revision_session(profile_id: str, subject_id: str, available_minutes: int = 30) -> dict:
    mastery_rows = await get_mastery_snapshot(profile_id, subject_id)
    attempted = [r for r in mastery_rows if (r.get("attempts_count") or 0) > 0 and r.get("last_attempt_at")]
    if not attempted:
        return {
            "plan": [], "total_minutes": 0, "available_minutes": available_minutes,
            "reason": "Aucune compétence déjà travaillée sur cette matière — rien à réviser pour l'instant (voir le Learning Orchestrator pour découvrir de nouvelles compétences).",
        }

    for row in attempted:
        row["forgetting_risk"] = _forgetting_risk(row.get("mastery_level"), row.get("last_attempt_at"))
    attempted.sort(key=lambda r: r["forgetting_risk"], reverse=True)

    subscription_tier = await _fetch_subscription_tier(profile_id)
    plan: list[dict] = []
    minutes_used = 0

    for row in attempted:
        if minutes_used >= available_minutes:
            break
        days_ago = round((datetime.now(timezone.utc) - datetime.fromisoformat(row["last_attempt_at"].replace("Z", "+00:00"))).total_seconds() / 86400.0)
        risk_pct = round(row["forgetting_risk"] * 100)
        reason = f"Risque d'oubli estimé à {risk_pct}% sur « {row['skill_name']} » (dernière tentative il y a {days_ago} jour(s))."

        exercises = await _fetch_exercises_for_skill(row["skill_id"], subscription_tier)
        if exercises:
            cost = MINUTES_PER_EXERCISE
            if minutes_used + cost > available_minutes and plan:
                break
            ex = exercises[0]
            plan.append({
                "type": "exercise", "id": ex["id"], "title": ex.get("title"),
                "skill_id": row["skill_id"], "skill_name": row["skill_name"],
                "forgetting_risk": row["forgetting_risk"], "estimated_minutes": cost, "reason": reason,
            })
            minutes_used += cost
            continue

        lessons = await _fetch_lessons_for_skill(row["skill_id"])
        if lessons:
            cost = MINUTES_PER_LESSON
            if minutes_used + cost > available_minutes and plan:
                break
            lesson = lessons[0]
            plan.append({
                "type": "lesson", "id": lesson["id"], "title": lesson.get("title"),
                "skill_id": row["skill_id"], "skill_name": row["skill_name"],
                "forgetting_risk": row["forgetting_risk"], "estimated_minutes": cost, "reason": reason,
            })
            minutes_used += cost

    return {"plan": plan, "total_minutes": minutes_used, "available_minutes": available_minutes}
