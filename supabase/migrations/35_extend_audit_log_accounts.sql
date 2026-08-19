-- Section 13.5 du CDC : "Toute suppression effectuée par n'importe quel administrateur doit être
-- retrouvable et consultable par le Super-admin — aucune suppression n'est anonyme ou invisible à ses
-- yeux." Le trigger `log_admin_action` (voir reset_project_schema.sql / migration antérieure) n'était
-- posé que sur academic_nodes, subscription_tiers, access_matrix et admin_users — aucune suppression
-- de compte élève, compte parent ou profil (les entités mêmes de "Comptes & Sécurité") n'était donc
-- jamais journalisée.

-- UPDATE/DELETE seulement (pas INSERT) : la création d'un compte/profil est très majoritairement une
-- auto-inscription élève (assistant d'inscription, CDC §7), pas un geste admin — la tracer noierait le
-- journal sous des milliers d'entrées "Système" sans valeur d'audit. Les modifications et suppressions,
-- elles, sont presque toujours un geste admin (archivage, suspension, suppression définitive) et sont
-- exactement ce que le §13.5 exige de rendre traçable.
DROP TRIGGER IF EXISTS audit_accounts ON accounts;
CREATE TRIGGER audit_accounts AFTER UPDATE OR DELETE ON accounts FOR EACH ROW EXECUTE FUNCTION log_admin_action();

DROP TRIGGER IF EXISTS audit_parent_accounts ON parent_accounts;
CREATE TRIGGER audit_parent_accounts AFTER UPDATE OR DELETE ON parent_accounts FOR EACH ROW EXECUTE FUNCTION log_admin_action();

DROP TRIGGER IF EXISTS audit_profiles ON profiles;
CREATE TRIGGER audit_profiles AFTER UPDATE OR DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION log_admin_action();
