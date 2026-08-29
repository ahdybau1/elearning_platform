"""Allowlist stricte des tools exposés par la Gateway (§2 du cahier Agents IA : « Aucun agent
n'obtient un accès SQL générique à toute la base »). Un tool absent d'ici n'est tout simplement pas
appelable — pas de fallback générique.
"""
from typing import Awaitable, Callable, Optional

from pydantic import BaseModel

from .content import ContentToolError, search_validated_content
from .curriculum import CurriculumToolError, get_curriculum_context
from .math_tools import MathToolError, sympy_solve


class CurriculumContextInput(BaseModel):
    class_node_id: str


class SearchContentInput(BaseModel):
    subject_id: Optional[str] = None
    chapter_id: Optional[str] = None
    keyword: Optional[str] = None
    limit: int = 5


class SympySolveInput(BaseModel):
    expression: str
    variable: str = "x"
    mode: str = "solve"  # 'solve' | 'simplify' | 'evaluate'


async def _run_curriculum(payload: dict) -> dict:
    data = CurriculumContextInput(**payload)
    return await get_curriculum_context(data.class_node_id)


async def _run_content(payload: dict) -> dict:
    data = SearchContentInput(**payload)
    return await search_validated_content(
        subject_id=data.subject_id, chapter_id=data.chapter_id, keyword=data.keyword, limit=data.limit,
    )


async def _run_math(payload: dict) -> dict:
    data = SympySolveInput(**payload)
    return sympy_solve(expression=data.expression, variable=data.variable, mode=data.mode)


TOOL_REGISTRY: dict[str, Callable[[dict], Awaitable[dict]]] = {
    "get_curriculum_context": _run_curriculum,
    "search_validated_content": _run_content,
    "sympy_solve": _run_math,
}

TOOL_ERRORS: tuple[type[Exception], ...] = (CurriculumToolError, ContentToolError, MathToolError)
