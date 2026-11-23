import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/rendering/latex_to_unicode_converter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/student_auth_provider.dart';
import '../../../core/models/student_models.dart';
import '../../../core/providers/student_providers.dart';
import '../../../core/rendering/ai_message_bubble_renderer.dart';
import '../../../core/services/local_chat_storage_service.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/widgets/student_page_content.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../pedagogy/widgets/photo_transcription_modal.dart';
import '../widgets/chat_attachment_pill.dart';
import '../widgets/chat_history_drawer.dart';
import '../widgets/chat_multimodal_dock.dart';

class AiTutorChatScreen extends ConsumerStatefulWidget {
  final String? subjectId;
  final String? subjectName;
  final String? lessonId;
  final String? classNodeId;
  final String? chapterId;

  const AiTutorChatScreen({
    super.key,
    this.subjectId,
    this.subjectName,
    this.lessonId,
    this.classNodeId,
    this.chapterId,
  });

  @override
  ConsumerState<AiTutorChatScreen> createState() => _AiTutorChatScreenState();
}

class _AiTutorChatScreenState extends ConsumerState<AiTutorChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  bool _isLoadingSessions = true;
  bool _isGenerating = false;

  /// Jusqu'à 4 suggestions tirées du parcours de l'élève (exercices ratés, compétences faibles,
  /// leçons terminées, chapitres en cours de SA classe), puis la photo. Les suggestions générales ne
  /// servent que si la classe n'a encore rien (aucun chapitre, aucun exercice).
  List<Map<String, dynamic>> _starters() {
    const icons = {
      TutorSuggestionKind.retry: Icons.replay_rounded,
      TutorSuggestionKind.weakSkill: Icons.trending_up_rounded,
      TutorSuggestionKind.check: Icons.fact_check_outlined,
      TutorSuggestionKind.chapter: Icons.menu_book_outlined,
    };
    final generic = _genericStarters();
    final photo = generic.firstWhere((g) => g['action'] == 'photo');
    if (_personal.isEmpty) return generic;
    return [
      for (final p in _personal)
        {'icon': icons[p.kind], 'title': p.title, 'subtitle': p.subtitle, 'prompt': p.prompt},
      photo,
    ];
  }

  /// Suggestions de départ adaptées à la matière ouverte (ou générales), valables de la 6e à la
  /// Terminale et dans toutes les matières. Les anciennes cartes proposaient à tous les élèves des
  /// sujets de Terminale scientifique (polynômes, TVI, dérivée d'un quotient).
  List<Map<String, dynamic>> _genericStarters() {
    final subject = widget.subjectName;
    if (subject != null && subject.trim().isNotEmpty) {
      return [
        {
          'icon': Icons.lightbulb_outline_rounded,
          'title': 'Comprendre une notion de $subject',
          'prompt': 'Je veux comprendre une notion de $subject. Demande-moi laquelle, puis explique-la simplement avec un exemple.',
        },
        {
          'icon': Icons.edit_note_rounded,
          'title': 'M\'entraîner en $subject',
          'prompt': 'Donne-moi un exercice de $subject adapté à mon niveau, attends ma réponse, puis corrige-la.',
        },
        {
          'icon': Icons.quiz_outlined,
          'title': 'Réviser $subject en 5 questions',
          'prompt': 'Pose-moi 5 questions rapides, une par une, pour réviser $subject.',
        },
        {
          'icon': Icons.photo_camera_outlined,
          'title': 'Envoyer la photo d\'un exercice',
          'prompt': 'Aide-moi à résoudre cet exercice pas à pas.',
          'action': 'photo',
        },
      ];
    }
    return [
      {
        'icon': Icons.lightbulb_outline_rounded,
        'title': 'Comprendre une leçon',
        'prompt': 'Je n\'ai pas compris une leçon. Demande-moi la matière et le chapitre, puis explique-la simplement.',
      },
      {
        'icon': Icons.fact_check_outlined,
        'title': 'Vérifier ma réponse',
        'prompt': 'Je vais te donner un exercice et ma réponse : dis-moi si elle est juste et pourquoi.',
      },
      {
        'icon': Icons.event_note_outlined,
        'title': 'Préparer un devoir',
        'prompt': 'J\'ai bientôt un devoir. Aide-moi à organiser mes révisions : demande-moi la matière et les chapitres.',
      },
      {
        'icon': Icons.photo_camera_outlined,
        'title': 'Envoyer la photo d\'un exercice',
        'prompt': 'Aide-moi à résoudre cet exercice pas à pas.',
        'action': 'photo',
      },
    ];
  }

  /// Suggestions tirées du parcours réel de l'élève (exercices ratés, leçons terminées, chapitre
  /// en cours de SA classe). Chargées une fois ; les suggestions générales ne font que compléter.
  List<TutorSuggestion> _personal = const [];
  bool _personalLoaded = false;

  Future<void> _loadPersonalSuggestions() async {
    final profile = ref.read(studentAuthProvider).activeProfile;
    final classNodeId = widget.classNodeId ?? profile?.classNodeId ?? '';
    if (profile == null || classNodeId.isEmpty) {
      setState(() => _personalLoaded = true);
      return;
    }
    try {
      final list = await ref.read(studentSupabaseServiceProvider).fetchTutorSuggestions(
            profileId: profile.id,
            classNodeId: classNodeId,
            subjectId: widget.subjectId,
          );
      if (mounted) setState(() => _personal = list);
    } finally {
      if (mounted) setState(() => _personalLoaded = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLocalSessions();
    _loadPersonalSuggestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getActiveProfileId() {
    final profile = ref.read(studentAuthProvider).activeProfile;
    return profile?.id ?? 'default_student';
  }

  Future<void> _loadLocalSessions() async {
    final storage = ref.read(localChatStorageServiceProvider);
    final profileId = _getActiveProfileId();
    final sessions = await storage.getSessions(profileId);

    if (!mounted) return;

    setState(() {
      _sessions = sessions;
      _isLoadingSessions = false;
      if (sessions.isNotEmpty) {
        _currentSession = sessions.first;
      } else {
        _createNewSessionInternal();
      }
    });
  }

  void _createNewSessionInternal() {
    final profileId = _getActiveProfileId();
    final newSession = ChatSession(
      id: UniqueKey().toString(),
      title: 'Nouvelle discussion',
      profileId: profileId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [
        ChatMessage(
          id: 'welcome_msg',
          sender: 'ai',
          text: 'Bonjour ! Je suis ton Tuteur pq learn.\n'
              'Pose-moi une question, joins une photo de ton devoir, un document PDF ou un message vocal. Je te guiderai pas-à-pas sans te donner la solution brute !',
          timestamp: DateTime.now(),
        ),
      ],
    );

    setState(() {
      _currentSession = newSession;
    });
  }

  Future<void> _handleNewSessionRequest() async {
    final storage = ref.read(localChatStorageServiceProvider);
    final profileId = _getActiveProfileId();
    final canCreate = await storage.canCreateNewSession(profileId);

    if (!canCreate && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'Limite de stockage atteinte',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Tu as déjà ${LocalChatStorageService.maxSessions} conversations enregistrées sur ton téléphone.\n\n'
            'Afin de préserver l\'espace de stockage de ton appareil, supprime au moins une ancienne conversation avant d\'en créer une nouvelle.',
            style: GoogleFonts.inter(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Compris'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: Colors.black87,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _scaffoldKey.currentState?.openDrawer();
              },
              child: const Text('Gérer l\'historique'),
            ),
          ],
        ),
      );
      return;
    }

    _createNewSessionInternal();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _saveCurrentSession() async {
    if (_currentSession == null) return;
    final storage = ref.read(localChatStorageServiceProvider);
    await storage.saveSession(_currentSession!);
    final profileId = _getActiveProfileId();
    final updatedList = await storage.getSessions(profileId);
    if (mounted) {
      setState(() {
        _sessions = updatedList;
      });
    }
  }

  Future<void> _sendMessage(String text, [List<ChatAttachment> attachments = const []]) async {
    if ((text.trim().isEmpty && attachments.isEmpty) || _isGenerating) return;

    final profile = ref.read(studentAuthProvider).activeProfile;
    final userMsg = ChatMessage(
      id: UniqueKey().toString(),
      sender: 'user',
      text: text.trim(),
      timestamp: DateTime.now(),
      attachments: attachments,
    );

    // Titre automatique de la discussion basé sur le premier message de l'élève
    String sessionTitle = _currentSession?.title ?? 'Nouvelle discussion';
    if (_currentSession != null &&
        (_currentSession!.title == 'Nouvelle discussion' || _currentSession!.messages.length <= 1)) {
      if (text.trim().isNotEmpty) {
        sessionTitle = text.trim().length > 35
            ? '${text.trim().substring(0, 35)}...'
            : text.trim();
      } else if (attachments.isNotEmpty) {
        sessionTitle = 'Analyse : ${attachments.first.name}';
      }
    }

    final updatedMessages = List<ChatMessage>.from(_currentSession?.messages ?? [])..add(userMsg);

    setState(() {
      _currentSession = _currentSession?.copyWith(
            title: sessionTitle,
            messages: updatedMessages,
            updatedAt: DateTime.now(),
          ) ??
          ChatSession(
            id: UniqueKey().toString(),
            title: sessionTitle,
            profileId: _getActiveProfileId(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            messages: updatedMessages,
          );
      _isGenerating = true;
    });

    _scrollToBottom();
    await _saveCurrentSession();

    // Préparation de la charge utile pour l'Edge Function
    final attachmentsPayload = attachments.map((a) {
      return {
        'name': a.name,
        'mime_type': a.mimeType,
        'data': a.base64Data,
      };
    }).toList();

    try {
      final effectiveClassNodeId = widget.classNodeId ?? (profile?.classNodeId.isNotEmpty == true ? profile?.classNodeId : null);
      final effectiveSubjectId = widget.subjectId;
      final effectiveSubjectName = widget.subjectName;

      final response = await Supabase.instance.client.functions
          .invoke(
            'ai-tutor-chat',
            body: {
              'message': text.trim().isNotEmpty ? text.trim() : 'Analyse ces pièces jointes.',
              'class_name': profile?.className,
              'profile_id': profile?.id,
              'class_node_id': effectiveClassNodeId,
              'subject_id': effectiveSubjectId,
              'subject_name': effectiveSubjectName,
              'lesson_id': widget.lessonId,
              'history': updatedMessages.take(updatedMessages.length - 1).map((m) {
                return {'sender': m.sender, 'text': m.text};
              }).toList(),
              'attachments': attachmentsPayload,
            },
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      final data = response.data;
      final reply = data is Map ? data['reply'] as String? : null;
      final citationsRaw = data is Map ? data['citations'] as List<dynamic>? : null;
      final citations = citationsRaw?.map((c) => Map<String, dynamic>.from(c as Map)).toList() ?? [];

      final aiMsg = ChatMessage(
        id: UniqueKey().toString(),
        sender: 'ai',
        text: reply?.trim().isNotEmpty == true
            ? reply!
            : 'Le Tuteur pq learn n\'a pas pu produire de réponse. Réessaie dans un instant.',
        timestamp: DateTime.now(),
        citations: citations,
      );

      final finalMessages = List<ChatMessage>.from(_currentSession!.messages)..add(aiMsg);

      setState(() {
        _isGenerating = false;
        _currentSession = _currentSession!.copyWith(messages: finalMessages);
      });

      _scrollToBottom();
      await _saveCurrentSession();
    } catch (e) {
      if (!mounted) return;

      String errorText;
      if (e is TimeoutException) {
        errorText = 'Le calcul ou l\'analyse prend plus de temps que prévu (délai d\'attente dépassé). '
            'Ta question et tes pièces jointes sont bien conservées. Clique sur Réessayer ci-dessous.';
      } else {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('503') || errStr.contains('unavailable') || errStr.contains('surchargé')) {
          errorText = 'Le serveur de calcul IA est momentanément très sollicité. '
              'Tes documents sont conservés intacts. Clique sur Réessayer ci-dessous pour relancer.';
        } else if (errStr.contains('network') ||
            errStr.contains('socket') ||
            errStr.contains('connexion') ||
            errStr.contains('failed to fetch') ||
            errStr.contains('clientexception')) {
          errorText = 'Connexion réseau instable ou interrompue. '
              'Ta question et tes pièces jointes sont sauvegardées sur ton appareil. Clique sur Réessayer dès que le réseau revient.';
        } else {
          errorText = 'Le service du Tuteur pq learn a rencontré une courte interruption temporaire. '
              'Ta question et tes pièces jointes sont conservées. Clique sur Réessayer pour continuer.';
        }
      }

      final errorMsg = ChatMessage(
        id: UniqueKey().toString(),
        sender: 'ai',
        text: errorText,
        timestamp: DateTime.now(),
        isError: true,
      );

      final finalMessages = List<ChatMessage>.from(_currentSession!.messages)..add(errorMsg);

      setState(() {
        _isGenerating = false;
        _currentSession = _currentSession!.copyWith(messages: finalMessages);
      });

      _scrollToBottom();
      await _saveCurrentSession();
    }
  }

  void _retryLastMessage() {
    if (_currentSession == null || _isGenerating) return;
    final messages = List<ChatMessage>.from(_currentSession!.messages);
    if (messages.isEmpty) return;

    // Supprimer le message d'erreur si présent en fin de liste
    if (messages.last.isAi &&
        (messages.last.isError ||
            messages.last.text.contains('momentanément') ||
            messages.last.text.contains('attente réseau') ||
            messages.last.text.contains('Réessayer') ||
            messages.last.text.contains('délai'))) {
      messages.removeLast();
    }

    // Trouver le dernier message élève
    final lastUserIndex = messages.lastIndexWhere((m) => m.sender == 'user');
    if (lastUserIndex < 0) return;

    final userMsg = messages[lastUserIndex];
    // Supprimer ce dernier message utilisateur car _sendMessage va le réajouter
    messages.removeAt(lastUserIndex);

    setState(() {
      _currentSession = _currentSession!.copyWith(messages: messages);
    });

    _sendMessage(userMsg.text, userMsg.attachments);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(studentAuthProvider).activeProfile;
    final messages = _currentSession?.messages ?? [];
    final hasUserMessages = messages.any((m) => m.sender == 'user');
    final isAtMaxQuota = _sessions.length >= LocalChatStorageService.maxSessions;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      drawer: ChatHistoryDrawer(
        sessions: _sessions,
        activeSessionId: _currentSession?.id,
        onSelectSession: (id) {
          final found = _sessions.firstWhere((s) => s.id == id);
          setState(() {
            _currentSession = found;
          });
          _scrollToBottom();
        },
        onNewSession: _handleNewSessionRequest,
        onDeleteSession: (id) async {
          final storage = ref.read(localChatStorageServiceProvider);
          final profileId = _getActiveProfileId();
          await storage.deleteSession(profileId, id);
          await _loadLocalSessions();
        },
        onRenameSession: (id, newTitle) async {
          final storage = ref.read(localChatStorageServiceProvider);
          final profileId = _getActiveProfileId();
          await storage.renameSession(profileId, id, newTitle);
          await _loadLocalSessions();
        },
        onClearAll: () async {
          final storage = ref.read(localChatStorageServiceProvider);
          final profileId = _getActiveProfileId();
          await storage.clearAllSessions(profileId);
          await _loadLocalSessions();
        },
      ),
      body: StudentPageContent(
        child: Column(
          children: [
            // Barre supérieure moderne façon ChatGPT / Gemini
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(
                  bottom: BorderSide(
                    color: colors.border.withValues(alpha: 0.7),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Bouton menu Drawer pour ouvrir l'historique
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, size: 22),
                    tooltip: 'Historique des discussions',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),

                  const SizedBox(width: 4),

                  // Pastille centrale du Modèle Tuteur Socratique IA
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.r16),
                          border: Border.all(
                            color: AppColors.cyanAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.emeraldSuccess,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tuteur pq learn',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.cyanAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Multimodal',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.cyanAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Bouton Nouvelle discussion rapide
                  IconButton(
                    icon: const Icon(Icons.edit_square, size: 20),
                    tooltip: 'Nouvelle discussion',
                    onPressed: _handleNewSessionRequest,
                  ),
                ],
              ),
            ),

            // Bannière d'avertissement de quota si la limite de 10 est atteinte
            if (isAtMaxQuota)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(Icons.storage_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '10/10 conversations stockées sur le téléphone. Supprimez-en pour libérer l\'espace.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      child: const Text('Gérer', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Corps principal : Accueil ou Fil de discussion
            Expanded(
              child: _isLoadingSessions
                  ? const Center(child: CircularProgressIndicator())
                  : !hasUserMessages
                      ? _buildWelcomeState(context, profile?.className)
                      : _buildMessageFeed(context),
            ),

            // Indicateur de réflexion IA
            if (_isGenerating)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: AppRadius.radiusFull,
                        border: Border.all(
                          color: AppColors.cyanAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.cyanAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Le tuteur réfléchit…',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Dock de saisie multimodal ChatGPT/Gemini
            ChatMultimodalDock(
              isGenerating: _isGenerating,
              onSend: (text) => _sendMessage(text),
              onSendWithAttachments: (text, attachments) =>
                  _sendMessage(text, attachments),
              onStopGenerating: () => setState(() => _isGenerating = false),
            ),
          ],
        ),
      ),
    );
  }

  /// Écran d'accueil accueillant ChatGPT / Gemini quand aucune question n'a été posée
  Widget _buildWelcomeState(BuildContext context, String? className) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Orbe IA lumineux
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: AppColors.aiCompanionGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Comment puis-je t\'aider aujourd\'hui ?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            className != null
                ? 'Ton tuteur pour la $className : il t\'explique pas à pas.'
                : 'Ton tuteur t\'explique pas à pas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          // Suggestions tirées du parcours de l'élève : une liste sobre (plus de grille de cartes).
          if (!_personalLoaded)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
          if (_personal.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Pour toi, d\'après tes exercices et ton programme',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                for (final starter in _starters())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(AppRadius.r16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.r16),
                        onTap: () {
                          if (starter['action'] == 'photo') {
                            PhotoTranscriptionModal.show(
                              context,
                              onTranscription: (ocrResult) => _sendMessage(ocrResult),
                            );
                          } else {
                            _sendMessage(starter['prompt'] as String);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.r16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(starter['icon'] as IconData, size: 20, color: colors.accentPrimary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      // Titres d'exercices parfois écrits en LaTeX : lisibles, sans $.
                                      LatexToUnicodeConverter.convert(
                                          (starter['title'] as String).replaceAll(r'$', '')),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    if ((starter['subtitle'] as String?)?.isNotEmpty ?? false)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          starter['subtitle'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 12, color: colors.textMuted),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 20, color: colors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ],
        ],
      ),
    );
  }

  /// Flux de messages conversationnels style ChatGPT / Gemini
  Widget _buildMessageFeed(BuildContext context) {
    final colors = context.colors;
    final messages = _currentSession?.messages ?? [];

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isAi = msg.isAi;

        return Row(
          mainAxisAlignment:
              isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAi) ...[
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.aiCompanionGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyanAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isAi ? colors.card : null,
                  gradient: isAi ? null : AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.r16),
                    topRight: const Radius.circular(AppRadius.r16),
                    bottomLeft: Radius.circular(
                      isAi ? AppRadius.r4 : AppRadius.r16,
                    ),
                    bottomRight: Radius.circular(
                      isAi ? AppRadius.r16 : AppRadius.r4,
                    ),
                  ),
                  border: isAi ? Border.all(color: colors.border) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Affichage des pièces jointes associées au message
                    if (msg.hasAttachments) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: msg.attachments.map((att) {
                          return ChatAttachmentPill(
                            attachment: att,
                            isCompact: true,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Corps textuel avec moteur de formules mathématiques LaTeX & Détection de polynôme
                    AiMessageBubbleRenderer(
                      message: msg.text,
                      isAi: isAi,
                    ),

                    // Copier : discret, sous la réponse (plus d'en-tête « Tuteur » dans chaque bulle,
                    // l'avatar suffit à identifier l'auteur).
                    if (isAi && !msg.isError && msg.text.trim().isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Copier la réponse',
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          color: colors.textMuted,
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: msg.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Réponse copiée'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),

                    // Bouton de réessai immédiat si le message signale une erreur
                    if (isAi &&
                        (msg.isError ||
                            msg.text.contains('momentanément') ||
                            msg.text.contains('attente réseau') ||
                            msg.text.contains('Réessayer') ||
                            msg.text.contains('délai'))) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cyanAccent,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: _isGenerating ? null : _retryLastMessage,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          'Réessayer',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    // Affichage des citations RAG si présentes
                    if (isAi && msg.citations.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.menu_book_rounded,
                                    size: 13, color: AppColors.cyanAccent),
                                const SizedBox(width: 6),
                                Text(
                                  'Sources pédagogiques consultées :',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...msg.citations.map((c) {
                              final title = c['source_title'] as String? ?? 'Extrait de cours officiel';
                              return Text(
                                '• $title',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: colors.textPrimary,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!isAi) const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}
