-- IA-004 partie 2 : enregistre le 4e tool réel (rag_search), même discipline que la migration 57.

INSERT INTO ai_tools (tool_key, description, input_schema, output_schema, timeout_ms) VALUES
(
    'rag_search',
    'Recherche par similarité cosinus dans les chunks RAG déjà ingérés (contenu publié uniquement — voir ingest_lesson). Retourne des citations liées à leur source, jamais un texte sans provenance.',
    '{"type":"object","required":["query"],"properties":{"query":{"type":"string"},"class_node_id":{"type":"string","format":"uuid"},"subject_id":{"type":"string","format":"uuid"},"top_k":{"type":"integer","minimum":1,"maximum":20,"default":5}}}'::jsonb,
    '{"type":"object","properties":{"citations":{"type":"array","items":{"type":"object","properties":{"chunk_id":{"type":"string"},"source_id":{"type":"string"},"source_title":{"type":"string"},"source_type":{"type":"string"},"content":{"type":"string"},"similarity":{"type":"number"}}}}}}'::jsonb,
    15000
)
ON CONFLICT (tool_key) DO NOTHING;
