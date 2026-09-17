import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/services/local_chat_storage_service.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';

/// Tiroir d'historique des discussions calqué sur ChatGPT / Gemini
/// Gère la sélection, le renommage, la suppression et le quota strict des 10 conversations
class ChatHistoryDrawer extends StatelessWidget {
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onNewSession;
  final ValueChanged<String> onDeleteSession;
  final Function(String sessionId, String newTitle) onRenameSession;
  final VoidCallback onClearAll;

  const ChatHistoryDrawer({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onNewSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onClearAll,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes == 0 ? "quelques instants" : "${difference.inMinutes} min"}';
    } else if (difference.inHours < 24 && now.day == dt.day) {
      return 'Aujourd\'hui à ${DateFormat('HH:mm').format(dt)}';
    } else if (difference.inDays < 2) {
      return 'Hier à ${DateFormat('HH:mm').format(dt)}';
    } else {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(dt);
    }
  }

  void _showRenameDialog(BuildContext context, ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Renommer la discussion',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Titre de la discussion',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                onRenameSession(session.id, newTitle);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSession(BuildContext context, ChatSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Supprimer cette discussion ?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          'Cette action effacera les messages stockés sur votre appareil pour "${session.title}".',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              onDeleteSession(session.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Effacer tout l\'historique ?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: const Text(
          'Toutes vos conversations stockées localement sur ce téléphone seront définitivement effacées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              onClearAll();
              Navigator.of(ctx).pop();
            },
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final count = sessions.length;
    final isAtMaxQuota = count >= LocalChatStorageService.maxSessions;

    // Répartition chronologique
    final now = DateTime.now();
    final todaySessions = <ChatSession>[];
    final lastWeekSessions = <ChatSession>[];
    final olderSessions = <ChatSession>[];

    for (final s in sessions) {
      final diff = now.difference(s.updatedAt);
      if (diff.inDays == 0 && now.day == s.updatedAt.day) {
        todaySessions.add(s);
      } else if (diff.inDays <= 7) {
        lastWeekSessions.add(s);
      } else {
        olderSessions.add(s);
      }
    }

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          children: [
            // En-tête du Drawer avec bouton Nouvelle discussion
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.aiCompanionGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Conversations',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Bouton + Nouvelle discussion (style ChatGPT)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      foregroundColor: AppColors.cyanAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                        side: BorderSide(
                          color: AppColors.cyanAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      elevation: 1,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onNewSession();
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      'Nouvelle discussion',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Jauge du quota local (règle des 10 conversations)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAtMaxQuota
                          ? Colors.amber.withValues(alpha: 0.15)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAtMaxQuota
                            ? Colors.amber.withValues(alpha: 0.5)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Stockage local',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isAtMaxQuota
                                      ? Colors.amber
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$count / ${LocalChatStorageService.maxSessions} chats',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isAtMaxQuota
                                    ? Colors.amber
                                    : AppColors.cyanAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: count / LocalChatStorageService.maxSessions,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isAtMaxQuota
                                  ? Colors.amber
                                  : AppColors.cyanAccent,
                            ),
                            minHeight: 5,
                          ),
                        ),
                        if (isAtMaxQuota) ...[
                          const SizedBox(height: 6),
                          Text(
                            '⚠️ Limite atteinte : supprimez une ancienne discussion pour en démarrer une autre.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Liste scrollable des conversations groupées
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 44,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune discussion enregistrée',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      children: [
                        if (todaySessions.isNotEmpty) ...[
                          _buildSectionHeader('Aujourd\'hui', isDark),
                          ...todaySessions.map((s) => _buildSessionTile(
                                context,
                                s,
                                isDark,
                              )),
                        ],
                        if (lastWeekSessions.isNotEmpty) ...[
                          _buildSectionHeader('7 derniers jours', isDark),
                          ...lastWeekSessions.map((s) => _buildSessionTile(
                                context,
                                s,
                                isDark,
                              )),
                        ],
                        if (olderSessions.isNotEmpty) ...[
                          _buildSectionHeader('Plus ancien', isDark),
                          ...olderSessions.map((s) => _buildSessionTile(
                                context,
                                s,
                                isDark,
                              )),
                        ],
                      ],
                    ),
            ),

            const Divider(height: 1),

            // Pied de page : Vider l'historique & badge local
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (sessions.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _confirmClearAll(context),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Effacer tout l\'historique'),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.smartphone_rounded,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Stocké localement (zéro charge BDD)',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }

  Widget _buildSessionTile(
    BuildContext context,
    ChatSession session,
    bool isDark,
  ) {
    final isSelected = session.id == activeSessionId;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: AppColors.cyanAccent.withValues(alpha: 0.4),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: isSelected
            ? (isDark
                ? AppColors.cyanAccent.withValues(alpha: 0.15)
                : AppColors.cyanAccent.withValues(alpha: 0.1))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(
          isSelected
              ? Icons.chat_bubble_rounded
              : Icons.chat_bubble_outline_rounded,
          size: 18,
          color: isSelected
              ? AppColors.cyanAccent
              : (isDark ? Colors.white54 : Colors.black54),
        ),
        title: Text(
          session.title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatDate(session.updatedAt)} • ${session.messages.length} msg',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          onSelectSession(session.id);
        },
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            size: 16,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
          onSelected: (action) {
            if (action == 'rename') {
              _showRenameDialog(context, session);
            } else if (action == 'delete') {
              _confirmDeleteSession(context, session);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Renommer'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 16, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
