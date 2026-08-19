-- La page "Enseignants & Écoles" (comme toute future liste de staff) a besoin que n'importe quel admin
-- actif puisse VOIR la liste des comptes admin_users (dont les enseignants) — la policy actuelle
-- restreignait la lecture au seul super_admin, ce qui aurait rendu la page invisible pour un admin_pays
-- alors que le CDC (§5.4, périmètre de rôle) prévoit explicitement qu'il gère les comptes enseignant.
-- L'écriture (INSERT/UPDATE/DELETE) reste réservée au super_admin (policies existantes inchangées) —
-- élargir l'écriture par rôle nécessiterait des policies scoped par rôle, hors périmètre de ce correctif.

DROP POLICY IF EXISTS admin_users_select ON admin_users;
CREATE POLICY admin_users_select ON admin_users FOR SELECT USING (auth_user_id = auth.uid() OR is_admin_user());
