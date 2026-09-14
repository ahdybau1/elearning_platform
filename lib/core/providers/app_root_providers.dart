import 'package:flutter_riverpod/flutter_riverpod.dart';

/// §17 du CDC : vrai `false` à chaque démarrage à froid de l'app — poser ce choix « Je suis élève »
/// une fois par ouverture n'a rien de persistant par design (voir RoleSelectionScreen). Distinct de
/// `hasUnlockedThisBoot` (student_auth_provider.dart) : celui-ci ne fait que sortir de l'écran de
/// choix de rôle, l'autre exige encore mot de passe ou code personnel avant d'entrer réellement.
final hasChosenStudentRoleProvider = StateProvider<bool>((ref) => false);
