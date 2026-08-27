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

/// §4 du cahier des charges. Cloisonnement réel : un examen national est rattaché à UNE SEULE
/// classe (BEPC → 3e, Probatoire → 1ère, Baccalauréat → Terminale, au Cameroun) — un profil ne
/// voit jamais un examen d'un autre niveau, et un niveau sans examen national (ex: 2nde) n'a
/// simplement pas accès à cette page (voir main_navigation_screen.dart, qui la masque déjà de la
/// barre latérale dans ce cas). Le titre reprend le nom exact de l'examen du profil actif.
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_outlined, size: 46, color: context.colors.textMuted),
                    const SizedBox(height: 16),
                    Text('Aucun examen national pour $className',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      'Ce niveau ne compose aucun examen officiel du pays.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
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
                trailing: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: context.colors.accentAmber),
                  onPressed: () => Navigator.pushNamed(context, '/mock-arena'),
                  icon: const Icon(Icons.emoji_events_rounded, size: 18),
                  label: const Text('Examens Blancs', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: context.colors.accentIndigo, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${widget.exam.name} — ${widget.className}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                  ),
                  ToggleButtons(
                    isSelected: [_groupBySubject, !_groupBySubject],
                    onPressed: (i) => setState(() => _groupBySubject = i == 0),
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.black,
                    fillColor: context.colors.accentPrimary,
                    color: context.colors.textSecondary,
                    constraints: const BoxConstraints(minHeight: 32, minWidth: 90),
                    children: const [
                      Text('Par matière', style: TextStyle(fontSize: 11)),
                      Text('Par année', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: papersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Erreur : $err', style: const TextStyle(color: Colors.red))),
                data: (papers) {
                  if (papers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_off_outlined, size: 46, color: context.colors.textMuted),
                            const SizedBox(height: 16),
                            Text('Aucun sujet archivé pour le moment',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                            const SizedBox(height: 6),
                            Text('Les annales de ${widget.exam.name} seront ajoutées progressivement par l\'administration.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, color: context.colors.textSecondary)),
                          ],
                        ),
                      ),
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
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
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
    final bool correctionUnlocked = paper.isCorrectionUnlocked;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _groupBySubject ? 'Session ${paper.year}' : (paper.subjectName ?? 'Matière'),
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              side: BorderSide(color: context.colors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _openDocument(context, paper.documentUrl),
            icon: const Icon(Icons.description_outlined, size: 15),
            label: const Text('Sujet', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          if (correctionUnlocked)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentEmerald,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _openDocument(context, paper.correctionUrl),
              icon: const Icon(Icons.check_circle_rounded, size: 15),
              label: const Text('Corrigé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            Tooltip(
              message: 'Le corrigé se débloque après une première tentative',
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.textMuted,
                  side: BorderSide(color: context.colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: null,
                icon: const Icon(Icons.lock_outline_rounded, size: 14),
                label: const Text('Corrigé', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
