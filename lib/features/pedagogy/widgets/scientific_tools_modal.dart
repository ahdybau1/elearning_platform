import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/rendering/math_formula_view.dart';
import '../../../core/services/scientific_tools_service.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import 'interactive_function_graph.dart';
import 'virtual_labs/circuit_simulator_widget.dart';
import 'virtual_labs/molecular_viewer_3d_widget.dart';
import 'virtual_labs/python_sandbox_widget.dart';
import 'virtual_labs/ballistics_simulator_widget.dart';

/// Modal complet des Outils Scientifiques et Laboratoires Virtuels EDLEARN
///
/// Conforme au Cahier Technique Frameworks & Outils IA (docs/CAHIER_TECHNIQUE_FRAMEWORKS_OUTILS_IA.md) :
/// - SymPy : calcul exact formel déterministe
/// - Grapheur : repère dynamique et dérivation
/// - Simulateurs LabAssistant : Circuits (ngspice), Molécules 3D (3Dmol.js), Python (Pyodide)
class ScientificToolsModal extends StatefulWidget {
  final String? initialQuery;
  final int initialTabIndex; // 0 = SymPy, 1 = Grapheur, 2 = Labos

  const ScientificToolsModal({
    super.key,
    this.initialQuery,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialQuery,
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScientificToolsModal(
        initialQuery: initialQuery,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<ScientificToolsModal> createState() => _ScientificToolsModalState();
}

class _ScientificToolsModalState extends State<ScientificToolsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TextEditingController _exprCtrl;

  MathComputationResult? _lastResult;
  bool _isComputing = false;
  int? _activeLabIndex;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _exprCtrl = TextEditingController(text: widget.initialQuery ?? '3x(x - 2)');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _runSympySolve('solve');
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _exprCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSympySolve(String mode) async {
    final query = _exprCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isComputing = true);

    try {
      final res = await ScientificToolsService.instance.solveEquation(query, mode: mode);
      setState(() {
        _lastResult = res;
        _isComputing = false;
      });
    } catch (_) {
      setState(() => _isComputing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barre supérieure de drag
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // En-tête avec titre et sélecteur de moteur KaTeX / MathJax
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withAlpha(30),
                    borderRadius: AppRadius.radiusSmall,
                    border: Border.all(color: AppColors.primaryCyan.withAlpha(100)),
                  ),
                  child: const Icon(Icons.calculate_rounded, color: AppColors.primaryCyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OUTILS SCIENTIFIQUES DÉTERMINISTES',
                        style: GoogleFonts.inter(
                          color: AppColors.primaryCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'SymPy • Grapheur • Simulateurs',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Barre d'onglets
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: AppColors.primaryCyan.withAlpha(40),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.primaryCyan.withAlpha(140)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(
                  icon: Icon(Icons.functions_rounded, size: 16),
                  text: 'Calcul SymPy',
                ),
                Tab(
                  icon: Icon(Icons.show_chart_rounded, size: 16),
                  text: 'Grapheur & Dérivée',
                ),
                Tab(
                  icon: Icon(Icons.science_rounded, size: 16),
                  text: 'Labos Virtuels',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Corps des onglets
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildSympyCalculatorTab(),
                _buildGrapherTab(),
                _buildVirtualLabsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Onglet 1 : Calculateur Formel SymPy Déterministe
  Widget _buildSympyCalculatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de saisie d'expression
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white.withAlpha(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXPRESSION MATHÉMATIQUE',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _exprCtrl,
                  style: GoogleFonts.firaCode(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'ex: 3x(x - 2) ou x^2 - 5x + 6',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Boutons d'actions SymPy
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                label: 'Résoudre = 0',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.primaryCyan,
                onTap: () => _runSympySolve('solve'),
              ),
              _buildActionButton(
                label: 'Calculer Dérivée',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF10B981),
                onTap: () => _runSympySolve('derivative'),
              ),
              _buildActionButton(
                label: 'Simplifier',
                icon: Icons.auto_fix_high_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () => _runSympySolve('simplify'),
              ),
              _buildActionButton(
                label: 'Évaluer (Float)',
                icon: Icons.exposure_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => _runSympySolve('evaluate'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Raccourcis d'exemples classiques du programme Bac
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildExampleChip('3x(x - 2)'),
              _buildExampleChip('x^2 - 5x + 6'),
              _buildExampleChip('x^3 - 3x^2 + 1'),
              _buildExampleChip('2x - 4 = 0'),
            ],
          ),
          const SizedBox(height: 20),

          // Zone de résultat certifié
          if (_isComputing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primaryCyan),
              ),
            )
          else if (_lastResult != null)
            _buildResultCard(_lastResult!),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(25),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(90)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildExampleChip(String expr) {
    return ActionChip(
      backgroundColor: Colors.white.withAlpha(12),
      side: BorderSide(color: Colors.white.withAlpha(30)),
      label: Text(expr, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      onPressed: () {
        _exprCtrl.text = expr;
        _runSympySolve('solve');
      },
    );
  }

  Widget _buildResultCard(MathComputationResult res) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'RÉSULTAT EXACT CERTIFIÉ',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: AppRadius.radiusSmall,
                ),
                child: Text(
                  res.engineUsed,
                  style: const TextStyle(color: Colors.white60, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MathFormulaView(
            formulaLatex: res.latexResult,
            fontSize: 17,
            label: 'SOLUTIONS FORMELLES',
          ),
          const SizedBox(height: 12),
          Text(
            res.explanation,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }

  /// Onglet 2 : Grapheur de Fonction & Tangente Réactive
  Widget _buildGrapherTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: InteractiveFunctionGraph(
              functionSpec: MathFunctionSpec.defaultCubic,
              initialX: 2.0,
              showObservationCard: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Onglet 3 : Laboratoires Virtuels Déterministes (LabAssistant)
  Widget _buildVirtualLabsTab() {
    if (_activeLabIndex != null) {
      return Column(
        children: [
          // Barre de navigation du simulateur actif
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              border: Border(bottom: BorderSide(color: Colors.white.withAlpha(20))),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _activeLabIndex = null),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white70),
                  label: Text(
                    'Tous les Laboratoires',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const Spacer(),
                // Puces de bascule rapide entre les 4 labos
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, icon: Icon(Icons.bolt_rounded, size: 14), tooltip: 'Circuit RC'),
                    ButtonSegment(value: 1, icon: Icon(Icons.blur_on_rounded, size: 14), tooltip: 'Molécules 3D'),
                    ButtonSegment(value: 2, icon: Icon(Icons.terminal_rounded, size: 14), tooltip: 'Python WASM'),
                    ButtonSegment(value: 3, icon: Icon(Icons.rocket_launch_rounded, size: 14), tooltip: 'Balistique'),
                  ],
                  selected: {_activeLabIndex!},
                  onSelectionChanged: (set) => setState(() => _activeLabIndex = set.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primaryCyan.withAlpha(50);
                      }
                      return Colors.transparent;
                    }),
                  ),
                ),
              ],
            ),
          ),
          // Corps du laboratoire interactif
          Expanded(
            child: IndexedStack(
              index: _activeLabIndex,
              children: const [
                CircuitSimulatorWidget(),
                MolecularViewer3DWidget(),
                PythonSandboxWidget(),
                BallisticsSimulatorWidget(),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _buildLabCard(
          index: 0,
          title: '⚡ Simulateur de Circuits Électriques (ngspice / CircuitJS)',
          discipline: 'PHYSIQUE & ÉLECTRONIQUE',
          description: "Simulation déterministe réelle SPICE : Loi d'Ohm, régime transitoire RC, oscillateur RLC et analyse fréquentielle.",
          statusText: 'Moteur Actif (SPICE 3F5)',
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 12),
        _buildLabCard(
          index: 1,
          title: '🧪 Visualiseur Moléculaire 3D (3Dmol.js / RDKit)',
          discipline: 'CHIMIE & STÉRÉOCHIMIE',
          description: "Visualisation 3D interactive des liaisons covalentes, molécules organiques, alcanes, alcools et isomères du programme.",
          statusText: 'WebGL / PDB Ready',
          color: const Color(0xFF10B981),
        ),
        const SizedBox(height: 12),
        _buildLabCard(
          index: 2,
          title: '💻 Bac à Sable Python (Pyodide / WebAssembly)',
          discipline: 'INFORMATIQUE & ALGORITHMIQUE',
          description: "Exécution de scripts Python réels dans le navigateur sans serveur : calcul de suites, boucles et algorithmes du Bac.",
          statusText: 'Python 3.12 WASM',
          color: const Color(0xFF38BDF8),
        ),
        const SizedBox(height: 12),
        _buildLabCard(
          index: 3,
          title: '⚙️ Modélisation Physique & Mécanique (Matter.js / Box2D)',
          discipline: 'MÉCANIQUE NEWTONIENNE',
          description: "Trajectoires de projectiles, pendules oscillants et plans inclinés avec calcul exact des vecteurs accélération et vitesse.",
          statusText: 'Moteur Déterministe',
          color: const Color(0xFFA855F7),
        ),
      ],
    );
  }

  Widget _buildLabCard({
    required int index,
    required String title,
    required String discipline,
    required String description,
    required String statusText,
    required Color color,
  }) {
    return InkWell(
      onTap: () => setState(() => _activeLabIndex = index),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: AppRadius.radiusSmall,
                    border: Border.all(color: color.withAlpha(100)),
                  ),
                  child: Text(
                    discipline,
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                Text(
                  statusText,
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _activeLabIndex = index),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Ouvrir le Simulateur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withAlpha(40),
                    foregroundColor: color,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      side: BorderSide(color: color.withAlpha(120)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
