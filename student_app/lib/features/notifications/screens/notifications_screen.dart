import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../design_system/components/empty_state_view.dart';
import '../widgets/notification_tile.dart';

/// §6.4 du cahier des charges : historique réel des notifications (échéances d'abonnement,
/// requalification mensuelle, rappels d'examens...) — remplace le placeholder de la cloche
/// d'accueil ("Tes notifications seront regroupées ici.").
///
/// Poussée en route autonome (pas un onglet de `MainNavigationScreen`, absente du tableau des
/// groupes de navigation du §20 — un centre de notifications est déclenché depuis la cloche,
/// jamais un onglet permanent) : porte donc son propre `Scaffold`/`AppBar`, contrairement aux
/// pages de contenu qui utilisent `StudentScreenHeader` sous la barre partagée du shell.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentAuthProvider).activeProfile;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notifications', style: TextStyle(color: context.colors.textPrimary)),
      ),
      body: StudentPageContent(
        child: profile == null
            ? const Center(child: CircularProgressIndicator())
            : Consumer(
                builder: (context, ref, _) {
                  final notificationsAsync = ref.watch(notificationsProvider(profile.id));
                  return RefreshIndicator(
                        onRefresh: () async => ref.invalidate(notificationsProvider(profile.id)),
                        child: notificationsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, _) => ListView(
                            children: [
                              EmptyStateView(
                                icon: Icons.cloud_off_rounded,
                                title: 'Notifications indisponibles',
                                description: 'Impossible de charger vos notifications pour le moment.',
                                iconColor: context.colors.accentAmber,
                                actionLabel: 'Réessayer',
                                onAction: () => ref.invalidate(notificationsProvider(profile.id)),
                              ),
                            ],
                          ),
                          data: (items) {
                            if (items.isEmpty) {
                              return ListView(
                                children: [
                                  EmptyStateView(
                                    icon: Icons.notifications_none_rounded,
                                    title: 'Aucune notification',
                                    description:
                                        'Les échéances d\'abonnement, rappels et autres informations importantes apparaîtront ici.',
                                  ),
                                ],
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final notification = items[index];
                                return NotificationTile(
                                  notification: notification,
                                  onTap: notification.isUnread
                                      ? () async {
                                          await ref
                                              .read(studentSupabaseServiceProvider)
                                              .markNotificationOpened(notification.id);
                                          ref.invalidate(notificationsProvider(profile.id));
                                        }
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                      );
                },
              ),
      ),
    );
  }
}
