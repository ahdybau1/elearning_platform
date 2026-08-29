-- IA-004 partie 2 : recherche par similarité cosinus sur ai_rag_chunks (§10 du cahier : "retrieval
-- filtré"). PostgREST ne peut pas trier par distance vectorielle via de simples filtres REST — RPC
-- nécessaire, mais reste un paramètre typé fixe (query_embedding + filtres de scope), jamais du SQL
-- arbitraire passé par l'appelant (§2 du cahier Agents IA).

CREATE OR REPLACE FUNCTION match_rag_chunks(
    query_embedding vector(768),
    match_class_node_id UUID DEFAULT NULL,
    match_subject_id UUID DEFAULT NULL,
    match_count INT DEFAULT 5
)
RETURNS TABLE (id UUID, source_id UUID, content TEXT, similarity FLOAT)
AS $$
    SELECT c.id, c.source_id, c.content, 1 - (c.embedding <=> query_embedding) AS similarity
    FROM ai_rag_chunks c
    WHERE (match_class_node_id IS NULL OR c.class_node_id = match_class_node_id)
      AND (match_subject_id IS NULL OR c.subject_id = match_subject_id)
    ORDER BY c.embedding <=> query_embedding
    LIMIT LEAST(GREATEST(match_count, 1), 20);
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION match_rag_chunks(vector, UUID, UUID, INT) TO authenticated, service_role;
