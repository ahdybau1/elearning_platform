import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/models/student_models.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';

/// §5 du cahier des charges. Données réelles (establishments/establishment_papers, lecture
/// publique) — la classe est toujours déduite du profil actif, jamais redemandée (§5, règle de
/// cloisonnement). Catalogue ouvert : tout élève peut consulter les épreuves de n'importe quel
/// établissement.
class EstablishmentPapersScreen extends ConsumerStatefulWidget {
  const EstablishmentPapersScreen({super.key});

  @override
  ConsumerState<EstablishmentPapersScreen> createState() =>
      _EstablishmentPapersScreenState();
}

class _EstablishmentPapersScreenState
    extends ConsumerState<EstablishmentPapersScreen> {
  String? _selectedEstablishmentId;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final establishmentsAsync = ref.watch(establishmentsProvider);

    return profile == null
        ? const Center(child: CircularProgressIndicator())
        : StudentPageContent(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StudentScreenHeader(
                    title: 'Épreuves par Établissement',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          color: context.colors.accentPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Épreuves filtrées pour : ${profile.className}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Filtrer par établissement',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  establishmentsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text(
                      'Erreur : $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                    data: (establishments) => SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _filterChip(
                            'Tous les établissements',
                            _selectedEstablishmentId == null,
                            () =>
                                setState(() => _selectedEstablishmentId = null),
                          ),
                          ...establishments.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _filterChip(
                                '${e.name} (${e.city})',
                                _selectedEstablishmentId == e.id,
                                () => setState(
                                  () => _selectedEstablishmentId = e.id,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final papersAsync = ref.watch(
                          establishmentPapersProvider(
                            EstablishmentPapersQuery(
                              classNodeId: profile.classNodeId,
                              establishmentId: _selectedEstablishmentId,
                            ),
                          ),
                        );
                        return papersAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Text(
                            'Erreur : $err',
                            style: const TextStyle(color: Colors.red),
                          ),
                          data: (papers) {
                            if (papers.isEmpty) {
                              return _emptyState();
                            }
                            return ListView.separated(
                              itemCount: papers.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _buildPaperTile(context, papers[index]),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: context.colors.accentPrimary.withValues(alpha: 0.2),
      backgroundColor: context.colors.card,
      labelStyle: TextStyle(
        color: selected
            ? context.colors.accentPrimary
            : context.colors.textPrimary,
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 42,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              'Aucune épreuve disponible pour le moment',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Les établissements et enseignants n\'ont pas encore publié d\'épreuve pour votre classe.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperTile(BuildContext context, EstablishmentPaper paper) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${paper.subjectName ?? 'Matière'} — ${paper.year}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  paper.establishmentName ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Sujet')),
          if (paper.correctionUrl != null)
            TextButton(onPressed: () {}, child: const Text('Correction')),
        ],
      ),
    );
  }
}
