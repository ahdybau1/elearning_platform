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
                icon: const Icon(Icons.shopping_bag_outlined, color: StudentTheme.accentPrimary),
                tooltip: 'Boutique de documents à la carte',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Scaffold(
                      backgroundColor: StudentTheme.backgroundDark,
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
            color: StudentTheme.surfaceDark,
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: StudentTheme.accentPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Espace cloisonné : seuls les élèves de ${profile?.className ?? 'votre classe'} ont accès à ce fil.',
                    style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textSecondary),
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
                        color: StudentTheme.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: StudentTheme.borderDark),
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
                                      style: GoogleFonts.inter(fontSize: 11, color: StudentTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: StudentTheme.surfaceDark,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Élève', style: TextStyle(fontSize: 10, color: StudentTheme.textSecondary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            post.content,
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.thumb_up_alt_outlined, size: 16, color: StudentTheme.textSecondary),
                                    onPressed: () {},
                                  ),
                                  Text('${post.likesCount}', style: const TextStyle(fontSize: 12, color: StudentTheme.textSecondary)),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.mode_comment_outlined, size: 16, color: StudentTheme.textSecondary),
                                    onPressed: () {},
                                  ),
                                  Text('${post.repliesCount} réponses', style: const TextStyle(fontSize: 12, color: StudentTheme.textSecondary)),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ouverture du fil de discussion...')),
                                  );
                                },
                                child: const Text('Répondre', style: TextStyle(color: StudentTheme.accentPrimary, fontSize: 12)),
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
            decoration: const BoxDecoration(
              color: StudentTheme.surfaceDark,
              border: Border(top: BorderSide(color: StudentTheme.borderDark)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Poser une question à la classe...',
                      hintStyle: GoogleFonts.inter(color: StudentTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: StudentTheme.cardDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: StudentTheme.borderDark),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: StudentTheme.accentPrimary),
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
                        const SnackBar(
                          backgroundColor: StudentTheme.accentEmerald,
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
