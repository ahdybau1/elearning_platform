"""IA-010 "Learning intelligence" — ExamCoachAgent (AIA-AGT-007).

Mission du cahier : « Préparer aux BEPC, Probatoire, Baccalauréat, examens blancs et autres
évaluations configurées. » Tools : « Exam catalog, curriculum, mastery, timer/planning, past-paper
RAG autorisé. » Règles : « Ne prétend pas connaître une future épreuve confidentielle ; distingue
entraînement, prédiction statistique et information officielle. » Sortie : « plan, priorités,
simulations, gestion du temps, lacunes, prochaines actions. »

Différé le 2026-08-29 (migration 71) : « dépend d'un vrai corpus d'épreuves passées exploitable
(exam_papers/official_exams existent en schéma mais leur contenu réel n'a pas été audité pour cette
passe) — à reprendre avec un audit dédié. » Cet audit a eu lieu depuis (Exam Resource Factory,
migrations 73-74, 2026-09-04/05) : `exam_paper_questions` contient maintenant de vraies questions
structurées, jamais publiées sans revue humaine complète (`guard_exam_publication`, migration 74).
C'est ce corpus réel que « simulations » expose ici — jamais un corpus inventé, et jamais une
prédiction de contenu d'épreuve future (règle explicite du cahier).

Autorisation : `exam_paper_questions` reste réservée à `is_admin_user()` (RLS, migration 73). Cet
agent ne la lit JAMAIS directement via service_role — il appelle `read_published_exam_questions`
(migration 74, SECURITY DEFINER), la même RPC que le futur écran élève, qui vérifie déjà classe +
palier d'abonnement (`access_matrix`, feature_key='official_exams') avant de renvoyer quoi que ce
soit. Un refus d'accès (palier insuffisant) est un résultat honnête, pas une erreur à masquer :
l'annale apparaît comme « nécessite un abonnement », jamais silencieusement ignorée ou contournée.
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


async def _fetch_class_node_id(profile_id: str) -> str | None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/profiles",
            params={"id": f"eq.{profile_id}", "select": "class_node_id"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    return rows[0].get("class_node_id") if rows else None


async def _fetch_official_exam(class_node_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/official_exams",
            params={"class_node_id": f"eq.{class_node_id}", "select": "id,name,exam_date"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    return rows[0] if rows else None


async def _fetch_published_papers(exam_id: str, subject_id: str) -> list[dict]:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/exam_papers",
            params={
                "exam_id": f"eq.{exam_id}", "subject_id": f"eq.{subject_id}",
                "processing_status": "eq.published", "select": "id,year",
            },
            headers=_service_headers,
        )
    return res.json() if res.status_code == 200 else []


async def _fetch_approved_questions_via_rpc(user_jwt: str, profile_id: str, exam_paper_id: str) -> list[dict] | None:
    """`None` = accès refusé (palier/classe) — distinct d'une liste vide (sujet publié sans question
    approuvée, cas dégénéré mais honnête). Appelée avec le VRAI JWT de l'élève (comme
    `tutor_agent.py`, pas le service_role) : `read_published_exam_questions` vérifie `auth.uid()`
    elle-même — un appel service_role n'a aucune revendication JWT et échouerait toujours."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.post(
            f"{settings.rest_url}/rpc/read_published_exam_questions",
            json={"p_profile_id": profile_id, "p_exam_paper_id": exam_paper_id},
            headers={
                "Authorization": f"Bearer {user_jwt}",
                "apikey": settings.supabase_anon_key,
                "Content-Type": "application/json",
            },
        )
    if res.status_code != 200:
        return None
    return res.json()


async def build_exam_prep_plan(profile_id: str, subject_id: str, user_jwt: str) -> dict:
    class_node_id = await _fetch_class_node_id(profile_id)
    if not class_node_id:
        return {"exam": None, "lacunes": [], "simulations": [], "next_actions": [], "reason": "Profil introuvable."}

    exam = await _fetch_official_exam(class_node_id)
    if not exam:
        return {
            "exam": None, "lacunes": [], "simulations": [], "next_actions": [],
            "reason": "Aucun examen officiel national ne concerne ce niveau — pas d'entraînement à proposer ici.",
        }

    mastery_rows = await get_mastery_snapshot(profile_id, subject_id)
    lacunes = [
        {
            "skill_id": r["skill_id"], "skill_name": r["skill_name"],
            "mastery_level": r.get("mastery_level"), "attempts_count": r["attempts_count"],
        }
        for r in mastery_rows
        if r.get("mastery_level") is None or r["mastery_level"] < MASTERY_THRESHOLD
    ]
    lacunes.sort(key=lambda r: (r["mastery_level"] if r["mastery_level"] is not None else -1))

    papers = await _fetch_published_papers(exam["id"], subject_id)
    simulations = []
    for paper in papers:
        questions = await _fetch_approved_questions_via_rpc(user_jwt, profile_id, paper["id"])
        if questions is None:
            simulations.append({
                "exam_paper_id": paper["id"], "year": paper["year"], "accessible": False,
                "note": "Nécessite un abonnement incluant les Examens Officiels pour ce niveau.",
            })
        elif questions:
            simulations.append({
                "exam_paper_id": paper["id"], "year": paper["year"], "accessible": True,
                "question_count": len(questions),
                "note": "Annale réellement publiée et revue par un humain — entraînement, pas une prédiction de l'épreuve à venir.",
            })
    simulations.sort(key=lambda s: s["year"], reverse=True)

    next_actions = []
    if lacunes:
        next_actions.append(f"Travailler en priorité « {lacunes[0]['skill_name']} » (compétence la moins maîtrisée).")
    accessible_sims = [s for s in simulations if s.get("accessible")]
    if accessible_sims:
        next_actions.append(f"S'entraîner sur l'annale {accessible_sims[0]['year']} ({accessible_sims[0]['question_count']} question(s) revues).")
    if not next_actions:
        next_actions.append("Aucune lacune détectée et aucune annale accessible pour l'instant — rien à prioriser aujourd'hui.")

    return {
        "exam": {"id": exam["id"], "name": exam["name"], "exam_date": exam.get("exam_date")},
        "lacunes": lacunes,
        "simulations": simulations,
        "next_actions": next_actions,
    }
