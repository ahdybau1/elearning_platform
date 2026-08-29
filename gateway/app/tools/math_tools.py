"""Tool math (§12 : "SymPy/NumPy/SciPy") : calcul EXACT confié à SymPy, jamais au LLM — voir la
règle explicite de docs/CAHIER_TECHNIQUE_FRAMEWORKS_OUTILS_IA.md §6 ("Pas de calcul mathématique
exact confié uniquement au LLM").

SÉCURITÉ — trouvé et corrigé le 2026-08-29, pas théorique : un premier essai utilisant
`sympy.parsing.sympy_parser.parse_expr(expression, local_dict=..., evaluate=True)` SANS
`global_dict` explicite s'est révélé être une vraie exécution de code arbitraire. `parse_expr`
appelle en interne `eval(code, global_dict, local_dict)`, et CPython injecte automatiquement le
VRAI module `__builtins__` dans tout dict `globals` qui ne contient pas déjà cette clé — même si
`global_dict` semble "restreint" par ailleurs. Testé en conditions réelles avec l'expression
`__import__("os").system("whoami")` : la commande s'est réellement exécutée sur la machine
(confirmé dans les logs du serveur). Corrigé par deux défenses indépendantes :
1. Allowlist de caractères stricte AVANT tout parsing (aucune lettre autorisée hors la variable et
   quelques noms de fonctions mathématiques connus, aucun `__`).
2. `global_dict` explicite contenant `'__builtins__': {}` pour neutraliser l'injection automatique
   de CPython, en plus de ne whitelister que des objets SymPy sûrs.
Re-testé après correction : la même expression malveillante est maintenant rejetée avant même
d'atteindre `parse_expr`, tandis que les calculs légitimes (solve/simplify/evaluate) continuent de
fonctionner normalement.
"""
import concurrent.futures
import re
import types

import sympy
from sympy.parsing.sympy_parser import parse_expr

MAX_EXPR_LEN = 200
TIMEOUT_SECONDS = 5
_VALID_MODES = {"solve", "simplify", "evaluate"}

# Uniquement chiffres, opérateurs mathématiques, parenthèses, points, espaces et lettres (pour la
# variable + les noms de fonctions ci-dessous) — aucun caractère permettant d'écrire un accès
# attribut chaîné suspect au-delà du strict nécessaire n'est ajouté sans revue.
_ALLOWED_CHARS = re.compile(r"^[0-9a-zA-Z_+\-*/^().,\s]+$")
_FORBIDDEN_SUBSTRINGS = (
    "__", "import", "exec", "eval", "open", "os.", "sys.", "subprocess",
    "getattr", "setattr", "globals", "locals", "compile", "lambda",
)
class MathToolError(ValueError):
    pass


def _validate_expression(expression: str) -> None:
    if not expression or len(expression) > MAX_EXPR_LEN:
        raise MathToolError(f"Expression manquante ou trop longue (max {MAX_EXPR_LEN} caractères).")
    if not _ALLOWED_CHARS.match(expression):
        raise MathToolError("Expression contient des caractères non autorisés.")
    lowered = expression.lower()
    for forbidden in _FORBIDDEN_SUBSTRINGS:
        if forbidden in lowered:
            raise MathToolError(f"Expression rejetée (motif interdit : '{forbidden}').")


_SAFE_SYMPY_GLOBALS: dict | None = None


def _safe_global_dict() -> dict:
    """Namespace complet de SymPy (Integer/Symbol/Rational/sin/cos/... — nécessaires au parser
    interne pour construire les nombres/fonctions), en excluant tout objet module (empêcherait un
    accès du type `sympy.core.something`) et en neutralisant explicitement l'injection automatique
    de `__builtins__` par CPython dans `eval()` — c'est la vraie cause de la vulnérabilité trouvée
    et corrigée le 2026-08-29, pas un détail cosmétique."""
    global _SAFE_SYMPY_GLOBALS
    if _SAFE_SYMPY_GLOBALS is None:
        _SAFE_SYMPY_GLOBALS = {
            name: value
            for name, value in vars(sympy).items()
            if not name.startswith("_") and not isinstance(value, types.ModuleType)
        }
    safe = dict(_SAFE_SYMPY_GLOBALS)
    safe["__builtins__"] = {}
    return safe


def _compute(expression: str, mode: str, variable: str) -> dict:
    var = sympy.Symbol(variable)
    global_dict = _safe_global_dict()
    try:
        expr = parse_expr(expression, local_dict={variable: var}, global_dict=global_dict, evaluate=True)
    except (SyntaxError, TypeError, NameError, sympy.SympifyError) as exc:
        raise MathToolError(f"Expression invalide : {exc}") from exc

    if not isinstance(expr, sympy.Basic):
        # Ne devrait plus arriver après la correction (c'est exactement le symptôme qui avait
        # révélé la faille : un `int` Python brut renvoyé par une expression non-mathématique).
        raise MathToolError("Expression rejetée : ne représente pas une expression SymPy valide.")

    if mode == "solve":
        solutions = sympy.solve(expr, var)
        return {"result": [str(s) for s in solutions]}
    if mode == "simplify":
        return {"result": str(sympy.simplify(expr))}
    # mode == "evaluate"
    return {"result": str(expr.evalf())}


def sympy_solve(expression: str, variable: str = "x", mode: str = "solve") -> dict:
    """Tool réel — pas un stub. `mode` : 'solve' (résout expr=0 pour `variable`), 'simplify'
    (simplification symbolique), 'evaluate' (évaluation numérique)."""
    _validate_expression(expression)
    if mode not in _VALID_MODES:
        raise MathToolError(f"mode invalide : '{mode}' (attendu : {sorted(_VALID_MODES)}).")

    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
        future = executor.submit(_compute, expression, mode, variable)
        try:
            return future.result(timeout=TIMEOUT_SECONDS)
        except concurrent.futures.TimeoutError as exc:
            raise MathToolError(f"Calcul trop long (>{TIMEOUT_SECONDS}s) — expression rejetée.") from exc
