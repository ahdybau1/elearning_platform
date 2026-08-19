-- Migration 08: Bucket de stockage pour les médias (images/vidéos/audio/documents des leçons,
-- exercices, sujets d'examens, etc.)
--
-- Jusqu'ici aucun média n'était réellement uploadé nulle part dans l'app — les champs "URL" des
-- formulaires étaient de simples zones de texte à remplir à la main. Ce script crée le bucket
-- Supabase Storage "media" et ses policies RLS (storage.objects, même mécanisme que les tables
-- normales — voir 01_rls_security.md).
--
-- Rejouable sans erreur.

INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true)
ON CONFLICT (id) DO NOTHING;

-- Lecture publique : nécessaire pour que le contenu s'affiche (les URLs sont déjà protégées en
-- amont par le RLS applicatif sur lessons/exercises — voir le "cas particulier" documenté dans
-- 01_rls_security.md ; le fichier brut n'étant pas la donnée sensible en soi pour du contenu
-- pédagogique MVP, le filigrane forensique restant une protection V2 dédiée aux PDF d'examens).
DROP POLICY IF EXISTS media_public_read ON storage.objects;
CREATE POLICY media_public_read ON storage.objects
    FOR SELECT USING (bucket_id = 'media');

-- Upload/suppression réservés aux admins authentifiés et liés (is_admin_user() défini en 06).
DROP POLICY IF EXISTS media_admin_insert ON storage.objects;
CREATE POLICY media_admin_insert ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'media' AND is_admin_user());

DROP POLICY IF EXISTS media_admin_update ON storage.objects;
CREATE POLICY media_admin_update ON storage.objects
    FOR UPDATE USING (bucket_id = 'media' AND is_admin_user());

DROP POLICY IF EXISTS media_admin_delete ON storage.objects;
CREATE POLICY media_admin_delete ON storage.objects
    FOR DELETE USING (bucket_id = 'media' AND is_admin_user());
