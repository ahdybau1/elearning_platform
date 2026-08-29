"""IA-008 — PedagogicalValidationAgent (AIA-AGT-024, docs/CAHIER_DES_CHARGES_AGENTS_IA.md §7/§22).

Mission du cahier : « Précontrôler exactitude, alignement curriculum, niveau, structure,
accessibilité, citations, sécurité et cohérence d'un contenu. » Règle explicite : « C'est un
pré-validateur ; la publication humaine reste requise. » — ce module ne publie ni ne bloque jamais
rien lui-même, il produit un rapport que `validation_queue` (déjà existant) peut afficher.

Honnête sur la couverture réelle vs la liste complète de tools du cahier (« Curriculum, RAG, exact
solvers, schema validators, accessibility checks, duplicate/plagiarism-like internal checks ») :
implémentés ici = rattachement curriculaire (schéma réel), structure des blocs (schema validator),
détection de contenu factice/mock (spécifique à ce projet — trouvé lors d'IA-007), tentative
best-effort de validation symbolique des formules (exact solver, non bloquant — beaucoup de LaTeX
pédagogique n'est pas du SymPy valide, c'est attendu). PAS implémentés : RAG (pas de vérification de
citation contre une source), accessibilité fine (alt-text), détection de plagiat — différés, à ajouter
si un vrai besoin se présente plutôt que construits par anticipation.
"""
import httpx
from ..config import settings
from ..tools.math_tools import MathToolError, sympy_solve

_service_headers = {
    "Authorization": f"Bearer {settings.supabase_service_role_key}",
    "apikey": settings.supabase_service_role_key,
    "Content-Type": "application/json",
}

_SUBSTANTIVE_TYPES = {"definition", "theoreme", "methode"}
_MOCK_MARKERS = ("factice", "remplacez par un contenu réel", "mock")


async def _fetch_lesson(lesson_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/lessons",
            params={"id": f"eq.{lesson_id}", "select": "id,title,content_json,is_published,is_active,chapter_id"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    return rows[0] if rows else None


def _blocks_from_content(content_json: dict) -> list[dict]:
    """Même chaîne de résolution que le reste du projet (Dart `Lesson.blocks`, Python RAG chunking) :
    blocks natifs -> ai_structured.sections -> rien (jamais le `body` texte brut ici, une validation
    de structure sur du texte plat n'a pas de sens — un `body` seul déclenche juste l'erreur
    "aucun bloc structuré", ce qui est le signal correct)."""
    blocks = content_json.get("blocks")
    if isinstance(blocks, list) and blocks:
        return blocks
    ai_structured = content_json.get("ai_structured")
    if isinstance(ai_structured, dict) and isinstance(ai_structured.get("sections"), list):
        return ai_structured["sections"]
    return []


def _check_structure(blocks: list[dict]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    if not blocks:
        errors.append("Aucun bloc de contenu structuré trouvé (ni `blocks`, ni `ai_structured.sections`).")
        return errors, warnings
    types = {b.get("type") for b in blocks}
    if not (types & _SUBSTANTIVE_TYPES):
        warnings.append(f"Aucun bloc de fond ({sorted(_SUBSTANTIVE_TYPES)}) — leçon peut-être trop superficielle.")
    for i, b in enumerate(blocks):
        if not (b.get("body") or "").strip():
            errors.append(f"Bloc #{i} (type={b.get('type')}) a un corps vide.")
    return errors, warnings


def _check_mock_content(content_json: dict, blocks: list[dict]) -> list[str]:
    warnings = []
    if isinstance(content_json.get("ai_structured"), dict) and content_json["ai_structured"].get("_mock"):
        warnings.append("Contenu marqué comme MOCK de développement (`_mock: true`) — ne doit pas être publié tel quel.")
    for b in blocks:
        body_lower = (b.get("body") or "").lower()
        if any(marker in body_lower for marker in _MOCK_MARKERS):
            warnings.append("Un bloc contient un marqueur de contenu factice/placeholder — probable contenu de test.")
            break
    return warnings


def _check_formulas(blocks: list[dict]) -> list[str]:
    """Best-effort, jamais bloquant : beaucoup de LaTeX pédagogique légitime (fractions \\frac,
    indices, \\Delta...) n'est pas une expression SymPy valide — un rejet par sympy_solve n'est donc
    PAS traité comme une erreur, seulement noté comme "non vérifiable automatiquement"."""
    warnings = []
    unverifiable = 0
    total = 0
    for b in blocks:
        for f in (b.get("formulas") or b.get("latex_formulas") or []):
            total += 1
            candidate = f.strip().strip("$")
            try:
                sympy_solve(expression=candidate, mode="simplify")
            except MathToolError:
                unverifiable += 1
    if total and unverifiable == total:
        warnings.append(f"{total} formule(s) présente(s), aucune vérifiable automatiquement par SymPy (syntaxe LaTeX complexe — normal, pas bloquant).")
    return warnings


async def _check_curriculum_link(lesson: dict) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    chapter_id = lesson.get("chapter_id")
    if not chapter_id:
        errors.append("Leçon sans `chapter_id` — aucun rattachement curriculaire.")
        return errors, warnings
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(
            f"{settings.rest_url}/chapters",
            params={"id": f"eq.{chapter_id}", "select": "id,subject_id,class_node_id"},
            headers=_service_headers,
        )
    rows = res.json() if res.status_code == 200 else []
    if not rows:
        errors.append("`chapter_id` référence un chapitre introuvable (intégrité rompue).")
    elif not rows[0].get("subject_id") or not rows[0].get("class_node_id"):
        warnings.append("Chapitre rattaché mais incomplet (subject_id ou class_node_id manquant).")
    return errors, warnings


async def validate_lesson(lesson_id: str) -> dict:
    lesson = await _fetch_lesson(lesson_id)
    if not lesson:
        return {
            "checklist": [], "errors": [f"Leçon introuvable : {lesson_id}"], "warnings": [],
            "blocking_issues": [f"Leçon introuvable : {lesson_id}"], "confidence": 0.0,
        }

    content_json = lesson.get("content_json") or {}
    blocks = _blocks_from_content(content_json)

    struct_errors, struct_warnings = _check_structure(blocks)
    mock_warnings = _check_mock_content(content_json, blocks)
    formula_warnings = _check_formulas(blocks)
    curriculum_errors, curriculum_warnings = await _check_curriculum_link(lesson)

    errors = struct_errors + curriculum_errors
    warnings = struct_warnings + mock_warnings + formula_warnings + curriculum_warnings

    blocking_issues = list(errors)
    if lesson.get("is_published") and mock_warnings:
        blocking_issues.append("Contenu factice détecté sur une leçon DÉJÀ PUBLIÉE — revue urgente recommandée.")

    checklist = [
        {"check": "structure_blocs", "passed": not struct_errors},
        {"check": "contenu_non_factice", "passed": not mock_warnings},
        {"check": "rattachement_curriculaire", "passed": not curriculum_errors},
    ]
    confidence = round(sum(1 for c in checklist if c["passed"]) / len(checklist), 3)

    return {"checklist": checklist, "errors": errors, "warnings": warnings, "blocking_issues": blocking_issues, "confidence": confidence}
