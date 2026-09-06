"""IA-012 "Staff/famille" — TeacherAssistantAgent (AIA-AGT-018).

Mission du cahier : « Aider enseignants/auteurs à préparer cours, exercices, corrections, plans,
feedbacks et analyses de cohorte dans leur scope. » Règles : « Respect strict du scope enseignant ;
pas d'accès global aux élèves ; toute publication suit workflow. »

Scope v1, délibérément restreint aux « analyses de cohorte » — les autres capacités listées
(préparer cours/exercices/corrections) existent déjà comme agents séparés et enregistrés
(CourseGenerator/ExerciseAgent/CorrectionAgent) ; les dupliquer ici n'ajouterait aucune valeur.
L'analyse de cohorte (moyenne de maîtrise par compétence sur une classe entière) n'existe nulle
part ailleurs — c'est le vrai apport de cet agent.

Scope enseignant réel : `teacher_establishments.classes_scope`/`subjects_scope` (migration 03,
JSONB). Un `admin_role='enseignant'` ne peut demander une cohorte que pour une classe+matière
réellement dans son périmètre déclaré — vérifié ici, PAS seulement côté UI. Les autres rôles admin
(super_admin/admin_pays/admin_contenu) ont déjà une visibilité plus large ailleurs dans admin_app et
ne sont pas restreints par ce scope.

Limite de performance honnête : agrège via N appels à `get_student_skill_mastery` (un par élève de
la classe) faute de RPC d'agrégation dédiée — acceptable pour une classe (dizaines d'élèves), pas
benchmarké au-delà.
"""
import httpx
from ..config import settings
from ..student_model.mastery import get_mastery_snapshot
from ..student_model.orchestrator import MASTERY_THRESHOLD

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}


class TeacherScopeError(ValueError):
    pass


async def _fetch_teacher_scope(admin_user_id: str) -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/teacher_establishments",
            params={"teacher_id": f"eq.{admin_user_id}", "select": "classes_scope,subjects_scope"},
            headers=_service_headers,
        )
    return res.json() if res.status_code == 200 else []


def _in_scope(class_node_id: str, subject_id: str, scope_rows: list[dict]) -> bool:
    return any(
        class_node_id in (row.get("classes_scope") or []) and subject_id in (row.get("subjects_scope") or [])
        for row in scope_rows
    )


async def _fetch_active_profile_ids(class_node_id: str) -> list[str]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/profiles",
            params={"class_node_id": f"eq.{class_node_id}", "status": "eq.actif", "select": "id"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    return [r["id"] for r in rows]


async def build_cohort_summary(admin_user_id: str, admin_role: str, class_node_id: str, subject_id: str) -> dict:
    if admin_role == "enseignant":
        scope_rows = await _fetch_teacher_scope(admin_user_id)
        if not _in_scope(class_node_id, subject_id, scope_rows):
            raise TeacherScopeError("Cette classe/matière n'est pas dans votre périmètre déclaré.")

    profile_ids = await _fetch_active_profile_ids(class_node_id)
    if not profile_ids:
        return {"class_node_id": class_node_id, "subject_id": subject_id, "students_count": 0, "skills": [], "reason": "Aucun élève actif dans cette classe."}

    per_skill: dict[str, dict] = {}
    for profile_id in profile_ids:
        rows = await get_mastery_snapshot(profile_id, subject_id)
        for r in rows:
            if not r.get("attempts_count"):
                continue
            entry = per_skill.setdefault(r["skill_id"], {"skill_name": r["skill_name"], "levels": [], "struggling_count": 0})
            level = r.get("mastery_level")
            if level is not None:
                entry["levels"].append(level)
                if level < MASTERY_THRESHOLD:
                    entry["struggling_count"] += 1

    skills = [
        {
            "skill_id": skill_id, "skill_name": data["skill_name"],
            "average_mastery": round(sum(data["levels"]) / len(data["levels"]), 3) if data["levels"] else None,
            "students_attempted": len(data["levels"]), "students_struggling": data["struggling_count"],
        }
        for skill_id, data in per_skill.items()
    ]
    skills.sort(key=lambda s: (s["average_mastery"] if s["average_mastery"] is not None else 1))

    return {"class_node_id": class_node_id, "subject_id": subject_id, "students_count": len(profile_ids), "skills": skills}
