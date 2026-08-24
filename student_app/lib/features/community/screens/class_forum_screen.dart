import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../core/widgets/student_screen_header.dart';
import '../../subscription/screens/boutique_shop_screen.dart';

class ClassForumScreen extends ConsumerStatefulWidget {
  const ClassForumScreen({super.key});

  @override
  ConsumerState<ClassForumScreen> createState() => _ClassForumScreenState();
}

class _ClassForumScreenState extends ConsumerState<ClassForumScreen> {
  final TextEditingController _postCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final postsAsync = ref.watch(studentForumPostsProvider(profile?.classNodeId ?? ''));

    return StudentPageContent(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: StudentScreenHeader(
              title: 'Forum de Classe (${profile?.className ?? ''})',
              trailing: IconButton(
                icon: Icon(Icons.shopping_bag_outlined, color: context.colors.accentPrimary),
                tooltip: 'Boutique de documents à la carte',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Scaffold(
                      backgroundColor: context.colors.background,
                      appBar: AppBar(automaticallyImplyLeading: true),
                      body: const BoutiqueShopScreen(),
                    )),
                  );
                },
              ),
            ),
          ),
          // Class Isolation Notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: context.colors.surface,
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: context.colors.accentPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Espace cloisonné : seuls les élèves de ${profile?.className ?? 'votre classe'} ont accès à ce fil.',
                    style: GoogleFonts.inter(fontSize: 11, color: context.colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          // Posts Feed
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.red))),
              data: (posts) {
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final post = posts[index];

                    return Container(
                      padding: const EdgeInsets.all(16),
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
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: StudentTheme.primaryGradient,
                                ),
                                child: Center(
                                  child: Text(
                                    post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'A',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.authorName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Il y a quelques heures',
                                      style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Élève', style: TextStyle(fontSize: 10, color: context.colors.textSecondary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            post.content,
                            style: GoogleFonts.inter(fontSize: 14, color: context.colors.textPrimary, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.thumb_up_alt_outlined, size: 16, color: context.colors.textSecondary),
                                    onPressed: () {},
                                  ),
                                  Text('${post.likesCount}', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: Icon(Icons.mode_comment_outlined, size: 16, color: context.colors.textSecondary),
                                    onPressed: () {},
                                  ),
                                  Text('${post.repliesCount} réponses', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ouverture du fil de discussion...')),
                                  );
                                },
                                child: Text('Répondre', style: TextStyle(color: context.colors.accentPrimary, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom New Post Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(top: BorderSide(color: context.colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postCtrl,
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Poser une question à la classe...',
                      hintStyle: GoogleFonts.inter(color: context.colors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: context.colors.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: context.colors.accentPrimary),
                  onPressed: () {
                    if (_postCtrl.text.trim().isNotEmpty && profile != null) {
                      ref.read(studentSupabaseServiceProvider).createForumPost(
                            classNodeId: profile.classNodeId,
                            profileId: profile.id,
                            authorName: profile.name,
                            content: _postCtrl.text.trim(),
                          );
                      _postCtrl.clear();
                      ref.invalidate(studentForumPostsProvider(profile.classNodeId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: context.colors.accentEmerald,
                          content: Text('Votre message a été publié après modération IA automatique.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
