"""IA-009 — CorrectionAgent (AIA-AGT-005, docs/CAHIER_DES_CHARGES_AGENTS_IA.md §7/§22).

Mission du cahier : « Corriger une tentative à partir d'une solution/barème versionné et expliquer les
erreurs. » Règle explicite : « Séparer machine_score, confidence, feedback et official_grade. Une note
officielle nécessitant validation humaine ne peut être écrite directement. »

Ne traite que les réponses rédigées (reponse_courte/redaction) — le QCM a déjà une correction
déterministe exacte (comparaison d'index côté client), CorrectionAgent n'y ajouterait rien et
introduirait un risque d'erreur là où il n'y en avait aucun.

N'écrit JAMAIS `official_correct` (colonne réservée à un admin, RLS migration 68) — seulement les
champs `ai_*`, une proposition, jamais une vérité.
"""
import json
import re

import httpx
from ..config import settings
from ..model_router.router import route_generate

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

_CORRECTABLE_FORMATS = {"reponse_courte", "redaction"}
_JSON_BLOCK_RE = re.compile(r"\{.*\}", re.DOTALL)


class CorrectionAgentError(ValueError):
    pass


async def _fetch_attempt(attempt_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/exercise_attempts",
            params={"id": f"eq.{attempt_id}", "select": "id,exercise_id,submitted_answer"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    return rows[0] if rows else None


async def _fetch_exercise(exercise_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/exercises",
            params={"id": f"eq.{exercise_id}", "select": "format,instructions_json,solution_json"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    return rows[0] if rows else None


def _parse_llm_json(text: str) -> dict:
    """`ai-generate-text` ne force pas responseMimeType=application/json (texte libre, utilisé par
    d'autres capacités) — parsing défensif : essai direct, puis extraction du premier bloc {...}."""
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        match = _JSON_BLOCK_RE.search(text)
        if not match:
            raise CorrectionAgentError(f"Réponse du modèle non-JSON, aucun bloc {{...}} trouvé : {text[:200]}")
        return json.loads(match.group(0))


async def _write_ai_fields(attempt_id: str, result: dict) -> None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        await client.patch(
            f"{settings.rest_url}/exercise_attempts",
            params={"id": f"eq.{attempt_id}"},
            json={
                "ai_score": result["ai_score"],
                "ai_confidence": result["ai_confidence"],
                "ai_feedback": result["ai_feedback"],
                "ai_misconceptions": result["ai_misconceptions"],
                "needs_human_review": result["needs_human_review"],
            },
            headers=_service_headers,
        )


async def correct_attempt(attempt_id: str) -> dict:
    attempt = await _fetch_attempt(attempt_id)
    if not attempt:
        raise CorrectionAgentError(f"Tentative introuvable : {attempt_id}")

    exercise = await _fetch_exercise(attempt["exercise_id"])
    if not exercise:
        raise CorrectionAgentError(f"Exercice introuvable pour la tentative {attempt_id}.")
    if exercise["format"] not in _CORRECTABLE_FORMATS:
        raise CorrectionAgentError(
            f"CorrectionAgent ne traite que {sorted(_CORRECTABLE_FORMATS)} — format='{exercise['format']}' a déjà une correction déterministe."
        )

    submitted_text = ((attempt.get("submitted_answer") or {}).get("text") or "").strip()
    statement = (exercise.get("instructions_json") or {}).get("statement", "")
    reference_correction = (exercise.get("solution_json") or {}).get("correction", "")

    if not submitted_text:
        result = {
            "ai_score": 0.0, "ai_confidence": 1.0, "ai_feedback": "Aucune réponse soumise.",
            "ai_misconceptions": [], "needs_human_review": False,
        }
    else:
        prompt = f"""Énoncé de l'exercice :
{statement}

Corrigé de référence (barème) :
{reference_correction}

Réponse soumise par l'élève :
{submitted_text}

Évalue cette réponse par rapport au corrigé de référence, comme un correcteur bienveillant mais rigoureux.
Réponds en JSON strict, rien d'autre :
{{"score": <0.0 à 1.0>, "confidence": <0.0 à 1.0>, "feedback": "<explication pédagogique brève, en français, orientée élève>", "misconceptions": ["<erreur conceptuelle identifiée, si il y en a>"], "needs_review": <true si la réponse est ambiguë, partiellement correcte de façon non triviale, ou si ta confiance est faible>}}"""
        generation = await route_generate(capability="pedagogy_small", user_prompt=prompt, max_tokens=1024)
        parsed = _parse_llm_json(generation["text"])
        result = {
            "ai_score": float(parsed.get("score", 0.0)),
            "ai_confidence": float(parsed.get("confidence", 0.0)),
            "ai_feedback": str(parsed.get("feedback", "")),
            "ai_misconceptions": list(parsed.get("misconceptions") or []),
            "needs_human_review": bool(parsed.get("needs_review", True)),  # défaut prudent : à revoir si absent
        }

    await _write_ai_fields(attempt_id, result)
    return result
