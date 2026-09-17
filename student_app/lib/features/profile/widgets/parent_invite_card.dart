import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';

/// Carte « Inviter un parent » de l'écran profil — extraite de `StudentProfileScreen`
/// (`_buildParentInviteCard` + `_redeemParentInviteCode`, découpage du fichier monolithique).
///
/// §17 du cahier des charges : le parent crée son propre compte (auto-inscription, voir
/// student_login_screen.dart) et prouve son lien à cet enfant avec ce code plutôt qu'en partageant
/// un mot de passe ou en attendant une validation admin — voir migration 44.
class ParentInviteCard extends ConsumerStatefulWidget {
  const ParentInviteCard({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ParentInviteCard> createState() => _ParentInviteCardState();
}

class _ParentInviteCardState extends ConsumerState<ParentInviteCard> {
  final _parentCodeCtrl = TextEditingController();
  bool _isRedeemingParentCode = false;

  @override
  void dispose() {
    _parentCodeCtrl.dispose();
    super.dispose();
  }

  /// Sens inverse de « Inviter un parent » : un parent a généré son propre code (voir
  /// ParentAuthNotifier.getOrCreateInviteCode, migration 49) et l'élève le saisit ici pour se lier.
  Future<void> _redeemParentInviteCode() async {
    final code = _parentCodeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _isRedeemingParentCode = true);
    final error = await ref
        .read(studentSupabaseServiceProvider)
        .redeemParentInviteCode(code);
    if (!mounted) return;
    setState(() => _isRedeemingParentCode = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code invalide ou liaison impossible.')),
      );
    } else {
      _parentCodeCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Parent lié avec succès.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeAsync = ref.watch(parentLinkCodeProvider(widget.profileId));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.family_restroom_rounded,
                color: context.colors.accentAmber,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inviter un parent',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Donnez ce code à votre parent — il l\'utilisera en s\'inscrivant à son propre compte pour suivre votre scolarité (valable 24h).',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              codeAsync.when(
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (err, _) => Icon(
                  Icons.error_outline_rounded,
                  color: context.colors.accentRose,
                ),
                data: (code) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    code,
                    style: GoogleFonts.firaCode(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: context.colors.accentAmber,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.colors.border, height: 1),
          const SizedBox(height: 16),
          Text(
            'Votre parent a déjà son propre code ?',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _parentCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Code donné par votre parent',
                    hintStyle: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: context.colors.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isRedeemingParentCode
                    ? null
                    : _redeemParentInviteCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accentAmber,
                ),
                child: _isRedeemingParentCode
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Lier',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
