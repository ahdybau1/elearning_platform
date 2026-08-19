-- Migration 04: RLS, Triggers Métier (Cumul Mensuel, Audit Log) & Seed Data Cameroun

-- ============================================================================
-- 1. TRIGGER MÉTIER : CUMUL MENSUEL ET REQUALIFICATION AUTOMATIQUE (Section 38)
-- ============================================================================

CREATE OR REPLACE FUNCTION handle_monthly_spend_accumulation()
RETURNS TRIGGER AS $$
DECLARE
    v_month_year TEXT;
    v_class_node_id UUID;
    v_monthly_price NUMERIC(10, 2);
    v_new_total NUMERIC(10, 2);
    v_mensuel_tier_id UUID;
BEGIN
    -- S'exécute uniquement lorsqu'une transaction passe en statut 'success'
    IF (TG_OP = 'INSERT' AND NEW.status = 'success') OR (TG_OP = 'UPDATE' AND NEW.status = 'success' AND OLD.status != 'success') THEN
        
        -- Récupérer le mois courant 'YYYY-MM'
        v_month_year := TO_CHAR(NEW.created_at, 'YYYY-MM');
        
        -- Récupérer la classe du profil
        SELECT class_node_id INTO v_class_node_id FROM profiles WHERE id = NEW.profile_id;
        
        -- Mettre à jour ou insérer le compteur de dépenses du mois
        INSERT INTO monthly_spend_counter (profile_id, month_year, cumulative_amount, updated_at)
        VALUES (NEW.profile_id, v_month_year, NEW.amount, NOW())
        ON CONFLICT (profile_id, month_year)
        DO UPDATE SET 
            cumulative_amount = monthly_spend_counter.cumulative_amount + EXCLUDED.cumulative_amount,
            updated_at = NOW()
        RETURNING cumulative_amount INTO v_new_total;
        
        -- Récupérer le prix et l'ID du palier Mensuel pour cette classe
        SELECT id, price INTO v_mensuel_tier_id, v_monthly_price 
        FROM subscription_tiers 
        WHERE class_node_id = v_class_node_id AND name = 'mensuel'
        LIMIT 1;
        
        -- Si le cumul atteint ou dépasse le prix du palier Mensuel
        IF v_monthly_price IS NOT NULL AND v_new_total >= v_monthly_price THEN
            -- Requalifier automatiquement le profil au palier 'mensuel'
            UPDATE profiles 
            SET subscription_tier = 'mensuel', updated_at = NOW()
            WHERE id = NEW.profile_id;
            
            -- Créer ou mettre à jour l'abonnement mensuel pour le reste du mois calendaire
            INSERT INTO subscriptions (profile_id, tier_id, start_date, end_date, status)
            VALUES (
                NEW.profile_id, 
                v_mensuel_tier_id, 
                NOW(), 
                (DATE_TRUNC('month', NOW()) + INTERVAL '1 month' - INTERVAL '1 day')::TIMESTAMPTZ,
                'actif'
            );
            
            -- Créer une notification in-app de félicitations pour l'élève
            INSERT INTO notification_log (profile_id, title, body, channel)
            VALUES (
                NEW.profile_id,
                'Félicitations ! Accès Mensuel Débloqué',
                'Vous avez cumulé assez de paiements ce mois-ci pour débloquer l''accès complet jusqu''à la fin du mois !',
                'in_app'
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
-- SECURITY DEFINER : ce trigger peut être déclenché par un admin authentifié qui met à jour une
-- transaction manuellement depuis l'écran de réconciliation (pas seulement par le webhook en
-- service_role) ; il doit pouvoir écrire dans monthly_spend_counter/subscriptions/notification_log
-- quel que soit le rôle de l'appelant (voir 01_rls_security.md).

CREATE OR REPLACE TRIGGER trigger_monthly_spend_accumulation
AFTER INSERT OR UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION handle_monthly_spend_accumulation();


-- ============================================================================
-- 2. TRIGGER D'AUDIT LOG AUTOMATIQUE POUR ACTION ADMIN
-- ============================================================================

CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    -- Résolu via auth.uid() -> admin_users.auth_user_id, plus jamais via current_setting (variable
    -- de session que rien ne définit côté client — voir 01_rls_security.md).
    SELECT id INTO v_admin_id FROM admin_users WHERE auth_user_id = auth.uid();
    INSERT INTO audit_log (admin_user_id, action_type, entity_type, entity_id, before_json, after_json)
    VALUES (
        v_admin_id,
        TG_OP,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD)::jsonb ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW)::jsonb ELSE NULL END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
-- SECURITY DEFINER : déclenché par des DML faites par des admins authentifiés (pas service_role),
-- doit pouvoir écrire dans audit_log même sans policy INSERT pour le rôle appelant.

-- Attacher l'audit log sur les tables sensibles de l'administration
CREATE OR REPLACE TRIGGER audit_academic_nodes AFTER INSERT OR UPDATE OR DELETE ON academic_nodes FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE OR REPLACE TRIGGER audit_subscription_tiers AFTER INSERT OR UPDATE OR DELETE ON subscription_tiers FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE OR REPLACE TRIGGER audit_access_matrix AFTER INSERT OR UPDATE OR DELETE ON access_matrix FOR EACH ROW EXECUTE FUNCTION log_admin_action();
CREATE OR REPLACE TRIGGER audit_admin_users AFTER INSERT OR UPDATE OR DELETE ON admin_users FOR EACH ROW EXECUTE FUNCTION log_admin_action();


-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
-- Déplacé dans son intégralité vers 06_integrity_and_rls.sql : les anciennes policies de ce
-- fichier reposaient sur current_setting('app.current_admin_id', true), une variable de session que
-- rien côté client ne définit jamais — elles ne laissaient donc jamais rien passer (RLS activé, 0
-- ligne accessible à personne, y compris aux vrais super-admins). Elles ne sont plus recréées ici.
-- La migration 06 couvre les ~45 tables du schéma avec des policies basées sur auth.uid(), et
-- redéfinit ENABLE ROW LEVEL SECURITY pour transactions / monthly_spend_counter /
-- subscription_tiers / access_matrix / admin_users / audit_log au passage (idempotent : ALTER
-- TABLE ... ENABLE ROW LEVEL SECURITY ne provoque pas d'erreur si déjà activé).
-- Voir 01_rls_security.md.


-- ============================================================================
-- 4. SEED DATA INITIAL (Cameroun, Sections, Classes, Séries, Matières & Super-Admin)
-- ============================================================================

DO $$
DECLARE
    v_country_id UUID;
    v_francophone_id UUID;
    v_anglophone_id UUID;
    v_gen_fr_id UUID;
    v_tech_fr_id UUID;
    v_3e_id UUID;
    v_2nde_id UUID;
    v_1ere_id UUID;
    v_tle_id UUID;
    v_tle_c_id UUID;
    v_tle_a4_id UUID;
    v_tle_ti_id UUID;
    v_math_id UUID;
    v_physique_id UUID;
    v_svt_id UUID;
    v_français_id UUID;
    v_histo_id UUID;
    v_tier_gratuit_id UUID;
    v_tier_journalier_id UUID;
    v_tier_mensuel_id UUID;
    v_super_admin_id UUID;
BEGIN
    -- 1. Racine Pays : Cameroun
    INSERT INTO academic_nodes (node_type, name, code, parent_id)
    VALUES ('country', 'Cameroun', 'CM', NULL)
    RETURNING id INTO v_country_id;

    -- Mettre à jour country_id du noeud racine sur lui-même
    UPDATE academic_nodes SET country_id = v_country_id WHERE id = v_country_id;

    -- 2. Sections
    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('section', 'Section Francophone', 'FR', v_country_id, v_country_id)
    RETURNING id INTO v_francophone_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('section', 'Section Anglophone (Sub-system)', 'EN', v_country_id, v_country_id)
    RETURNING id INTO v_anglophone_id;

    -- 3. Types d'enseignement sous Section Francophone
    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('education_type', 'Enseignement Général', 'GEN_FR', v_francophone_id, v_country_id)
    RETURNING id INTO v_gen_fr_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('education_type', 'Enseignement Technique', 'TECH_FR', v_francophone_id, v_country_id)
    RETURNING id INTO v_tech_fr_id;

    -- 4. Classes sous Enseignement Général
    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id, display_order)
    VALUES ('class', 'Classe de 3ème', '3E', v_gen_fr_id, v_country_id, 4)
    RETURNING id INTO v_3e_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id, display_order)
    VALUES ('class', 'Classe de 2nde', '2NDE', v_gen_fr_id, v_country_id, 5)
    RETURNING id INTO v_2nde_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id, display_order)
    VALUES ('class', 'Classe de 1ère', '1ERE', v_gen_fr_id, v_country_id, 6)
    RETURNING id INTO v_1ere_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id, display_order)
    VALUES ('class', 'Classe de Terminale', 'TLE', v_gen_fr_id, v_country_id, 7)
    RETURNING id INTO v_tle_id;

    -- 5. Séries sous la Classe de Terminale
    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('series', 'Terminale C (Scientifique Math/Physique)', 'TLE_C', v_tle_id, v_country_id)
    RETURNING id INTO v_tle_c_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('series', 'Terminale A4 (Littéraire)', 'TLE_A4', v_tle_id, v_country_id)
    RETURNING id INTO v_tle_a4_id;

    INSERT INTO academic_nodes (node_type, name, code, parent_id, country_id)
    VALUES ('series', 'Terminale TI (Technologies de l''Information)', 'TLE_TI', v_tle_id, v_country_id)
    RETURNING id INTO v_tle_ti_id;

    -- 6. Matières principales du Cameroun
    INSERT INTO subjects (name, code, country_id) VALUES ('Mathématiques', 'MATH', v_country_id) RETURNING id INTO v_math_id;
    INSERT INTO subjects (name, code, country_id) VALUES ('Physique-Chimie', 'PHY_CHIM', v_country_id) RETURNING id INTO v_physique_id;
    INSERT INTO subjects (name, code, country_id) VALUES ('Sciences de la Vie et de la Terre', 'SVT', v_country_id) RETURNING id INTO v_svt_id;
    INSERT INTO subjects (name, code, country_id) VALUES ('Français & Littérature', 'FRANCAIS', v_country_id) RETURNING id INTO v_français_id;
    INSERT INTO subjects (name, code, country_id) VALUES ('Histoire - Géographie', 'HIST_GEO', v_country_id) RETURNING id INTO v_histo_id;

    -- 7. Liens Matière <-> Classes
    INSERT INTO subject_class_links (subject_id, class_node_id) VALUES (v_math_id, v_3e_id);
    INSERT INTO subject_class_links (subject_id, class_node_id) VALUES (v_math_id, v_tle_c_id);
    INSERT INTO subject_class_links (subject_id, class_node_id) VALUES (v_physique_id, v_tle_c_id);
    INSERT INTO subject_class_links (subject_id, class_node_id) VALUES (v_français_id, v_3e_id);

    -- 8. Paliers d'abonnements pour la Classe de 3ème
    INSERT INTO subscription_tiers (name, country_id, class_node_id, price, duration_days)
    VALUES ('gratuit', v_country_id, v_3e_id, 0.00, 0)
    RETURNING id INTO v_tier_gratuit_id;

    INSERT INTO subscription_tiers (name, country_id, class_node_id, price, duration_days)
    VALUES ('journalier', v_country_id, v_3e_id, 150.00, 1)
    RETURNING id INTO v_tier_journalier_id;

    INSERT INTO subscription_tiers (name, country_id, class_node_id, price, duration_days)
    VALUES ('mensuel', v_country_id, v_3e_id, 2500.00, 30)
    RETURNING id INTO v_tier_mensuel_id;

    -- 9. Configuration de la Matrice de Droits pour la 3ème
    INSERT INTO access_matrix (tier_id, feature_key, access_level, limit_parameter) VALUES
    (v_tier_gratuit_id, 'courses', 'limite', '{"chapters_limit": 2}'::jsonb),
    (v_tier_gratuit_id, 'exercises_training', 'limite', '{"daily_limit": 5}'::jsonb),
    (v_tier_gratuit_id, 'exercises_evaluation', 'aucun', '{}'::jsonb),
    (v_tier_gratuit_id, 'official_exams', 'aucun', '{}'::jsonb),
    (v_tier_gratuit_id, 'ai_assistant', 'aucun', '{}'::jsonb),

    (v_tier_journalier_id, 'courses', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'exercises_training', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'exercises_evaluation', 'complet', '{}'::jsonb),
    (v_tier_journalier_id, 'official_exams', 'aucun', '{}'::jsonb),
    (v_tier_journalier_id, 'ai_assistant', 'limite', '{"daily_questions": 3}'::jsonb),

    (v_tier_mensuel_id, 'courses', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'exercises_training', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'exercises_evaluation', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'official_exams', 'complet', '{}'::jsonb),
    (v_tier_mensuel_id, 'ai_assistant', 'complet', '{}'::jsonb);

    -- 10. Compte Super-Admin initial
    INSERT INTO admin_users (email, first_name, last_name, role)
    VALUES ('ahdybau@gmail.com', 'Super', 'Administrateur', 'super_admin')
    RETURNING id INTO v_super_admin_id;

END $$;
