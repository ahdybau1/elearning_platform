import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/subscription_models.dart';
import '../../../core/providers/data_providers.dart';

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
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                  'Problème : Webhook non reçu',
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
          const SizedBox(width: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
            ),
            onPressed: () async {
              final service = ref.read(supabaseServiceProvider);
              await service.reconcileTransaction(tx.id, 'success');
              ref.refresh(ambiguousTransactionsProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Paiement réconcilié ! L\'abonnement de l\'élève est activé.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Valider Paiement'),
          ),
        ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Demande : ${refReq.id} • Profil ${refReq.profileId}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentRose,
                  side: const BorderSide(color: AppTheme.accentRose),
                ),
                onPressed: () async {
                  final service = ref.read(supabaseServiceProvider);
                  await service.decideRefund(
                    refReq.id,
                    'refuse',
                    decidedBy: 'admin',
                  );
                  ref.refresh(refundRequestsProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demande refusée.')),
                    );
                  }
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Refuser la demande'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                ),
                onPressed: () async {
                  final service = ref.read(supabaseServiceProvider);
                  await service.decideRefund(
                    refReq.id,
                    'accepte',
                    decidedBy: 'admin',
                  );
                  ref.refresh(refundRequestsProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Remboursement exécuté.')),
                    );
                  }
                },
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Exécuter le Remboursement'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
