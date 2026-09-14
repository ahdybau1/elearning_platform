import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system/tokens/app_radius.dart';

/// Atome dans l'espace 3D
class Atom3D {
  final String element;
  final double x;
  final double y;
  final double z;
  final Color color;
  final double radius;

  const Atom3D({
    required this.element,
    required this.x,
    required this.y,
    required this.z,
    required this.color,
    this.radius = 14.0,
  });
}

/// Liaison covalente entre deux atomes
class Bond3D {
  final int atom1Index;
  final int atom2Index;
  final int order; // 1 = simple, 2 = double

  const Bond3D(this.atom1Index, this.atom2Index, {this.order = 1});
}

/// Définition d'une molécule stéréochimique du programme
class MoleculeModel {
  final String name;
  final String formula;
  final String geometry;
  final String molarMass;
  final String bondAngle;
  final List<Atom3D> atoms;
  final List<Bond3D> bonds;

  const MoleculeModel({
    required this.name,
    required this.formula,
    required this.geometry,
    required this.molarMass,
    required this.bondAngle,
    required this.atoms,
    required this.bonds,
  });

  // Molécule : Méthane CH4 (Tétraédrique)
  static final methane = MoleculeModel(
    name: 'Méthane',
    formula: 'CH₄',
    geometry: 'Tétraédrique',
    molarMass: '16.04 g/mol',
    bondAngle: '109.5°',
    atoms: const [
      Atom3D(element: 'C', x: 0, y: 0, z: 0, color: Color(0xFF475569), radius: 18),
      Atom3D(element: 'H', x: 45, y: 45, z: 45, color: Color(0xFFE2E8F0), radius: 11),
      Atom3D(element: 'H', x: -45, y: -45, z: 45, color: Color(0xFFE2E8F0), radius: 11),
      Atom3D(element: 'H', x: -45, y: 45, z: -45, color: Color(0xFFE2E8F0), radius: 11),
      Atom3D(element: 'H', x: 45, y: -45, z: -45, color: Color(0xFFE2E8F0), radius: 11),
    ],
    bonds: const [
      Bond3D(0, 1),
      Bond3D(0, 2),
      Bond3D(0, 3),
      Bond3D(0, 4),
    ],
  );

  // Molécule : Eau H2O (Coudée)
  static final water = MoleculeModel(
    name: 'Eau',
    formula: 'H₂O',
    geometry: 'Coudée',
    molarMass: '18.02 g/mol',
    bondAngle: '104.5°',
    atoms: const [
      Atom3D(element: 'O', x: 0, y: 15, z: 0, color: Color(0xFFEF4444), radius: 19),
      Atom3D(element: 'H', x: -48, y: -30, z: 0, color: Color(0xFFE2E8F0), radius: 11),
      Atom3D(element: 'H', x: 48, y: -30, z: 0, color: Color(0xFFE2E8F0), radius: 11),
    ],
    bonds: const [
      Bond3D(0, 1),
      Bond3D(0, 2),
    ],
  );

  // Molécule : Éthanol C2H5OH (Alcool)
  static final ethanol = MoleculeModel(
    name: 'Éthanol',
    formula: 'C₂H₅OH',
    geometry: 'Alcool Primaire',
    molarMass: '46.07 g/mol',
    bondAngle: '109.5° & 104.5°',
    atoms: const [
      Atom3D(element: 'C', x: -45, y: 0, z: 0, color: Color(0xFF475569), radius: 17),
      Atom3D(element: 'C', x: 15, y: 0, z: 0, color: Color(0xFF475569), radius: 17),
      Atom3D(element: 'O', x: 60, y: 35, z: 0, color: Color(0xFFEF4444), radius: 18),
      Atom3D(element: 'H', x: 95, y: 25, z: 0, color: Color(0xFFE2E8F0), radius: 10),
      Atom3D(element: 'H', x: -45, y: 40, z: 25, color: Color(0xFFE2E8F0), radius: 10),
      Atom3D(element: 'H', x: -45, y: -40, z: 25, color: Color(0xFFE2E8F0), radius: 10),
      Atom3D(element: 'H', x: -85, y: 0, z: -25, color: Color(0xFFE2E8F0), radius: 10),
      Atom3D(element: 'H', x: 15, y: -40, z: -25, color: Color(0xFFE2E8F0), radius: 10),
      Atom3D(element: 'H', x: 15, y: 40, z: -25, color: Color(0xFFE2E8F0), radius: 10),
    ],
    bonds: const [
      Bond3D(0, 1),
      Bond3D(1, 2),
      Bond3D(2, 3),
      Bond3D(0, 4),
      Bond3D(0, 5),
      Bond3D(0, 6),
      Bond3D(1, 7),
      Bond3D(1, 8),
    ],
  );

  // Molécule : Dioxyde de Carbone CO2 (Linéaire)
  static final carbonDioxide = MoleculeModel(
    name: 'Dioxyde de Carbone',
    formula: 'CO₂',
    geometry: 'Linéaire',
    molarMass: '44.01 g/mol',
    bondAngle: '180.0°',
    atoms: const [
      Atom3D(element: 'C', x: 0, y: 0, z: 0, color: Color(0xFF475569), radius: 18),
      Atom3D(element: 'O', x: -65, y: 0, z: 0, color: Color(0xFFEF4444), radius: 17),
      Atom3D(element: 'O', x: 65, y: 0, z: 0, color: Color(0xFFEF4444), radius: 17),
    ],
    bonds: const [
      Bond3D(0, 1, order: 2),
      Bond3D(0, 2, order: 2),
    ],
  );
}

/// Visualiseur Moléculaire 3D Interactif
class MolecularViewer3DWidget extends StatefulWidget {
  const MolecularViewer3DWidget({super.key});

  @override
  State<MolecularViewer3DWidget> createState() => _MolecularViewer3DWidgetState();
}

class _MolecularViewer3DWidgetState extends State<MolecularViewer3DWidget> {
  int _selectedMolIndex = 0;
  final List<MoleculeModel> _molecules = [
    MoleculeModel.methane,
    MoleculeModel.ethanol,
    MoleculeModel.water,
    MoleculeModel.carbonDioxide,
  ];

  double _rotX = 0.4;
  double _rotY = 0.6;

  @override
  Widget build(BuildContext context) {
    final mol = _molecules[_selectedMolIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête avec sélecteur de molécule
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHIMIE & STÉRÉOCHIMIE 3D',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mol.name,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(30),
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(120)),
                ),
                child: Text(
                  mol.formula,
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Puces de sélection de molécules
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _molecules.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isSelected = i == _selectedMolIndex;
                return ChoiceChip(
                  label: Text('${_molecules[i].name} (${_molecules[i].formula})'),
                  selected: isSelected,
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: const Color(0xFF131B2E),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedMolIndex = i);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Zone de rendu 3D interactive tactile
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _rotY += details.delta.dx * 0.015;
                _rotX -= details.delta.dy * 0.015;
              });
            },
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF070D18),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size.infinite,
                      painter: _Molecule3DPainter(
                        molecule: mol,
                        rotX: _rotX,
                        rotY: _rotY,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: AppRadius.radiusSmall,
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.touch_app_rounded, color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Glisser pour faire pivoter à 360°',
                              style: TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Propriétés stéréochimiques certifiées
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoTile('Géométrie', mol.geometry),
                    _infoTile('Masse Molaire', mol.molarMass),
                    _infoTile('Angle de Liaison', mol.bondAngle),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),
                // Légende CPK
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _cpkLegend('C (Carbone)', const Color(0xFF475569)),
                    const SizedBox(width: 14),
                    _cpkLegend('H (Hydrogène)', const Color(0xFFE2E8F0)),
                    const SizedBox(width: 14),
                    _cpkLegend('O (Oxygène)', const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _cpkLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}

class _Molecule3DPainter extends CustomPainter {
  final MoleculeModel molecule;
  final double rotX;
  final double rotY;

  _Molecule3DPainter({
    required this.molecule,
    required this.rotX,
    required this.rotY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Projection 3D -> 2D
    final cosX = math.cos(rotX);
    final sinX = math.sin(rotX);
    final cosY = math.cos(rotY);
    final sinY = math.sin(rotY);

    final projectedAtoms = <({double x, double y, double z, Atom3D atom})>[];

    for (final a in molecule.atoms) {
      // Rotation Y
      final x1 = a.x * cosY + a.z * sinY;
      final z1 = -a.x * sinY + a.z * cosY;

      // Rotation X
      final y2 = a.y * cosX - z1 * sinX;
      final z2 = a.y * sinX + z1 * cosX;

      // Projection perspective
      const focal = 240.0;
      final scale = focal / (focal + z2);

      projectedAtoms.add((
        x: centerX + x1 * scale,
        y: centerY - y2 * scale,
        z: z2,
        atom: a,
      ));
    }

    // Dessiner les liaisons covalentes
    final bondPaint = Paint()
      ..color = Colors.white.withAlpha(120)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (final b in molecule.bonds) {
      if (b.atom1Index < projectedAtoms.length && b.atom2Index < projectedAtoms.length) {
        final p1 = projectedAtoms[b.atom1Index];
        final p2 = projectedAtoms[b.atom2Index];

        if (b.order == 2) {
          // Double liaison
          final dx = p2.x - p1.x;
          final dy = p2.y - p1.y;
          final len = math.sqrt(dx * dx + dy * dy);
          if (len > 0) {
            final nx = -dy / len * 3.0;
            final ny = dx / len * 3.0;
            canvas.drawLine(Offset(p1.x + nx, p1.y + ny), Offset(p2.x + nx, p2.y + ny), bondPaint);
            canvas.drawLine(Offset(p1.x - nx, p1.y - ny), Offset(p2.x - nx, p2.y - ny), bondPaint);
          }
        } else {
          canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), bondPaint);
        }
      }
    }

    // Trier les atomes selon z pour le rendu en profondeur (peintre d'arrière en avant)
    final sortedIndices = List.generate(projectedAtoms.length, (i) => i);
    sortedIndices.sort((a, b) => projectedAtoms[a].z.compareTo(projectedAtoms[b].z));

    for (final idx in sortedIndices) {
      final p = projectedAtoms[idx];
      const focal = 240.0;
      final scale = focal / (focal + p.z);
      final radius = p.atom.radius * scale;

      // Ombre portée
      final shadowPaint = Paint()..color = Colors.black.withAlpha(80);
      canvas.drawCircle(Offset(p.x + 2, p.y + 2), radius, shadowPaint);

      // Sphère d'atome
      final atomPaint = Paint()..color = p.atom.color;
      canvas.drawCircle(Offset(p.x, p.y), radius, atomPaint);

      // Reflet de brillance 3D
      final highlightPaint = Paint()..color = Colors.white.withAlpha(90);
      canvas.drawCircle(Offset(p.x - radius * 0.35, p.y - radius * 0.35), radius * 0.35, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Molecule3DPainter oldDelegate) =>
      oldDelegate.rotX != rotX ||
      oldDelegate.rotY != rotY ||
      oldDelegate.molecule != molecule;
}
