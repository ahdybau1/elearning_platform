import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import '../widgets/archived_classes_section.dart';
import '../widgets/followed_classes_section.dart';
import '../widgets/login_code_card.dart';
import '../widgets/parent_invite_card.dart';
import '../widgets/profile_achievements_section.dart';
import '../widgets/profile_identity_card.dart';

/// Données réelles (compte + profils déjà chargés par studentAuthProvider) — rien à simuler ici.
///
/// Écran orchestrateur : le fichier faisait auparavant 1373 lignes (avatar, dialogues d'édition,
/// code personnel, invitation parent, classes suivies/archivées, réussites) — découpé en
/// sous-composants sous `../widgets/` (`docs/UI_REDESIGN_PLAN.md` Vague 3, critère d'acceptation
/// n°9 : fichiers < ~350 lignes). Comportement, contrats de providers et routes identiques —
/// refonte purement structurelle, aucun changement fonctionnel.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(studentAuthProvider);
    final account = authState.account;
    final activeProfile = authState.activeProfile;

    return StudentPageContent(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StudentScreenHeader(title: 'Mon Profil'),
            const SizedBox(height: 20),
            ProfileIdentityCard(account: account),

            if (activeProfile != null) ...[
              const SizedBox(height: 20),
              ParentInviteCard(profileId: activeProfile.id),
            ],

            if (account != null) ...[
              const SizedBox(height: 20),
              const LoginCodeCard(),
            ],

            const SizedBox(height: 28),
            FollowedClassesSection(
              profiles: authState.profiles,
              activeProfileId: activeProfile?.id,
            ),

            if (account != null) ...[
              const SizedBox(height: 28),
              ArchivedClassesSection(accountId: account.id),
            ],

            const SizedBox(height: 28),
            const ProfileAchievementsSection(),
          ],
        ),
      ),
    );
  }
}
