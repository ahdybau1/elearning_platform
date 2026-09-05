"""IA-008 "Content Factory agents" — FormulaRecognitionAgent (AIA-AGT-015).

Mission du cahier : « Reconnaître formules imprimées/manuscrites et produire une représentation
structurée (LaTeX/AST) vérifiable. » Sortie : « formule, confidence, parse status, semantic
validation. » Règle : « Toute formule utilisée pour correction/calcul doit être parsée/validée ou
envoyée en revue. »

Périmètre réel, honnêtement limité (pas de raccourci silencieux) : aucun moteur de reconnaissance
VISUELLE de formule manuscrite n'existe sur ce projet — il dépendait d'OCRAgent, longtemps différé
(migration 67) faute d'infra OpenCV/PaddleOCR. OCRAgent existe maintenant (AIA-AGT-014,
ai-exam-paper-processing, vision Gemini, migration 75) et transcrit déjà les formules en LaTeX au
mieux de son prompt — une formule candidate arrive donc ici comme TEXTE déjà transcrit, jamais comme
image. Le travail réel de cet agent est de PARSER et VALIDER SÉMANTIQUEMENT ce texte via SymPy
(moteur exact, jamais le LLM — même règle que math_tools.py, réutilisé tel quel, y compris ses
défenses contre l'injection de code trouvées le 2026-08-29). `confidence` n'est donc jamais une
probabilité inventée : 1.0 si la formule parse et est sémantiquement valide, 0.0 sinon — un échec de
parsing est TOUJOURS renvoyé avec `needs_review: true` (jamais accepté silencieusement), conformément
à la règle du cahier.
"""
from ..tools.math_tools import MathToolError, sympy_solve


async def recognize_formula(expression: str, variable: str = "x") -> dict:
    try:
        parsed = sympy_solve(expression, variable=variable, mode="parse")
    except MathToolError as exc:
        return {
            "formula": expression,
            "confidence": 0.0,
            "parse_status": "invalid",
            "semantic_validation": False,
            "needs_review": True,
            "error": str(exc),
        }
    return {
        "formula": parsed["result"],
        "confidence": 1.0,
        "parse_status": "valid",
        "semantic_validation": True,
        "needs_review": False,
    }
