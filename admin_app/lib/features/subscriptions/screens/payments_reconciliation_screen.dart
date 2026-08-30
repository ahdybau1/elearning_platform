import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/subscription_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/app_dialog_title.dart';

class PaymentsReconciliationScreen extends ConsumerStatefulWidget {
  const PaymentsReconciliationScreen({super.key});

  @override
  ConsumerState<PaymentsReconciliationScreen> createState() =>
      _PaymentsReconciliationScreenState();
}

class _PaymentsReconciliationScreenState
    extends ConsumerState<PaymentsReconciliationScreen> {
  int _activeTab = 0; // 0: Transactions Ambigües, 1: Demandes de Remboursement

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final canViewFinancials = authAsync.valueOrNull?.canViewFinancials ?? false;

    final ambiguousTxAsync = ref.watch(ambiguousTransactionsProvider);
    final refundAsync = ref.watch(refundRequestsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expanded : titre 26pt + sous-titre débordait hors de l'écran sur mobile (retour
              // utilisateur réel, 2026-08-30).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réconciliation Paiements & Remboursements',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestion des échecs réseau Mobile Money (Orange/MTN) et des litiges financiers',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!canViewFinancials) const SizedBox(width: 12),
              if (!canViewFinancials)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentRose),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: AppTheme.accentRose,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Montants masqués (Seul Super-Admin voit les chiffres)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentRose,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Tabs Switcher Bar
          Row(
            children: [
              _buildTabButton(0, 'Paiements Ambiguës', ambiguousTxAsync),
              const SizedBox(width: 12),
              _buildTabButton(1, 'Demandes de Remboursement', refundAsync),
              const Spacer(),
              // Ni l'un ni l'autre onglet n'est en temps réel (streams disponibles côté service
              // mais jamais branchés ici) : sans ce bouton, une nouvelle transaction ambiguë ou
              // demande de remboursement arrivée pendant que l'admin est sur cette page
              // n'apparaît qu'après avoir quitté puis reveni sur l'écran.
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
                tooltip: 'Actualiser',
                onPressed: () {
                  ref.invalidate(ambiguousTransactionsProvider);
                  ref.invalidate(refundRequestsProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main View Content
          Expanded(
            child: _activeTab == 0
                ? ambiguousTxAsync.when(
                    data: (transactions) => transactions.isEmpty
                        ? Center(
                            child: Text(
                              'Aucune transaction ambiguë pour le moment.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: transactions.length,
                            itemBuilder: (context, idx) {
                              final tx = transactions[idx];
                              return _buildTransactionItem(
                                context,
                                tx,
                                canViewFinancials,
                              );
                            },
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text(
                        'Erreur: $err',
                        style: GoogleFonts.inter(color: AppTheme.accentRose),
                      ),
                    ),
                  )
                : refundAsync.when(
                    data: (refunds) => refunds.isEmpty
                        ? Center(
                            child: Text(
                              'Aucune demande de remboursement pour le moment.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: refunds.length,
                            itemBuilder: (context, idx) {
                              final refReq = refunds[idx];
                              return _buildRefundRequestItem(
                                context,
                                refReq,
                                canViewFinancials,
                              );
                            },
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text(
                        'Erreur: $err',
                        style: GoogleFonts.inter(color: AppTheme.accentRose),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, AsyncValue asyncValue) {
    final isSelected = _activeTab == index;
    final count = asyncValue.maybeWhen(
      data: (list) => (list is List) ? list.length : 0,
      orElse: () => 0,
    );

    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.primaryBorder,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Transaction tx,
    bool canViewFinancials,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.accentAmber.withValues(alpha: 0.15),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.accentAmber,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Réf: ${tx.id} • Profil ${tx.profileId}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Opérateur : ${tx.operator} (${tx.phoneNumber ?? 'N/A'}) • Statut: ${tx.status}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Problème signalé : confirmation automatique du paiement non reçue',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.accentAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                canViewFinancials
                    ? '${tx.amount.toStringAsFixed(0)} FCFA'
                    : '•••• FCFA',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                tx.createdAt.toLocal().toString().split('.').first,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => _showReconcileConfirmation(context, tx, forceSuccess: true),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Valider Paiement'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentRose,
                  side: const BorderSide(color: AppTheme.accentRose),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => _showReconcileConfirmation(context, tx, forceSuccess: false),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Marquer Échoué'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Avant : "Valider Paiement" agissait immédiatement sans confirmation (action financière
  /// irréversible), et le message de succès affirmait que l'abonnement était activé — faux dans la
  /// plupart des cas : l'activation dépend d'un seuil de cumul mensuel atteint ou non (trigger
  /// handle_monthly_spend_accumulation), pas d'une simple validation de transaction. Et il n'existait
  /// aucun moyen de marquer une transaction ambiguë comme réellement échouée (ex: fraude) — l'admin
  /// était structurellement forcé de toujours valider.
  void _showReconcileConfirmation(BuildContext context, Transaction tx, {required bool forceSuccess}) {
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: forceSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
            iconColor: forceSuccess ? AppTheme.accentEmerald : AppTheme.accentRose,
            text: forceSuccess ? 'Valider ce paiement ?' : 'Marquer ce paiement comme échoué ?',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forceSuccess
                      ? 'La transaction sera marquée "réussie". L\'abonnement de l\'élève ne '
                          's\'active automatiquement QUE si son cumul mensuel atteint le seuil du '
                          'palier correspondant — vérifiez le profil élève si vous vous attendez à '
                          'une activation immédiate.'
                      : 'La transaction sera marquée "échouée". Aucun abonnement ne sera activé.',
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
                backgroundColor: forceSuccess ? AppTheme.accentEmerald : AppTheme.accentRose,
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
                        await service.reconcileTransaction(tx.id, forceSuccess ? 'success' : 'failed');
                        ref.invalidate(ambiguousTransactionsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: forceSuccess ? AppTheme.accentEmerald : AppTheme.accentRose,
                            content: Text(forceSuccess
                                ? 'Transaction marquée réussie.'
                                : 'Transaction marquée échouée.'),
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
                  : Text(forceSuccess ? 'Valider' : 'Marquer échoué'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundRequestItem(
    BuildContext context,
    RefundRequest refReq,
    bool canViewFinancials,
  ) {
    final isEligible = refReq.status == 'en_attente';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avant : deux Text non contraints côte à côte dans un Row spaceBetween — l'id de
              // demande + l'id de profil (deux UUID concaténés, ~80 caractères) dépassaient
              // facilement la largeur disponible sur une fenêtre normale ("RenderFlex overflowed"),
              // le même défaut que celui trouvé et corrigé sur la Matrice de Droits.
              Expanded(
                child: Text(
                  'Demande : ${refReq.id} • Profil ${refReq.profileId}',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                canViewFinancials
                    ? '${refReq.transaction?.amount.toStringAsFixed(0) ?? '••••'} FCFA'
                    : '•••• FCFA',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentRose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Motif : ${refReq.motive}',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          if (refReq.decisionReason != null) ...[
            const SizedBox(height: 4),
            Text(
              'Décision : ${refReq.decisionReason}',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isEligible
                  ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                  : AppTheme.accentRose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              refReq.status,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isEligible
                    ? AppTheme.accentEmerald
                    : AppTheme.accentRose,
              ),
            ),
          ),
          if (isEligible) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRose,
                    side: const BorderSide(color: AppTheme.accentRose),
                  ),
                  onPressed: () => _showRefundDecisionDialog(context, refReq, accept: false),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Refuser la demande'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentEmerald,
                  ),
                  onPressed: () => _showRefundDecisionDialog(context, refReq, accept: true),
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Accepter le Remboursement'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Avant : les deux actions s'exécutaient immédiatement sans confirmation (décision financière
  /// irréversible), le motif de décision (decision_reason, colonne existante en base) n'était
  /// jamais collecté, et un admin non authentifié au moment du clic aurait silencieusement écrit un
  /// UUID factice dans decided_by (colonne sans contrainte FK — corruption invisible de la piste
  /// d'audit). Et "Remboursement exécuté" laissait croire qu'un virement Mobile Money avait
  /// réellement eu lieu : cette action ne fait que changer un statut en base, aucun appel API
  /// agrégateur n'existe — l'admin doit encore déclencher le vrai remboursement manuellement.
  void _showRefundDecisionDialog(BuildContext context, RefundRequest refReq, {required bool accept}) {
    final reasonController = TextEditingController();
    String? fieldError;
    String? submitError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.primarySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: AppDialogTitle(
            icon: accept ? Icons.check_circle_rounded : Icons.cancel_rounded,
            iconColor: accept ? AppTheme.accentEmerald : AppTheme.accentRose,
            text: accept ? 'Accepter ce remboursement ?' : 'Refuser cette demande ?',
            onClose: () => Navigator.pop(ctx),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accept)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Ceci marque la demande comme acceptée EN BASE uniquement — aucun virement '
                      'Mobile Money n\'est déclenché automatiquement. Vous devrez effectuer le '
                      'remboursement réel vous-même via votre agrégateur (Orange Money / MTN MoMo) '
                      'après validation ici.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accentAmber, height: 1.4),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: accept ? 'Note (optionnel)' : 'Motif du refus',
                    hintText: accept
                        ? 'Ex: Remboursé via Orange Money le ...'
                        : 'Ex: Délai de rétractation dépassé',
                    errorText: fieldError,
                  ),
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
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accept ? AppTheme.accentEmerald : AppTheme.accentRose,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final reason = reasonController.text.trim();
                      if (!accept && reason.isEmpty) {
                        setModalState(() => fieldError = 'Le motif du refus est obligatoire');
                        return;
                      }
                      final adminId = ref.read(authProvider).valueOrNull?.id;
                      if (adminId == null) {
                        setModalState(() => submitError =
                            'Session administrateur non résolue — rechargez la page avant de réessayer.');
                        return;
                      }
                      setModalState(() {
                        fieldError = null;
                        submitError = null;
                        isLoading = true;
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final service = ref.read(supabaseServiceProvider);
                        await service.decideRefund(
                          refReq.id,
                          accept ? 'accepte' : 'refuse',
                          decidedBy: adminId,
                          reason: reason.isEmpty ? null : reason,
                        );
                        ref.invalidate(refundRequestsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: accept ? AppTheme.accentEmerald : AppTheme.accentRose,
                            content: Text(accept
                                ? 'Demande acceptée — pensez à effectuer le virement manuellement.'
                                : 'Demande refusée.'),
                          ),
                        );
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
                  : Text(accept ? 'Accepter' : 'Refuser'),
            ),
          ],
        ),
      ),
    );
  }
}
