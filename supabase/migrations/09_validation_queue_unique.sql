-- Migration 09: Contrainte UNIQUE manquante sur validation_queue.content_id
--
-- SupabaseService.submitForValidation() fait un upsert avec onConflict: 'content_id' (un seul
-- enregistrement de validation par leçon/exercice, y compris en cas de resoumission après "à
-- corriger"). Sans contrainte UNIQUE correspondante, Postgres rejette la requête avec l'erreur
-- 42P10 ("no unique or exclusion constraint matching the ON CONFLICT specification"), renvoyée en
-- HTTP 400 par PostgREST — la soumission à la validation échouait donc systématiquement.
--
-- Rejouable sans erreur.

ALTER TABLE validation_queue DROP CONSTRAINT IF EXISTS validation_queue_content_id_key;
ALTER TABLE validation_queue ADD CONSTRAINT validation_queue_content_id_key UNIQUE (content_id);
