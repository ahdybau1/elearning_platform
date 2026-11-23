import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// §17 du CDC : vrai `false` à chaque démarrage à froid de l'app — poser ce choix « Je suis élève »
/// une fois par ouverture n'a rien de persistant par design (voir RoleSelectionScreen). Distinct de
/// `hasUnlockedThisBoot` (student_auth_provider.dart) : celui-ci ne fait que sortir de l'écran de
/// choix de rôle, l'autre exige encore mot de passe ou code personnel avant d'entrer réellement.
///
/// Exception : au retour d'un lien d'authentification élève (connexion Google, confirmation
/// d'email, mot de passe oublié), la page web se recharge avec les paramètres Supabase dans
/// l'URL. Redemander « élève ou parent ? » à ce moment-là casserait le parcours : on considère
/// le rôle élève comme déjà choisi.
final hasChosenStudentRoleProvider = StateProvider<bool>((ref) => _isReturningFromAuthLink());

bool _isReturningFromAuthLink() {
  if (!kIsWeb) return false;
  final uri = Uri.base;
  final query = uri.queryParameters;
  return query.containsKey('code') ||
      query.containsKey('error_description') ||
      uri.fragment.contains('access_token=') ||
      uri.fragment.contains('type=recovery');
}
