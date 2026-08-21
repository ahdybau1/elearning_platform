import 'package:flutter/material.dart';

/// Centre le contenu d'une page et le limite à une largeur de lecture confortable sur grand écran
/// (web/desktop, cible de premier plan du cahier des charges — §1.4). Sans cette limite, les
/// `Row(mainAxisAlignment: spaceBetween)` des cartes s'étirent sur toute la largeur de l'écran et
/// leurs éléments (badges, boutons) se retrouvent à des centaines de pixels les uns des autres —
/// un rendu cassé constaté en direct sur la page Chapitres. À envelopper directement autour du
/// corps scrollable de chaque écran (`body: StudentPageContent(child: ...)`).
class StudentPageContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const StudentPageContent({super.key, required this.child, this.maxWidth = 860});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
