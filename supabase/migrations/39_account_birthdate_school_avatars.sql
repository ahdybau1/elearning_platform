-- §7.1 du cahier des charges élargi : établissement fréquenté (texte libre, distinct du
-- référentiel `establishments` géré par l'admin pour les épreuves inter-établissements) + date de
-- naissance (fonctionnalité "joyeux anniversaire" demandée par l'utilisateur, absente du CDC
-- initial mais explicitement approuvée). Bucket `avatars` séparé du bucket `media` (réservé à
-- l'admin) pour permettre à un élève d'uploader sa propre photo de profil.

ALTER TABLE accounts ADD COLUMN IF NOT EXISTS birth_date DATE;
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS school_name TEXT;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS avatars_public_read ON storage.objects;
CREATE POLICY avatars_public_read ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS avatars_owner_insert ON storage.objects;
CREATE POLICY avatars_owner_insert ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'avatars' AND owner = auth.uid());

DROP POLICY IF EXISTS avatars_owner_update ON storage.objects;
CREATE POLICY avatars_owner_update ON storage.objects
    FOR UPDATE USING (bucket_id = 'avatars' AND owner = auth.uid());

DROP POLICY IF EXISTS avatars_owner_delete ON storage.objects;
CREATE POLICY avatars_owner_delete ON storage.objects
    FOR DELETE USING (bucket_id = 'avatars' AND owner = auth.uid());
