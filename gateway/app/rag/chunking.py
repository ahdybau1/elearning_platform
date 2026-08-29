"""Segmentation structure-aware (§10 du cahier Agents IA) — reprend EXACTEMENT la même logique de
résolution que `Lesson.blocks` côté `student_app` (CF-001,
`student_app/lib/core/models/student_models.dart`) et `_blocksFromAiStructured` côté `admin_app`
(CF-002, `lessons_manager_screen.dart`) : `content_json['blocks']` natif en priorité, sinon dérivé de
`ai_structured`, sinon repli sur `body` brut. Un chunk RAG = un bloc pédagogique, pas une coupure
arbitraire par nombre de caractères — cohérent avec ce que l'élève voit réellement.
"""


def chunk_lesson_content(content_json: dict) -> list[dict]:
    """Retourne une liste de {heading, text} — jamais un texte vide dans le lot."""
    raw_blocks = content_json.get("blocks")
    if isinstance(raw_blocks, list) and raw_blocks:
        chunks = []
        for block in raw_blocks:
            if not isinstance(block, dict):
                continue
            text = (block.get("body") or "").strip()
            if text:
                chunks.append({"heading": block.get("heading"), "text": text})
        if chunks:
            return chunks

    structured = content_json.get("ai_structured")
    if isinstance(structured, dict):
        chunks = []
        summary = structured.get("summary")
        if isinstance(summary, str) and summary.strip():
            chunks.append({"heading": None, "text": summary.strip()})
        for section in structured.get("sections") or []:
            if not isinstance(section, dict):
                continue
            text = (section.get("body") or "").strip()
            if text:
                chunks.append({"heading": section.get("heading"), "text": text})
        traps = [str(t).strip() for t in (structured.get("common_traps") or []) if str(t).strip()]
        if traps:
            chunks.append({"heading": "Pièges classiques", "text": "\n".join(f"• {t}" for t in traps)})
        tips = [str(t).strip() for t in (structured.get("exam_tips") or []) if str(t).strip()]
        if tips:
            chunks.append({"heading": "Conseils d'examen", "text": "\n".join(f"• {t}" for t in tips)})
        if chunks:
            return chunks

    body = content_json.get("body")
    if isinstance(body, str) and body.strip():
        return [{"heading": None, "text": body.strip()}]

    return []
