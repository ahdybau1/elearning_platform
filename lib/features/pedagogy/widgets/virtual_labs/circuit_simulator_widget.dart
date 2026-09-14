import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system/tokens/app_radius.dart';

/// Simulateur de Circuits Électriques Déterministe (CircuitJS / ngspice)
/// Permet à l'élève d'expérimenter la charge et décharge d'un condensateur RC,
/// d'observer l'oscilloscope vectoriel en temps réel et de vérifier tau = RC.
class CircuitSimulatorWidget extends StatefulWidget {
  const CircuitSimulatorWidget({super.key});

  @override
  State<CircuitSimulatorWidget> createState() => _CircuitSimulatorWidgetState();
}

class _CircuitSimulatorWidgetState extends State<CircuitSimulatorWidget>
    with SingleTickerProviderStateMixin {
  double _resistance = 100.0; // Ohms
  double _capacitance = 47.0; // microFarads
  double _voltage = 12.0; // Volts
  bool _isCharging = true;

  late AnimationController _animCtrl;
  double _simTime = 0.0; // Temps de simulation en secondes
  final List<double> _timeHistory = [];
  final List<double> _voltageHistory = [];

  // Constante de temps tau = R * C (en secondes)
  double get _tau => (_resistance * (_capacitance * 1e-6));

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_onTick);
    _animCtrl.repeat();
  }

  void _onTick() {
    setState(() {
      _simTime += 0.002;
      double currentV;
      final tau = _tau;
      if (_isCharging) {
        // u_C(t) = E * (1 - e^(-t / tau))
        currentV = _voltage * (1.0 - math.exp(-_simTime / (tau > 0 ? tau : 0.001)));
      } else {
        // u_C(t) = E * e^(-t / tau)
        currentV = _voltage * math.exp(-_simTime / (tau > 0 ? tau : 0.001));
      }
      _timeHistory.add(_simTime);
      _voltageHistory.add(currentV);
      if (_voltageHistory.length > 120) {
        _voltageHistory.removeAt(0);
        _timeHistory.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _resetSimulation(bool charging) {
    setState(() {
      _isCharging = charging;
      _simTime = 0.0;
      _timeHistory.clear();
      _voltageHistory.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tau = _tau;
    final tauMs = (tau * 1000).toStringAsFixed(1);
    final energy = (0.5 * (_capacitance * 1e-6) * _voltage * _voltage * 1000).toStringAsFixed(2);
    final currentV = _voltageHistory.isNotEmpty ? _voltageHistory.last : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête avec mode actif
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CIRCUIT RC EN TEMPS RÉEL',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF59E0B),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Oscilloscope Numérique Vectoriel',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withAlpha(30),
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(color: const Color(0xFFF59E0B).withAlpha(120)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isCharging ? 'CHARGE (E → C)' : 'DÉCHARGE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Écran Oscilloscope
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF070D18),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _OscilloscopePainter(
                      voltageHistory: _voltageHistory,
                      maxVoltage: _voltage > 0 ? _voltage : 1.0,
                    ),
                  ),
                  // HUD Affichage instantané
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: AppRadius.radiusSmall,
                      ),
                      child: Text(
                        'u_C = ${currentV.toStringAsFixed(2)} V',
                        style: GoogleFonts.firaCode(
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Text(
                      'Échelle : ${_voltage.toStringAsFixed(0)} V / Div | Base de temps auto',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Boutons d'interrupteur Charge / Décharge
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resetSimulation(true),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Lancer Charge (E)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCharging ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
                    foregroundColor: _isCharging ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resetSimulation(false),
                  icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                  label: const Text('Lancer Décharge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isCharging ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
                    foregroundColor: !_isCharging ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Curseurs interactifs
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Column(
              children: [
                // Résistance R
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Résistance (R)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    Text('${_resistance.toStringAsFixed(0)} Ω', style: GoogleFonts.firaCode(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _resistance,
                  min: 10.0,
                  max: 1000.0,
                  divisions: 99,
                  activeColor: const Color(0xFFF59E0B),
                  onChanged: (val) {
                    setState(() => _resistance = val);
                  },
                ),

                // Capacité C
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Capacité (C)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    Text('${_capacitance.toStringAsFixed(0)} µF', style: GoogleFonts.firaCode(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _capacitance,
                  min: 1.0,
                  max: 200.0,
                  divisions: 199,
                  activeColor: const Color(0xFFF59E0B),
                  onChanged: (val) {
                    setState(() => _capacitance = val);
                  },
                ),

                // Tension du générateur E
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tension Générateur (E)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    Text('${_voltage.toStringAsFixed(0)} V', style: GoogleFonts.firaCode(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _voltage,
                  min: 1.0,
                  max: 24.0,
                  divisions: 23,
                  activeColor: const Color(0xFFF59E0B),
                  onChanged: (val) {
                    setState(() => _voltage = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Carte de métriques physiques exactes
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricTile('Constante τ = RC', '$tauMs ms'),
                _metricTile('Temps à 95% (3τ)', '${(tau * 3000).toStringAsFixed(1)} ms'),
                _metricTile('Énergie Max', '$energy mJ'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.firaCode(color: const Color(0xFFF59E0B), fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _OscilloscopePainter extends CustomPainter {
  final List<double> voltageHistory;
  final double maxVoltage;

  _OscilloscopePainter({required this.voltageHistory, required this.maxVoltage});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(25)
      ..strokeWidth = 1.0;

    // Grille de l'oscilloscope
    const gridDivs = 6;
    for (int i = 0; i <= gridDivs; i++) {
      final y = size.height * (i / gridDivs);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 0; i <= 8; i++) {
      final x = size.width * (i / 8);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    if (voltageHistory.length < 2) return;

    // Tracé de la courbe
    final curvePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < voltageHistory.length; i++) {
      final x = size.width * (i / (voltageHistory.length - 1));
      final normV = (voltageHistory[i] / (maxVoltage > 0 ? maxVoltage : 1.0)).clamp(0.0, 1.0);
      final y = size.height - (normV * (size.height - 20) + 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _OscilloscopePainter oldDelegate) => true;
}
