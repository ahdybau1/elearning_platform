"""Student Model — lecture (IA-007, U9 du cahier maître).

La maîtrise n'est jamais stockée telle quelle : elle est recalculée à la demande depuis les vraies
tentatives d'exercices (`exercise_attempts`), via la RPC `get_student_skill_mastery` (migration 64).
Voir le commentaire de cette fonction pour le trust model (appel service_role uniquement, autorisation
déjà vérifiée en amont côté Python — `auth.verify_profile_access`).
"""
import httpx
from ..config import settings

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}


async def get_mastery_snapshot(profile_id: str, subject_id: str | None = None) -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.post(
            f"{settings.rest_url}/rpc/get_student_skill_mastery",
            json={"p_profile_id": profile_id, "p_subject_id": subject_id},
            headers=_service_headers,
        )
    if res.status_code != 200:
        return []
    return res.json()


def format_mastery_summary(rows: list[dict]) -> str | None:
    """Résumé textuel court, injecté dans le prompt système du TutorAgent — jamais un chiffre de
    maîtrise inventé : uniquement ce qui est réellement dans `rows` (peut être vide si l'élève n'a
    encore tenté aucun exercice lié à une compétence, ce qui est un état honnête, pas une erreur)."""
    if not rows:
        return None
    parts = []
    for row in sorted(rows, key=lambda r: (r.get("mastery_level") if r.get("mastery_level") is not None else 1)):
        level = row.get("mastery_level")
        level_pct = f"{round(level * 100)}%" if level is not None else "non évalué"
        parts.append(f"- {row['skill_name']} : {level_pct} de réussite sur {row['attempts_count']} tentative(s)")
    return "Suivi réel de l'élève sur cette matière (à utiliser pour adapter le niveau, jamais à réciter tel quel) :\n" + "\n".join(parts)
