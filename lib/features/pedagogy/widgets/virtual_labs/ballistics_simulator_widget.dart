import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../design_system/tokens/app_radius.dart';

/// Simulateur de Mécanique Newtonienne & Tir Balistique
class BallisticsSimulatorWidget extends StatefulWidget {
  const BallisticsSimulatorWidget({super.key});

  @override
  State<BallisticsSimulatorWidget> createState() => _BallisticsSimulatorWidgetState();
}

class _BallisticsSimulatorWidgetState extends State<BallisticsSimulatorWidget>
    with SingleTickerProviderStateMixin {
  double _angleDeg = 45.0; // Angle alpha en degrés
  double _initialVelocity = 25.0; // v0 en m/s
  final double _gravity = 9.81; // g en m/s^2 (Terre)

  late AnimationController _animCtrl;
  double _animProgress = 1.0;

  double get _angleRad => _angleDeg * math.pi / 180.0;

  // Hauteur maximale (Flèche H) = (v0 * sin(alpha))^2 / (2 * g)
  double get _maxHeight {
    final vy0 = _initialVelocity * math.sin(_angleRad);
    return (vy0 * vy0) / (2 * _gravity);
  }

  // Portée X = (v0^2 * sin(2*alpha)) / g
  double get _range {
    return (_initialVelocity * _initialVelocity * math.sin(2 * _angleRad)) / _gravity;
  }

  // Durée de vol = (2 * v0 * sin(alpha)) / g
  double get _flightTime {
    return (2 * _initialVelocity * math.sin(_angleRad)) / _gravity;
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addListener(() {
        setState(() => _animProgress = _animCtrl.value);
      });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _launchProjectile() {
    _animCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MÉCANIQUE NEWTONIENNE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFA855F7),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tir Balistique Parabolique',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _launchProjectile,
                icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                label: const Text('Tirer !'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Écran de simulation vectorielle
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: const Color(0xFF070D18),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: const Color(0xFFA855F7).withAlpha(80)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _TrajectoryPainter(
                      angleRad: _angleRad,
                      v0: _initialVelocity,
                      g: _gravity,
                      range: _range,
                      maxHeight: _maxHeight,
                      animProgress: _animProgress,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: AppRadius.radiusSmall,
                      ),
                      child: Text(
                        'v₀ = ${_initialVelocity.toStringAsFixed(0)} m/s | α = ${_angleDeg.toStringAsFixed(0)}°',
                        style: GoogleFonts.firaCode(
                          color: const Color(0xFFA855F7),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

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
                // Angle alpha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Angle de tir (α)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    Text('${_angleDeg.toStringAsFixed(0)}°', style: GoogleFonts.firaCode(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _angleDeg,
                  min: 5.0,
                  max: 85.0,
                  divisions: 80,
                  activeColor: const Color(0xFFA855F7),
                  onChanged: (val) {
                    setState(() => _angleDeg = val);
                  },
                ),

                // Vitesse initiale v0
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Vitesse initiale (v₀)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    Text('${_initialVelocity.toStringAsFixed(0)} m/s', style: GoogleFonts.firaCode(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _initialVelocity,
                  min: 5.0,
                  max: 50.0,
                  divisions: 45,
                  activeColor: const Color(0xFFA855F7),
                  onChanged: (val) {
                    setState(() => _initialVelocity = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Métriques calculées exactement
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
                _metricCol('Portée Maximale (X)', '${_range.toStringAsFixed(1)} m'),
                _metricCol('Flèche (H_max)', '${_maxHeight.toStringAsFixed(1)} m'),
                _metricCol('Durée de Vol', '${_flightTime.toStringAsFixed(2)} s'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.firaCode(
            color: const Color(0xFFA855F7),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  final double angleRad;
  final double v0;
  final double g;
  final double range;
  final double maxHeight;
  final double animProgress;

  _TrajectoryPainter({
    required this.angleRad,
    required this.v0,
    required this.g,
    required this.range,
    required this.maxHeight,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final originX = 24.0;
    final originY = size.height - 24.0;
    final drawW = size.width - 48.0;
    final drawH = size.height - 48.0;

    // Axe du sol et échelle
    final groundPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(originX, originY), Offset(size.width - 10, originY), groundPaint);

    if (range <= 0) return;

    final scaleX = drawW / (range * 1.15);
    final scaleY = drawH / (maxHeight > 0 ? maxHeight * 1.3 : 1.0);

    // Parabole théorique en pointillés ou ligne fine
    final trajectoryPaint = Paint()
      ..color = const Color(0xFFA855F7).withAlpha(140)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    const steps = 60;
    for (int i = 0; i <= steps; i++) {
      final x = (range * i) / steps;
      // y(x) = -g / (2 * v0^2 * cos^2(alpha)) * x^2 + tan(alpha) * x
      final y = -(g / (2 * v0 * v0 * math.cos(angleRad) * math.cos(angleRad))) * x * x +
          math.tan(angleRad) * x;

      final px = originX + x * scaleX;
      final py = originY - y * scaleY;

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, trajectoryPaint);

    // Projectile animé le long de la parabole
    final currentX = range * animProgress;
    final currentY = -(g / (2 * v0 * v0 * math.cos(angleRad) * math.cos(angleRad))) * currentX * currentX +
        math.tan(angleRad) * currentX;

    final ballX = originX + currentX * scaleX;
    final ballY = originY - (currentY > 0 ? currentY : 0.0) * scaleY;

    // Balle projectile
    final ballPaint = Paint()..color = const Color(0xFFA855F7);
    canvas.drawCircle(Offset(ballX, ballY), 6.5, ballPaint);
    final glowPaint = Paint()..color = Colors.white.withAlpha(160);
    canvas.drawCircle(Offset(ballX, ballY), 3.0, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) => true;
}
