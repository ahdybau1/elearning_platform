import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/models/content_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class SchoolYearPromotionScreen extends ConsumerStatefulWidget {
  const SchoolYearPromotionScreen({super.key});

  @override
  ConsumerState<SchoolYearPromotionScreen> createState() =>
      _SchoolYearPromotionScreenState();
}

class _SchoolYearPromotionScreenState
    extends ConsumerState<SchoolYearPromotionScreen> {
  int _activeTab = 0; // 0: Années Scolaires & Trimestres, 1: Campagne de Passage

  @override
  Widget build(BuildContext context) {
    final schoolYearsAsync = ref.watch(schoolYearsProvider(null));
    final promotionRecordsAsync = ref.watch(promotionRecordsProvider(null));

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Expanded : titre 24pt + longue phrase de sous-titre débordait hors de l'écran
                // sur mobile à côté du bouton (retour utilisateur réel, 2026-08-30).
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppTheme.accentEmerald,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Année Scolaire & Campagne de Passage',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Calendrier trimestriel et bascule annuelle des profils élèves (Cas A: Passage / Cas B: Redoublement)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddYearDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nouvelle Année Scolaire'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tab bar
            Row(
              children: [
                _buildTabButton('Années & Calendrier Trimestriel', 0),
                const SizedBox(width: 12),
                _buildTabButton('Campagne de Passage de Classe', 1),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _activeTab == 0
                  ? _buildSchoolYearsTab(schoolYearsAsync)
                  : _buildPromotionsTab(promotionRecordsAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSel = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? AppTheme.accentEmerald.withValues(alpha: 0.15) : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? AppTheme.accentEmerald : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
            color: isSel ? AppTheme.accentEmerald : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolYearsTab(AsyncValue<List<SchoolYear>> schoolYearsAsync) {
    return schoolYearsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
      ),
      data: (years) {
        if (years.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  'Aucune année scolaire configurée.',
                  style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cliquez sur "Nouvelle Année Scolaire" pour commencer.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: years.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final y = years[index];
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: y.isCurrent ? AppTheme.accentEmerald : AppTheme.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Text(
                              y.name,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: y.isActive ? Colors.white : Colors.white38,
                                decoration: y.isActive ? null : TextDecoration.lineThrough,
                              ),
                            ),
                            if (y.isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentEmerald,
                                  ),
                                ),
                              ),
                            if (!y.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ARCHIVÉE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentAmber,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _showEditYearDialog(context, y),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: Text('Modifier', style: GoogleFonts.inter(fontSize: 12)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentAmber,
                              side: const BorderSide(color: AppTheme.accentAmber),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _showToggleYearActiveConfirmation(context, y),
                            icon: Icon(y.isActive ? Icons.archive_rounded : Icons.unarchive_rounded, size: 16),
                            label: Text(y.isActive ? 'Archiver' : 'Désarchiver', style: GoogleFonts.inter(fontSize: 12)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: y.promotionCampaignOpen
                                  ? Colors.redAccent
                                  : AppTheme.accentCyan,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _showToggleCampaignConfirmation(context, y),
                            icon: Icon(
                              y.promotionCampaignOpen
                                  ? Icons.lock_clock_rounded
                                  : Icons.campaign_rounded,
                              size: 16,
                            ),
                            label: Text(
                              y.promotionCampaignOpen
                                  ? 'Fermer la Campagne'
                                  : 'Ouvrir Campagne de Passage',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Période: du ${DateFormat('dd MMMM yyyy').format(y.startDate)} au ${DateFormat('dd MMMM yyyy').format(y.endDate)}',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.borderColor),
                  const SizedBox(height: 12),
                  // Wrap plutôt que Row : titre long + bouton ne tenaient pas côte à côte sur
                  // mobile (retour utilisateur réel, 2026-08-30).
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Découpage Temporel & Déblocage Invisible :',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddTermDialog(context, y),
                        icon: const Icon(Icons.add_rounded, size: 16, color: AppTheme.accentEmerald),
                        label: Text('Ajouter un Trimestre',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentEmerald)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final termsAsync = ref.watch(termsProvider(y.countryId));
                      final terms = (termsAsync.valueOrNull ?? [])
                          .where((t) => t.schoolYear == y.name)
                          .toList()
                        ..sort((a, b) => a.startDate.compareTo(b.startDate));
                      if (terms.isEmpty) {
                        return Text(
                          'Aucun trimestre défini pour cette année scolaire — cliquez sur "Ajouter un Trimestre".',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                        );
                      }
                      final now = DateTime.now();
                      return Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: terms
                            .map((t) => _buildTermBadge(context, t, !t.startDate.isAfter(now)))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTermBadge(BuildContext context, Term term, bool isUnlocked) {
    final dates =
        '${DateFormat('dd MMM').format(term.startDate)} - ${DateFormat('dd MMM').format(term.endDate)}';
    final active = term.isActive;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showEditTermDialog(context, term),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: !active
                ? AppTheme.accentAmber
                : (isUnlocked ? AppTheme.accentEmerald : AppTheme.borderColor),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              !active
                  ? Icons.inventory_2_rounded
                  : (isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded),
              size: 14,
              color: !active
                  ? AppTheme.accentAmber
                  : (isUnlocked ? AppTheme.accentEmerald : AppTheme.textSecondary),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? term.name : '${term.name} (archivé)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !active
                        ? AppTheme.accentAmber
                        : (isUnlocked ? AppTheme.accentEmerald : Colors.white),
                    decoration: active ? null : TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  dates,
                  style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_rounded, size: 12, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionsTab(AsyncValue<List<PromotionRecord>> promotionsAsync) {
    return promotionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
      ),
      data: (records) {
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_edu_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  'Aucun historique de passage de classe pour le moment.',
                  style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, _) => const Divider(color: AppTheme.borderColor, height: 1),
            itemBuilder: (context, index) {
              final r = records[index];
              final isPromotion = r.status == 'valide';
              final service = ref.read(supabaseServiceProvider);
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPromotion
                        ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPromotion ? Icons.upgrade_rounded : Icons.replay_rounded,
                    color: isPromotion ? AppTheme.accentEmerald : Colors.amber,
                    size: 20,
                  ),
                ),
                title: FutureBuilder<List<dynamic>>(
                  // Les classes source/cible ne sont stockées qu'en UUID (fromClassNodeId /
                  // toClassNodeId) — les résoudre en noms réels plutôt que d'afficher des UUIDs
                  // bruts, illisibles pour un admin.
                  future: Future.wait([
                    service.getNode(r.fromClassNodeId),
                    if (r.toClassNodeId != null) service.getNode(r.toClassNodeId) else Future.value(null),
                  ]),
                  builder: (context, snapshot) {
                    final fromName = snapshot.data?[0]?.name ?? '…';
                    final toName =
                        r.toClassNodeId == null ? 'Même classe' : (snapshot.data?[1]?.name ?? '…');
                    return Text(
                      'Élève : $fromName ➔ $toName',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                    );
                  },
                ),
                subtitle: Text(
                  'Année scolaire: ${r.schoolYear} • Traité le ${DateFormat('dd/MM/yyyy').format(r.processedAt)}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPromotion
                        ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPromotion ? 'Cas A: Passage Validé' : 'Cas B: Redoublement',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPromotion ? AppTheme.accentEmerald : Colors.amber,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showAddYearDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String? selectedCountryId;
    DateTime? startDate;
    DateTime? endDate;
    bool isCurrent = false;
    String? fieldError;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.calendar_month_rounded,
            text: 'Créer une Année Scolaire',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom de l\'année (ex: 2027 - 2028)',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary),
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, _) {
                      final countriesAsync = ref.watch(nodesByTypeProvider('country'));
                      final countries = countriesAsync.valueOrNull ?? [];
                      return DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: selectedCountryId,
                        dropdownColor: AppTheme.primaryDark,
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pays',
                          prefixIcon: Icon(Icons.public_rounded, size: 20),
                        ),
                        items: countries
                            .map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedCountryId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 1825)),
                            );
                            if (picked != null) setModalState(() => startDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(startDate == null
                              ? 'Début'
                              : DateFormat('dd/MM/yyyy').format(startDate!)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: startDate?.add(const Duration(days: 300)) ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 1825)),
                            );
                            if (picked != null) setModalState(() => endDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(
                              endDate == null ? 'Fin' : DateFormat('dd/MM/yyyy').format(endDate!)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: isCurrent,
                    activeColor: AppTheme.accentEmerald,
                    title: Text('Marquer comme année scolaire en cours',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                    onChanged: (v) => setModalState(() => isCurrent = v ?? false),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(submitError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setModalState(() => fieldError = 'Le nom est obligatoire');
                        return;
                      }
                      if (selectedCountryId == null || startDate == null || endDate == null) {
                        setModalState(() => submitError = 'Pays, date de début et date de fin sont obligatoires.');
                        return;
                      }
                      if (!endDate!.isAfter(startDate!)) {
                        setModalState(() => submitError = 'La date de fin doit être après la date de début.');
                        return;
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createSchoolYear(
                          countryId: selectedCountryId!,
                          name: name,
                          startDate: startDate!,
                          endDate: endDate!,
                          isCurrent: isCurrent,
                        );
                        ref.invalidate(schoolYearsProvider(null));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          submitError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showToggleCampaignConfirmation(BuildContext context, SchoolYear year) {
    final isOpen = year.promotionCampaignOpen;
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: isOpen ? Icons.lock_clock_rounded : Icons.campaign_rounded,
            iconColor: isOpen ? Colors.redAccent : AppTheme.accentCyan,
            text: isOpen
                ? 'Fermer la campagne de "${year.name}" ?'
                : 'Ouvrir la campagne de "${year.name}" ?',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen
                      ? 'La campagne de passage de classe pour cette année sera marquée comme fermée.'
                      : 'La campagne de passage de classe pour cette année sera marquée comme '
                          'ouverte. Ce bouton ne fait que basculer ce statut — il ne déclenche '
                          'aucune promotion automatique des élèves (cette fonctionnalité n\'est pas '
                          'encore implémentée).',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(errorText!,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isOpen ? Colors.redAccent : AppTheme.accentCyan,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.togglePromotionCampaign(year.id, !isOpen);
                        ref.invalidate(schoolYearsProvider(null));
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentEmerald,
                            content: Text(isOpen
                                ? 'Campagne de "${year.name}" fermée.'
                                : 'Campagne de "${year.name}" ouverte.'),
                          ),
                        );
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isOpen ? 'Fermer' : 'Ouvrir'),
            ),
          ],
        ),
      ),
    );
  }

  /// Aucune modification n'était possible sur une année scolaire après création — une erreur de
  /// saisie (nom, dates) restait bloquée pour toujours. Le pays n'est volontairement pas
  /// modifiable ici (créez une nouvelle année plutôt que de réassigner celle-ci à un autre pays).
  void _showEditYearDialog(BuildContext context, SchoolYear year) {
    final nameCtrl = TextEditingController(text: year.name);
    DateTime startDate = year.startDate;
    DateTime endDate = year.endDate;
    bool isCurrent = year.isCurrent;
    String? fieldError;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.edit_calendar_rounded,
            text: 'Modifier "${year.name}"',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom de l\'année (ex: 2027 - 2028)',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary),
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1825)),
                              lastDate: DateTime.now().add(const Duration(days: 1825)),
                            );
                            if (picked != null) setModalState(() => startDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: endDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1825)),
                              lastDate: DateTime.now().add(const Duration(days: 1825)),
                            );
                            if (picked != null) setModalState(() => endDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(DateFormat('dd/MM/yyyy').format(endDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: isCurrent,
                    activeColor: AppTheme.accentEmerald,
                    title: Text('Marquer comme année scolaire en cours',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                    subtitle: Text('Désactive ce statut sur les autres années de ce pays',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    onChanged: (v) => setModalState(() => isCurrent = v ?? false),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(submitError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setModalState(() => fieldError = 'Le nom est obligatoire');
                        return;
                      }
                      if (!endDate.isAfter(startDate)) {
                        setModalState(() => submitError = 'La date de fin doit être après la date de début.');
                        return;
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateSchoolYear(
                          year.id,
                          countryId: year.countryId,
                          name: name,
                          startDate: startDate,
                          endDate: endDate,
                          isCurrent: isCurrent,
                        );
                        ref.invalidate(schoolYearsProvider(null));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          submitError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showToggleYearActiveConfirmation(BuildContext context, SchoolYear year) {
    final isActive = year.isActive;
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: isActive ? Icons.archive_rounded : Icons.unarchive_rounded,
            iconColor: AppTheme.accentAmber,
            text: isActive ? 'Archiver "${year.name}" ?' : 'Désarchiver "${year.name}" ?',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? 'Cette année scolaire sera masquée par défaut, pas supprimée — ses trimestres et son historique de passage restent intacts.'
                      : 'Cette année scolaire redeviendra pleinement visible.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(errorText!,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber),
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateSchoolYear(
                          year.id,
                          countryId: year.countryId,
                          isActive: !isActive,
                        );
                        ref.invalidate(schoolYearsProvider(null));
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.accentEmerald,
                            content: Text(isActive
                                ? 'Année "${year.name}" archivée.'
                                : 'Année "${year.name}" désarchivée.'),
                          ),
                        );
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          errorText = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isActive ? 'Archiver' : 'Désarchiver'),
            ),
          ],
        ),
      ),
    );
  }

  /// Avant, un trimestre ne pouvait être créé que depuis un détour par l'écran Leçons & Cours (au
  /// moment de créer un chapitre) — aucun moyen direct de le faire depuis la page qui gère
  /// justement les années scolaires et leur découpage temporel.
  void _showAddTermDialog(BuildContext context, SchoolYear year) {
    final nameCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    String? fieldError;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.calendar_month_rounded,
            iconColor: AppTheme.accentEmerald,
            text: 'Ajouter un Trimestre à "${year.name}"',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom (ex: Trimestre 1)',
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: year.startDate,
                              firstDate: year.startDate.subtract(const Duration(days: 30)),
                              lastDate: year.endDate.add(const Duration(days: 30)),
                            );
                            if (picked != null) setModalState(() => startDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(startDate == null
                              ? 'Début'
                              : DateFormat('dd/MM/yyyy').format(startDate!)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: startDate ?? year.startDate,
                              firstDate: year.startDate.subtract(const Duration(days: 30)),
                              lastDate: year.endDate.add(const Duration(days: 30)),
                            );
                            if (picked != null) setModalState(() => endDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(
                              endDate == null ? 'Fin' : DateFormat('dd/MM/yyyy').format(endDate!)),
                        ),
                      ),
                    ],
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(submitError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setModalState(() => fieldError = 'Le nom est obligatoire');
                        return;
                      }
                      if (startDate == null || endDate == null) {
                        setModalState(() => submitError = 'Les deux dates sont obligatoires.');
                        return;
                      }
                      if (!endDate!.isAfter(startDate!)) {
                        setModalState(() => submitError = 'La date de fin doit être après la date de début.');
                        return;
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.createTerm(
                          countryId: year.countryId,
                          name: name,
                          startDate: startDate!,
                          endDate: endDate!,
                          schoolYear: year.name,
                        );
                        ref.invalidate(termsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          submitError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Avant, un trimestre créé ne pouvait plus jamais être corrigé ni archivé — une erreur de date
  /// ou un trimestre obsolète restait bloqué pour toujours.
  void _showEditTermDialog(BuildContext context, Term term) {
    final nameCtrl = TextEditingController(text: term.name);
    DateTime startDate = term.startDate;
    DateTime endDate = term.endDate;
    bool isActive = term.isActive;
    String? fieldError;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: Icons.edit_calendar_rounded,
            text: 'Modifier "${term.name}"',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom du trimestre',
                      errorText: fieldError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1825)),
                              lastDate: DateTime.now().add(const Duration(days: 1825)),
                            );
                            if (picked != null) setModalState(() => startDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: endDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1825)),
                              lastDate: DateTime.now().add(const Duration(days: 1825)),
                            );
                            if (picked != null) setModalState(() => endDate = picked);
                          },
                          icon: const Icon(Icons.event_rounded, size: 16),
                          label: Text(DateFormat('dd/MM/yyyy').format(endDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: isActive,
                    activeColor: AppTheme.accentEmerald,
                    title: Text('Trimestre actif', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                    subtitle: Text(
                      isActive ? 'Visible et sélectionnable' : 'Archivé — masqué des sélecteurs de création',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    onChanged: (v) => setModalState(() => isActive = v ?? true),
                  ),
                  if (submitError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(submitError!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentRose)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setModalState(() => fieldError = 'Le nom est obligatoire');
                        return;
                      }
                      if (!endDate.isAfter(startDate)) {
                        setModalState(() => submitError = 'La date de fin doit être après la date de début.');
                        return;
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.updateTerm(
                          term.id,
                          name: name,
                          startDate: startDate,
                          endDate: endDate,
                          isActive: isActive,
                        );
                        ref.invalidate(termsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isLoading = false;
                          submitError = '$e';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
