import 'package:supabase_flutter/supabase_flutter.dart';

/// Détection, une seule fois par lancement, des colonnes ajoutées par des migrations récentes.
///
/// L'app peut être déployée (ou testée en prévisualisation sur la base de production) avant que la
/// migration correspondante soit appliquée. Plutôt que de faire échouer le chargement des profils,
/// on demande seulement les colonnes réellement disponibles.
class SchemaFeatures {
  SchemaFeatures._();

  static Future<bool>? _hasDisplayLabel;

  /// Vrai si `display_label(academic_nodes)` existe (migration 95 : « Terminale D » au lieu de
  /// « Série D »).
  static Future<bool> hasDisplayLabel(SupabaseClient client) {
    return _hasDisplayLabel ??= client
        .from('academic_nodes')
        .select('id, display_label')
        .limit(1)
        .then((_) => true)
        .catchError((Object _) => false);
  }

  static Future<bool>? _hasAccountGender;

  /// Vrai si `accounts.gender` existe (migration 95). Sans elle, le sexe n'est pas enregistré
  /// plutôt que de faire échouer la création du compte.
  static Future<bool> hasAccountGender(SupabaseClient client) {
    return _hasAccountGender ??= client
        .from('accounts')
        .select('gender')
        .limit(1)
        .then((_) => true)
        .catchError((Object _) => false);
  }

  /// Colonnes à demander dans l'imbrication `academic_nodes(...)` d'un profil.
  static Future<String> classNodeColumns(SupabaseClient client) async =>
      await hasDisplayLabel(client) ? 'name, display_label' : 'name';
}
