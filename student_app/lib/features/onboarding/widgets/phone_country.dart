import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/student_theme.dart';
import 'auth_ui.dart';

/// Pays proposés pour l'indicatif téléphonique. Le Cameroun est en tête (MVP), puis l'Afrique
/// centrale et de l'Ouest francophone, le Maghreb et les pays de la diaspora.
class PhoneCountry {
  final String iso;
  final String name;
  final String dial;
  /// Exemple de numéro national, affiché en indication dans le champ.
  final String example;

  const PhoneCountry(this.iso, this.name, this.dial, this.example);

  /// Image du drapeau (flagcdn.com, drapeaux du domaine public). Les drapeaux en emoji ne
  /// s'affichent pas sous Windows (on y voit « CM »), d'où une image avec le code en secours.
  String get flagUrl => 'https://flagcdn.com/w40/${iso.toLowerCase()}.png';

  static const cameroon = PhoneCountry('CM', 'Cameroun', '+237', '6 77 12 34 56');

  static const all = <PhoneCountry>[
    cameroon,
    PhoneCountry('GA', 'Gabon', '+241', '06 12 34 56'),
    PhoneCountry('CG', 'Congo', '+242', '06 612 3456'),
    PhoneCountry('CD', 'RD Congo', '+243', '81 234 5678'),
    PhoneCountry('TD', 'Tchad', '+235', '63 01 23 45'),
    PhoneCountry('CF', 'Centrafrique', '+236', '70 01 23 45'),
    PhoneCountry('GQ', 'Guinée équatoriale', '+240', '222 123 456'),
    PhoneCountry('NG', 'Nigeria', '+234', '802 123 4567'),
    PhoneCountry('CI', 'Côte d\'Ivoire', '+225', '07 01 23 45 67'),
    PhoneCountry('SN', 'Sénégal', '+221', '70 123 45 67'),
    PhoneCountry('BJ', 'Bénin', '+229', '01 90 01 12 34'),
    PhoneCountry('TG', 'Togo', '+228', '90 11 23 45'),
    PhoneCountry('BF', 'Burkina Faso', '+226', '70 12 34 56'),
    PhoneCountry('ML', 'Mali', '+223', '65 01 23 45'),
    PhoneCountry('NE', 'Niger', '+227', '93 12 34 56'),
    PhoneCountry('GN', 'Guinée', '+224', '601 12 34 56'),
    PhoneCountry('MG', 'Madagascar', '+261', '32 12 345 67'),
    PhoneCountry('RW', 'Rwanda', '+250', '720 123 456'),
    PhoneCountry('BI', 'Burundi', '+257', '79 56 12 34'),
    PhoneCountry('MA', 'Maroc', '+212', '6 50 12 34 56'),
    PhoneCountry('DZ', 'Algérie', '+213', '5 51 23 45 67'),
    PhoneCountry('TN', 'Tunisie', '+216', '20 123 456'),
    PhoneCountry('FR', 'France', '+33', '6 12 34 56 78'),
    PhoneCountry('BE', 'Belgique', '+32', '470 12 34 56'),
    PhoneCountry('CH', 'Suisse', '+41', '78 123 45 67'),
    PhoneCountry('IT', 'Italie', '+39', '312 345 6789'),
    PhoneCountry('DE', 'Allemagne', '+49', '1512 3456789'),
    PhoneCountry('GB', 'Royaume-Uni', '+44', '7400 123456'),
    PhoneCountry('CA', 'Canada', '+1', '506 234 5678'),
    PhoneCountry('US', 'États-Unis', '+1', '201 555 0123'),
  ];

  /// Numéro complet au format international (+237677123456), ou null si vide.
  String? international(String national) {
    var digits = national.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    // Le 0 initial (préfixe national, ex. France 06…) disparaît au format international,
    // sauf en Côte d'Ivoire et au Bénin où il fait partie du numéro.
    if (iso != 'CI' && iso != 'BJ' && iso != 'GA' && iso != 'CG') {
      digits = digits.replaceFirst(RegExp(r'^0+'), '');
    }
    return '$dial$digits';
  }

  /// Validation : stricte pour le Cameroun (9 chiffres, commence par 6 ou 2), souple ailleurs.
  String? validate(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null; // champ facultatif
    if (iso == 'CM') {
      if (digits.length != 9 || !(digits.startsWith('6') || digits.startsWith('2'))) {
        return '9 chiffres, commençant par 6 (ex. 6 77 12 34 56)';
      }
      return null;
    }
    if (digits.length < 6 || digits.length > 12) return 'Numéro incomplet ou trop long';
    return null;
  }
}

/// Champ téléphone avec choix du pays (drapeau + indicatif) à gauche.
class PhoneNumberField extends StatelessWidget {
  final TextEditingController controller;
  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final String label;
  final String? helper;

  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.label = 'Téléphone (facultatif)',
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      style: TextStyle(color: c.textPrimary, fontSize: 16),
      decoration: authInputDecoration(context, label: label, hint: country.example, helper: helper).copyWith(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 6, right: 4),
          child: TextButton(
            onPressed: () async {
              final picked = await showCountryPicker(context, selected: country);
              if (picked != null) onCountryChanged(picked);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: c.textPrimary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CountryFlag(country: country, height: 16),
                const SizedBox(width: 6),
                Text(country.dial, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                Icon(Icons.arrow_drop_down_rounded, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
      validator: country.validate,
    );
  }
}

/// Liste des pays avec recherche, en feuille modale depuis le bas (pratique au pouce sur mobile).
Future<PhoneCountry?> showCountryPicker(BuildContext context, {required PhoneCountry selected}) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _CountryPickerSheet(selected: selected),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final PhoneCountry selected;
  const _CountryPickerSheet({required this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _normalize(_query.trim());
    final list = PhoneCountry.all
        .where((p) => q.isEmpty || _normalize(p.name).contains(q) || p.dial.contains(q))
        .toList();
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Pays de votre numéro',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  icon: Icon(Icons.close_rounded, color: c.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: false,
              style: TextStyle(color: c.textPrimary),
              decoration: authInputDecoration(context, label: 'Rechercher un pays', icon: Icons.search_rounded),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final p = list[i];
                final isSelected = p.iso == widget.selected.iso;
                return ListTile(
                  leading: CountryFlag(country: p, height: 20),
                  title: Text(p.name, style: GoogleFonts.inter(fontSize: 15, color: c.textPrimary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.dial, style: GoogleFonts.inter(fontSize: 14, color: c.textSecondary)),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle_rounded, color: c.accentPrimary, size: 20),
                      ],
                    ],
                  ),
                  onTap: () => Navigator.pop(context, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Petit drapeau arrondi ; affiche le code ISO si l'image ne charge pas (hors ligne).
class CountryFlag extends StatelessWidget {
  final PhoneCountry country;
  final double height;
  const CountryFlag({super.key, required this.country, this.height = 16});

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      height: height,
      width: height * 1.4,
      child: Center(
        child: Text(country.iso, style: TextStyle(fontSize: height * 0.55, fontWeight: FontWeight.w700, color: context.colors.textSecondary)),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        country.flagUrl,
        height: height,
        width: height * 1.4,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => fallback,
      ),
    );
  }
}
