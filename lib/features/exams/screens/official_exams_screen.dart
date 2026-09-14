import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import '../../../core/models/student_models.dart';
import '../../../design_system/components/empty_state_view.dart';
import '../../../design_system/tokens/app_radius.dart';
import 'exam_questions_screen.dart';

/// §4 du cahier des charges : Annales officielles avec cloisonnement strict par classe.
class OfficialExamsScreen extends ConsumerWidget {
  const OfficialExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final examAsync = ref.watch(officialExamForClassProvider(profile.classNodeId));

    return examAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err', style: const TextStyle(color: Colors.red))),
      data: (exam) {
        if (exam == null) {
          return _NoExamScaffold(className: profile.className);
        }
        return _ExamPapersView(exam: exam, className: profile.className);
      },
    );
  }
}

class _NoExamScaffold extends StatelessWidget {
  final String className;
  const _NoExamScaffold({required this.className});

  @override
  Widget build(BuildContext context) {
    return StudentPageContent(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: StudentScreenHeader(title: 'Examens Officiels'),
          ),
          Expanded(
            child: EmptyStateView(
              icon: Icons.workspace_premium_outlined,
              title: 'Aucun examen national pour $className',
              description: 'Ce niveau d\'étude ne compose aucun examen officiel national.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamPapersView extends ConsumerStatefulWidget {
  final OfficialExam exam;
  final String className;
  const _ExamPapersView({required this.exam, required this.className});

  @override
  ConsumerState<_ExamPapersView> createState() => _ExamPapersViewState();
}

class _ExamPapersViewState extends ConsumerState<_ExamPapersView> {
  bool _groupBySubject = true;

  @override
  Widget build(BuildContext context) {
    final papersAsync = ref.watch(examPapersProvider(widget.exam.id));

    return StudentPageContent(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: StudentScreenHeader(
              title: 'Anciens Sujets — ${widget.exam.name}',
              subtitle: 'Annales officielles et corrigés types pour préparer votre examen.',
              trailing: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.accentAmber,
                  backgroundColor: context.colors.accentAmber.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSmall),
                ),
                onPressed: () => Navigator.pushNamed(context, '/mock-arena'),
                icon: const Icon(Icons.emoji_events_rounded, size: 16),
                label: const Text('Examens Blancs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: context.colors.accentIndigo, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.exam.name} • ${widget.className}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadius.radiusSmall,
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton(
                        label: 'Par matière',
                        isSelected: _groupBySubject,
                        onTap: () => setState(() => _groupBySubject = true),
                      ),
                      _buildToggleButton(
                        label: 'Par année',
                        isSelected: !_groupBySubject,
                        onTap: () => setState(() => _groupBySubject = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: papersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err', style: const TextStyle(color: Colors.red))),
              data: (papers) {
                if (papers.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.folder_off_outlined,
                    title: 'Aucun sujet archivé pour le moment',
                    description: 'Les annales de ${widget.exam.name} seront ajoutées progressivement par l\'administration.',
                  );
                }

                final groups = <String, List<ExamPaper>>{};
                for (final p in papers) {
                  final key = _groupBySubject ? (p.subjectName ?? 'Matière') : p.year.toString();
                  groups.putIfAbsent(key, () => []).add(p);
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: groups.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: context.colors.accentPrimary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.key,
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...entry.value.map((paper) => _buildPaperTile(paper)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusSmall,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.accentPrimary : Colors.transparent,
          borderRadius: AppRadius.radiusSmall,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le document : $url')),
        );
      }
    }
  }

  Widget _buildPaperTile(ExamPaper paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.radiusLarge,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _groupBySubject ? 'Session ${paper.year}' : (paper.subjectName ?? 'Matière'),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                ),
                if (paper.processingStatus == 'published')
                  Text(
                    'Corrigé détaillé disponible',
                    style: GoogleFonts.inter(fontSize: 11, color: context.colors.accentEmerald, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSmall),
            ),
            onPressed: () => _openDocument(context, paper.documentUrl),
            icon: const Icon(Icons.description_outlined, size: 15),
            label: const Text('Sujet', style: TextStyle(fontSize: 12)),
          ),
          if (paper.processingStatus == 'published') ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentPrimary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSmall),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExamQuestionsScreen(
                    title: '${paper.subjectName ?? 'Sujet'} — ${paper.year}',
                    documentUrl: paper.documentUrl,
                    examPaperId: paper.id,
                  ),
                ),
              ),
              icon: const Icon(Icons.visibility_rounded, size: 15),
              label: const Text('Corrigé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
