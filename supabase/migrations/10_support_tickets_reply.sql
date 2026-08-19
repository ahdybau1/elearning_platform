-- Migration 10: Colonne de réponse manquante sur support_tickets
--
-- SupabaseService.updateTicketStatus() écrit dans support_tickets.reply_message depuis
-- support_tickets_screen.dart, mais cette colonne n'a jamais existé dans le schéma — chaque
-- réponse à un ticket échouait silencieusement (erreur PostgREST "column not found").
--
-- Rejouable sans erreur.

ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS reply_message TEXT;
