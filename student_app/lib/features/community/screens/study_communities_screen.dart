import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §16 du cahier des charges. Données réelles (whatsapp_communities), gate déjà appliqué côté RLS
/// par classe ET palier d'abonnement. Une communauté n'existe qu'à l'initiative de l'admin pays —
/// jamais créée par les élèves.
class StudyCommunitiesScreen extends ConsumerWidget {
  const StudyCommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    return profile == null
        ? const Center(child: CircularProgressIndicator())
        : StudentPageContent(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StudentScreenHeader(title: 'Communautés d\'Étude'),
                  const SizedBox(height: 20),
                  Consumer(
                    builder: (context, ref, _) {
                      final communityAsync = ref.watch(whatsappCommunityProvider(profile.classNodeId));
                      return communityAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text('Erreur : $err', style: const TextStyle(color: Colors.red)),
                        data: (community) {
                          if (community == null) {
                            return _emptyState(context, profile.className);
                          }
                          return _buildCommunityCard(context, community.inviteLink, community.memberCountEstimate, profile.className);
                        },
                      );
                    },
                  ),
                ],
              ),
            ));
  }

  Widget _emptyState(BuildContext context, String className) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 46, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text('Aucune communauté active pour $className',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Soit l\'administration n\'a pas encore créé de groupe pour votre classe, soit votre palier d\'abonnement actuel n\'y donne pas accès.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityCard(BuildContext context, String inviteLink, int memberCount, String className) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFF25D366).withOpacity(0.25), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 14),
          Text('Groupe Officiel — $className', style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          Text('~$memberCount membres • Modéré par l\'administration',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9))),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF128C7E),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ouverture de $inviteLink...')),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Rejoindre sur WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
