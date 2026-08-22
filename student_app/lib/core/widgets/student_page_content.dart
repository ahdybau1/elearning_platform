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
    // `Center` + un `ConstrainedBox` limité en largeur SEULE laisse passer une hauteur non bornée
    // (double.infinity) dès que le contenu déclare une taille intrinsèque nulle sur cet axe — ce
    // qui casse tout `Expanded`/`Flexible` plus bas dans l'arbre avec une vraie exception Flutter
    // ("BoxConstraints forces an infinite height"), constatée en direct sur la page Chapitres (plus
    // aucun contenu ne s'affichait sous la bannière). `LayoutBuilder` fixe explicitement la hauteur
    // maximale disponible pour que ce cas ne se reproduise sur aucune page utilisant ce wrapper.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}
