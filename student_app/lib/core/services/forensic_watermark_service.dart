import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student_models.dart';

class ForensicWatermarkService {
  /// Génère le texte de filigrane invisible/semi-transparent conforme au MVP Optimisé (Document 2)
  static String generateWatermarkText({
    required StudentProfile profile,
    required String phoneNumber,
  }) {
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    final profileShortId = profile.id.length >= 8 ? profile.id.substring(0, 8) : profile.id;
    return 'DOC PERSONNEL • ${profile.name.toUpperCase()} • TEL: $phoneNumber • ID: $profileShortId • $timestamp • DIFFUSION INTERDITE';
  }

  /// Widget d'overlay de filigrane pour sécuriser l'affichage des cours et documents PDF
  static Widget buildWatermarkedContainer({
    required Widget child,
    required StudentProfile profile,
    required String phoneNumber,
  }) {
    final watermarkText = generateWatermarkText(profile: profile, phoneNumber: phoneNumber);

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.04, // Discret et infalsifiable
              child: Transform.rotate(
                angle: -0.35,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    8,
                    (_) => Text(
                      watermarkText,
                      style: GoogleFonts.firaCode(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
