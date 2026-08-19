import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/student_theme.dart';
import '../../../core/auth/student_auth_provider.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentStep = 0;
  String _selectedCountry = 'Cameroun';
  String _selectedCycle = 'Secondaire Général (Lycée)';
  String _selectedSerie = 'Série Scientifique (C / D / TI)';
  String _selectedClass = 'Terminale C';
  final TextEditingController _studentNameCtrl = TextEditingController(text: 'Junior');
  final TextEditingController _phoneCtrl = TextEditingController(text: '+237 699 00 11 22');
  final TextEditingController _schoolCtrl = TextEditingController(text: 'Lycée Général Leclerc');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentTheme.backgroundDark,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress indicator
                Row(
                  children: List.generate(4, (index) {
                    final isDone = index <= _currentStep;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isDone ? StudentTheme.accentPrimary : StudentTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Wizard Steps
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildCurrentStep(),
                  ),
                ),

                // Bottom Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      TextButton.icon(
                        onPressed: () => setState(() => _currentStep--),
                        icon: const Icon(Icons.arrow_back_rounded, color: StudentTheme.textSecondary),
                        label: Text(
                          'Précédent',
                          style: GoogleFonts.inter(color: StudentTheme.textSecondary),
                        ),
                      )
                    else
                      const SizedBox(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StudentTheme.accentPrimary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_currentStep < 3) {
                          setState(() => _currentStep++);
                        } else {
                          // Complete Onboarding
                          ref.read(studentAuthProvider.notifier).addProfile(
                            name: _studentNameCtrl.text.trim(),
                            classNodeId: '00000000-0000-0000-0000-000000000004',
                            className: _selectedClass,
                            schoolName: _schoolCtrl.text.trim(),
                          );
                          Navigator.pushReplacementNamed(context, '/home');
                        }
                      },
                      child: Text(
                        _currentStep == 3 ? 'Commencer l\'Aventure' : 'Continuer',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildCountryAndCycleStep();
      case 1:
        return _buildClassSelectionStep();
      case 2:
        return _buildProfileInfoStep();
      case 3:
        return _buildSummaryStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildCountryAndCycleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue sur votre Plateforme d\'Excellence',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sélectionnez votre pays et votre niveau d\'études pour charger le programme officiel conforme.',
          style: GoogleFonts.inter(fontSize: 14, color: StudentTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Pays :'),
        Wrap(
          spacing: 10,
          children: ['Cameroun', 'Côte d\'Ivoire', 'Sénégal', 'Gabon'].map((country) {
            final isSel = _selectedCountry == country;
            return ChoiceChip(
              label: Text(country),
              selected: isSel,
              onSelected: (_) => setState(() => _selectedCountry = country),
              selectedColor: StudentTheme.accentPrimary.withOpacity(0.2),
              backgroundColor: StudentTheme.cardDark,
              labelStyle: GoogleFonts.inter(
                color: isSel ? StudentTheme.accentPrimary : Colors.white,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Cycle d\'études :'),
        ...['Primaire', 'Collège (1er Cycle)', 'Secondaire Général (Lycée)', 'Enseignement Technique'].map((cycle) {
          final isSel = _selectedCycle == cycle;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSel ? StudentTheme.accentPrimary : StudentTheme.borderDark,
                ),
              ),
              tileColor: StudentTheme.cardDark,
              leading: Icon(
                isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSel ? StudentTheme.accentPrimary : StudentTheme.textSecondary,
              ),
              title: Text(cycle, style: GoogleFonts.inter(color: Colors.white)),
              onTap: () => setState(() => _selectedCycle = cycle),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildClassSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votre Classe & Série',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'L\'ensemble des cours, exercices et annales sera calibré sur cette classe.',
          style: GoogleFonts.inter(fontSize: 14, color: StudentTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Filière / Série :'),
        Wrap(
          spacing: 10,
          children: ['Série Scientifique (C / D / TI)', 'Série Littéraire (A / ABI)'].map((s) {
            final isSel = _selectedSerie == s;
            return ChoiceChip(
              label: Text(s),
              selected: isSel,
              onSelected: (_) => setState(() => _selectedSerie = s),
              selectedColor: StudentTheme.accentPrimary.withOpacity(0.2),
              backgroundColor: StudentTheme.cardDark,
              labelStyle: GoogleFonts.inter(
                color: isSel ? StudentTheme.accentPrimary : Colors.white,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Classe exacte :'),
        ...['2nde C', '1ère C', '1ère D', 'Terminale C', 'Terminale D'].map((cl) {
          final isSel = _selectedClass == cl;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSel ? StudentTheme.accentPrimary : StudentTheme.borderDark,
                ),
              ),
              tileColor: StudentTheme.cardDark,
              leading: Icon(
                isSel ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSel ? StudentTheme.accentPrimary : StudentTheme.textSecondary,
              ),
              title: Text(cl, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
              onTap: () => setState(() => _selectedClass = cl),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProfileInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Création du Profil Élève',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Modèle 1 Profil = 1 Classe : vous pourrez ajouter d\'autres frères et sœurs plus tard.',
          style: GoogleFonts.inter(fontSize: 14, color: StudentTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _studentNameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Prénom de l\'élève',
            labelStyle: const TextStyle(color: StudentTheme.textSecondary),
            filled: true,
            fillColor: StudentTheme.cardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _schoolCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Établissement scolaire fréquenté',
            labelStyle: const TextStyle(color: StudentTheme.textSecondary),
            filled: true,
            fillColor: StudentTheme.cardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Numéro de téléphone parent (Mobile Money)',
            labelStyle: const TextStyle(color: StudentTheme.textSecondary),
            filled: true,
            fillColor: StudentTheme.cardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStep() {
    return Container(
      padding: const EdgeInsets.all(24),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StudentTheme.accentEmerald.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: StudentTheme.accentEmerald, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prêt à Exceller !',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Votre espace de révision personnalisé est prêt.',
                      style: GoogleFonts.inter(fontSize: 12, color: StudentTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: StudentTheme.borderDark),
          const SizedBox(height: 14),
          _buildSummaryRow('Élève', _studentNameCtrl.text),
          _buildSummaryRow('Pays', _selectedCountry),
          _buildSummaryRow('Classe', _selectedClass),
          _buildSummaryRow('Établissement', _schoolCtrl.text),
          _buildSummaryRow('Accès Initial', 'Pass Découverte (Cours du 1er Trimestre débloqués)'),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: StudentTheme.textSecondary, fontSize: 13)),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
