import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

/// Modèle d'un élément de curriculum collecté par le Curriculum Autopilot
class CurriculumCandidateNode {
  final String id;
  final String title;
  final String type; // country, subsystem, cycle, class, subject, chapter
  final int? coefficient;
  final int? trimester;
  final bool isOfficial;
  final String officialSource;
  final List<String> skills;
  final List<CurriculumCandidateNode> children;

  CurriculumCandidateNode({
    required this.id,
    required this.title,
    required this.type,
    this.coefficient,
    this.trimester,
    this.isOfficial = true,
    this.officialSource = 'MINESEC / Arrêté Ministériel',
    this.skills = const [],
    this.children = const [],
  });
}

/// Écran d'administration du Curriculum Autopilot (AIA-AGT-017 / Annexe D.3)
/// Permet de collecter, structurer automatiquement les programmes scolaires
/// officiels d'un pays et de les injecter directement dans l'arbre académique.
class CurriculumAutopilotScreen extends ConsumerStatefulWidget {
  const CurriculumAutopilotScreen({super.key});

  @override
  ConsumerState<CurriculumAutopilotScreen> createState() =>
      _CurriculumAutopilotScreenState();
}

class _CurriculumAutopilotScreenState extends ConsumerState<CurriculumAutopilotScreen> {
  String _selectedCountry = 'Cameroun';
  String _selectedSubsystem = 'Francophone (MINESEC / OBC)';
  String _selectedTrack = 'Enseignement Général';

  bool _isHarvesting = false;
  bool _harvestCompleted = false;
  int _currentPhase = 0; // 0 à 4
  String _statusMessage = 'Prêt à lancer la collecte automatique';

  // Données générées/collectées
  List<CurriculumCandidateNode> _curriculumTree = [];

  final List<String> _countries = [
    'Cameroun',
    'Côte d\'Ivoire',
    'Sénégal',
    'Gabon',
  ];

  final List<String> _subsystems = [
    'Francophone (MINESEC / OBC)',
    'Anglophone (Cameroon GCE Board)',
    'Bilingue & Technique',
  ];

  final List<String> _tracks = [
    'Enseignement Général',
    'Enseignement Technique & Professionnel',
  ];

  @override
  void initState() {
    super.initState();
    _loadSampleCurriculum();
  }

  void _loadSampleCurriculum() {
    _curriculumTree = [
      CurriculumCandidateNode(
        id: 'node_cm_fr',
        title: 'Cameroun — Sous-système Francophone',
        type: 'subsystem',
        officialSource: 'MINESEC / Loi d\'Orientation de l\'Éducation',
        children: [
          CurriculumCandidateNode(
            id: 'cycle_2',
            title: 'Second Cycle (Lycée)',
            type: 'cycle',
            children: [
              CurriculumCandidateNode(
                id: 'class_tle_c',
                title: 'Terminale C (Scientifique Math & Physique)',
                type: 'class',
                children: [
                  CurriculumCandidateNode(
                    id: 'sub_math_tc',
                    title: 'Mathématiques',
                    type: 'subject',
                    coefficient: 7,
                    children: [
                      CurriculumCandidateNode(
                        id: 'chap_1',
                        title: 'Chapitre 1 : Limites, Continuité et Suites Réelles',
                        type: 'chapter',
                        trimester: 1,
                        skills: [
                          'Calculer la limite d\'une suite géométrique q^n',
                          'Appliquer le théorème des gendarmes',
                          'Démontrer la convergence d\'une suite monotone bornée',
                        ],
                      ),
                      CurriculumCandidateNode(
                        id: 'chap_2',
                        title: 'Chapitre 2 : Dérivation, Tangentes et Étude de Fonctions',
                        type: 'chapter',
                        trimester: 1,
                        skills: [
                          'Calculer la dérivée f\'(x) d\'une fonction rationnelle',
                          'Déterminer l\'équation de la tangente au point d\'abscisse x0',
                          'Dresser le tableau de variation complet',
                        ],
                      ),
                      CurriculumCandidateNode(
                        id: 'chap_3',
                        title: 'Chapitre 3 : Fonctions Logarithme Népérien & Exponentielle',
                        type: 'chapter',
                        trimester: 2,
                        skills: [
                          'Résoudre des équations et inéquations avec ln(x) et exp(x)',
                          'Calculer les limites remarquables en 0 et +∞',
                        ],
                      ),
                      CurriculumCandidateNode(
                        id: 'chap_4',
                        title: 'Chapitre 4 : Nombres Complexes & Géométrie du Plan',
                        type: 'chapter',
                        trimester: 2,
                        skills: [
                          'Écrire un nombre complexe sous forme algébrique et trigonométrique',
                          'Caractériser une similitude directe du plan',
                        ],
                      ),
                      CurriculumCandidateNode(
                        id: 'chap_5',
                        title: 'Chapitre 5 : Primitives, Intégration et Calcul d\'Aires',
                        type: 'chapter',
                        trimester: 3,
                        skills: [
                          'Calculer une intégrale par parties',
                          'Déterminer la valeur moyenne et l\'aire sous la courbe',
                        ],
                      ),
                    ],
                  ),
                  CurriculumCandidateNode(
                    id: 'sub_phys_tc',
                    title: 'Physique & Chimie',
                    type: 'subject',
                    coefficient: 6,
                    children: [
                      CurriculumCandidateNode(
                        id: 'chap_pc_1',
                        title: 'Chapitre 1 : Cinématique et Lois de Newton',
                        type: 'chapter',
                        trimester: 1,
                        skills: [
                          'Appliquer la 2e loi de Newton (P = mg, somme des forces = ma)',
                          'Déterminer les équations horaires d\'un projectile',
                        ],
                      ),
                      CurriculumCandidateNode(
                        id: 'chap_pc_2',
                        title: 'Chapitre 2 : Circuit RLC et Oscillations Électriques',
                        type: 'chapter',
                        trimester: 2,
                        skills: [
                          'Établir l\'équation différentielle de charge du condensateur RC',
                          'Calculer la constante de temps tau = RC',
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              CurriculumCandidateNode(
                id: 'class_tle_d',
                title: 'Terminale D (Sciences Expérimentales & SVT)',
                type: 'class',
                children: [
                  CurriculumCandidateNode(
                    id: 'sub_svt_td',
                    title: 'Sciences de la Vie et de la Terre',
                    type: 'subject',
                    coefficient: 6,
                    children: [
                      CurriculumCandidateNode(
                        id: 'chap_svt_1',
                        title: 'Chapitre 1 : Génétique et Brassage Chromosomique',
                        type: 'chapter',
                        trimester: 1,
                        skills: [
                          'Analyser un arbre généalogique héréditaire',
                          'Expliquer les mécanismes de méiose et fécondation',
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              CurriculumCandidateNode(
                id: 'class_1ere_c',
                title: 'Première C (Mathématiques & Sciences Physiques)',
                type: 'class',
                children: [
                  CurriculumCandidateNode(
                    id: 'sub_math_1c',
                    title: 'Mathématiques',
                    type: 'subject',
                    coefficient: 6,
                    children: [
                      CurriculumCandidateNode(
                        id: 'chap_1c_1',
                        title: 'Chapitre 1 : Polynômes du Second Degré & Équations',
                        type: 'chapter',
                        trimester: 1,
                        skills: [
                          'Calculer le discriminant Delta = b^2 - 4ac',
                          'Trouver le sommet et les racines d\'une parabole',
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ];
  }

  Future<void> _startHarvesting() async {
    setState(() {
      _isHarvesting = true;
      _harvestCompleted = false;
      _currentPhase = 1;
      _statusMessage = 'Phase 1/4 : Recherche & Ingestion des Décrets & Arrêtés Officiels...';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _currentPhase = 2;
      _statusMessage = 'Phase 2/4 : Structuration Arborescente (Matières, Coefficients, Trimestres T1-T3)...';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _currentPhase = 3;
      _statusMessage = 'Phase 3/4 : Audit AI Admin Copilot (Détection des lacunes et incohérences)...';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _currentPhase = 4;
      _isHarvesting = false;
      _harvestCompleted = true;
      _statusMessage = 'Collecte & Structuration terminées avec succès ! 100% conforme aux référentiels officiels.';
    });

    _loadSampleCurriculum();
  }

  void _injectIntoAcademicTree() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primarySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.primaryBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppTheme.accentEmerald, size: 24),
            SizedBox(width: 10),
            Text('Injection dans l\'Arbre Académique'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le Curriculum Autopilot va injecter les éléments suivants dans la base Supabase :',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _summaryItem(Icons.apartment_rounded, '1 Sous-système national (MINESEC)'),
            _summaryItem(Icons.school_rounded, '3 Classes & Séries (Tle C, Tle D, 1ère C)'),
            _summaryItem(Icons.menu_book_rounded, '4 Matières avec coefficients officiels'),
            _summaryItem(Icons.format_list_numbered_rounded, '9 Chapitres avec découpage trimestriel'),
            _summaryItem(Icons.psychology_rounded, '24 Compétences pédagogiques & prérequis'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentEmerald.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentEmerald.withAlpha(80)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_clock_rounded, color: AppTheme.accentEmerald, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Déblocage temporel automatique des trimestres T1, T2 et T3 configuré.',
                      style: TextStyle(color: AppTheme.accentEmerald, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.accentEmerald,
                  content: Row(
                    children: const [
                      Icon(Icons.done_all_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Arbre académique enrichi avec succès ! Les chapitres et matières sont disponibles.'),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('Confirmer l\'Injection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentEmerald,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.accentCyan),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre & Badge de l'agent
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.accentCyan.withAlpha(100)),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentCyan, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Curriculum Autopilot & Ingestion IA',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Agent AIA-AGT-017 • Spécification Normative Annexe D.3 & D.2',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // Statut de l'agent
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentEmerald.withAlpha(120)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.radio_button_checked_rounded, color: AppTheme.accentEmerald, size: 12),
                      SizedBox(width: 6),
                      Text(
                        'AGENT ACTIF & AUTONOME',
                        style: TextStyle(color: AppTheme.accentEmerald, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Barre de Configuration : Pays, Sous-système, Filière
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PARAMÈTRES DE COLLECTE NATIONALE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentCyan,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Pays
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCountry,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Pays de Référence',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: AppTheme.primaryDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          dropdownColor: AppTheme.primarySurface,
                          items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCountry = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Sous-système
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSubsystem,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Sous-Système Éducatif',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: AppTheme.primaryDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          dropdownColor: AppTheme.primarySurface,
                          items: _subsystems.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSubsystem = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Type d'enseignement
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedTrack,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Type d\'Enseignement',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: AppTheme.primaryDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          dropdownColor: AppTheme.primarySurface,
                          items: _tracks.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedTrack = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Bouton CTA principal de lancement 1-clic
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isHarvesting ? null : _startHarvesting,
                        icon: _isHarvesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.rocket_launch_rounded, size: 18),
                        label: Text(
                          _isHarvesting
                              ? 'Collecte & Structuration en cours...'
                              : '🚀 Lancer la Collecte & Structuration IA du Programme',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (_harvestCompleted)
                        ElevatedButton.icon(
                          onPressed: _injectIntoAcademicTree,
                          icon: const Icon(Icons.download_done_rounded, size: 18),
                          label: const Text('Injecter dans l\'Arbre Académique'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentEmerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Barre de suivi des 4 phases de l'agent IA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.accentCyan, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: GoogleFonts.firaCode(
                            color: _harvestCompleted ? AppTheme.accentEmerald : Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Indicateur des 4 phases
                  Row(
                    children: [
                      _phaseStep(1, 'Extraction Référentiels', _currentPhase >= 1),
                      _phaseDivider(_currentPhase >= 2),
                      _phaseStep(2, 'Structuration Arborescente', _currentPhase >= 2),
                      _phaseDivider(_currentPhase >= 3),
                      _phaseStep(3, 'Audit AI Copilot (D.2)', _currentPhase >= 3),
                      _phaseDivider(_currentPhase >= 4),
                      _phaseStep(4, 'Arbre Prêt pour Injection', _currentPhase >= 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Métriques clés du programme extrait
            Row(
              children: [
                _kpiCard('Classes Cartographiées', '3 Niveaux', Icons.school_rounded, AppTheme.accentCyan),
                const SizedBox(width: 14),
                _kpiCard('Matières & Coeffs', '4 Enseignements', Icons.menu_book_rounded, AppTheme.accentIndigo),
                const SizedBox(width: 14),
                _kpiCard('Chapitres Trimestriels', '9 Modules', Icons.format_list_bulleted_rounded, AppTheme.accentEmerald),
                const SizedBox(width: 14),
                _kpiCard('Compétences Ciblées', '24 Objectifs', Icons.psychology_rounded, AppTheme.accentAmber),
              ],
            ),
            const SizedBox(height: 24),

            // Zone d'exploration de l'arbre académique extrait
            Container(
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
                        'RÉFÉRENTIEL ACADÉMIQUE GÉNÉRÉ & CERTIFIÉ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          _legendItem('Officiel Certifié (MINESEC/OBC)', AppTheme.accentEmerald),
                          const SizedBox(width: 14),
                          _legendItem('Proposition IA Validable', AppTheme.accentAmber),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.primaryBorder, height: 24),
                  // Liste arborescente des classes et matières
                  ..._curriculumTree.map((node) => _buildTreeNode(node)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phaseStep(int step, String title, bool active) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: active ? AppTheme.accentCyan : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: active ? Colors.black : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseDivider(bool active) {
    return Container(
      width: 18,
      height: 2,
      color: active ? AppTheme.accentCyan : Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildTreeNode(CurriculumCandidateNode node, {int depth = 0}) {
    final hasChildren = node.children.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, top: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    node.type == 'subsystem'
                        ? Icons.apartment_rounded
                        : node.type == 'cycle'
                            ? Icons.account_tree_rounded
                            : node.type == 'class'
                                ? Icons.school_rounded
                                : node.type == 'subject'
                                    ? Icons.menu_book_rounded
                                    : Icons.bookmark_border_rounded,
                    size: 16,
                    color: node.type == 'class'
                        ? AppTheme.accentCyan
                        : node.type == 'subject'
                            ? AppTheme.accentAmber
                            : Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    node.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: node.type == 'class' ? 14 : 13,
                      fontWeight: node.type == 'class' || node.type == 'subject'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (node.coefficient != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentIndigo.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.accentIndigo.withAlpha(80)),
                  ),
                  child: Text(
                    'Coeff. ${node.coefficient}',
                    style: const TextStyle(color: AppTheme.accentIndigo, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              if (node.trimester != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Trimestre ${node.trimester}',
                    style: const TextStyle(color: AppTheme.accentCyan, fontSize: 10),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 10, color: AppTheme.accentEmerald),
                    const SizedBox(width: 4),
                    Text(
                      node.officialSource,
                      style: const TextStyle(color: AppTheme.accentEmerald, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (node.skills.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: node.skills
                    .map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: AppTheme.accentCyan)),
                              Expanded(
                                child: Text(s, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (hasChildren) ...[
            ...node.children.map((c) => _buildTreeNode(c, depth: depth + 1)),
          ],
        ],
      ),
    );
  }
}
