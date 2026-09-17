import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/student_models.dart';
import '../../../core/theme/student_theme.dart';

/// Une notification réelle (`notification_log`) — jamais un texte généré côté client.
class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification, this.onTap});

  final StudentNotification notification;
  final VoidCallback? onTap;

  static const _channelIcons = {
    'push': Icons.notifications_active_rounded,
    'in_app': Icons.campaign_rounded,
    'email': Icons.mail_outline_rounded,
  };

  String _relativeTime(DateTime sentAt) {
    final diff = DateTime.now().difference(sentAt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}/${sentAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = notification.isUnread;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? context.colors.accentPrimary.withValues(alpha: 0.08)
              : context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread ? context.colors.accentPrimary.withValues(alpha: 0.4) : context.colors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _channelIcons[notification.channel] ?? Icons.notifications_rounded,
                size: 18,
                color: isUnread ? context.colors.accentPrimary : context.colors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: GoogleFonts.inter(fontSize: 12.5, color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(notification.sentAt),
                    style: GoogleFonts.inter(fontSize: 10.5, color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                key: ValueKey('notification_unread_dot_${notification.id}'),
                margin: const EdgeInsets.only(top: 2, left: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.colors.accentPrimary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
