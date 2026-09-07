/// Section structurée d'une fiche de synthèse (Content != Presentation)
class SummarySheetSection {
  final String title;
  final String formulaLatex;
  final String explanation;
  final List<String> bulletPoints;
  final String? tip;

  const SummarySheetSection({
    required this.title,
    required this.formulaLatex,
    required this.explanation,
    this.bulletPoints = const [],
    this.tip,
  });
}

/// Modèle canonique d'une Fiche de Synthèse Pédagogique Officielle
class SummarySheet {
  final String id;
  final String title;
  final String subject;
  final String level;
  final String chapterTag;
  final String imageAssetPath;
  final List<SummarySheetSection> sections;

  const SummarySheet({
    required this.id,
    required this.title,
    required this.subject,
    this.level = 'Terminale C, D & TI',
    required this.chapterTag,
    required this.imageAssetPath,
    required this.sections,
  });
}

/// Registre des fiches pédagogiques de référence d'EDLEARN
class SummarySheetRegistry {
  SummarySheetRegistry._();

  static const List<SummarySheet> sheets = [
    // 1. FICHE SUITES RÉELLES (Mathématiques)
    SummarySheet(
      id: 'math-suites-reelles',
      title: 'Résumé : Suites Réelles',
      subject: 'Mathématiques',
      chapterTag: 'suites',
      imageAssetPath: 'assets/sheets/math_suites_reelles.jpg',
      sections: [
        SummarySheetSection(
          title: '1. Suite Arithmétique vs Suite Géométrique',
          formulaLatex: r'''\begin{aligned}
\text{Arithmétique : } & U_{n+1} - U_n = r \implies U_n = U_0 + n \cdot r \\
\text{Somme : } & S = \frac{N(P + D)}{2} \\
\text{Géométrique : } & U_{n+1} = q \cdot U_n \implies U_n = U_0 \cdot q^n \\
\text{Somme : } & S = P \cdot \frac{1 - q^N}{1 - q}
\end{aligned}''',
          explanation: 'Notations fondamentales du programme :',
          bulletPoints: [
            'P : Premier terme considéré',
            'D : Dernier terme de la somme',
            'N : Nombre de termes sommés = (Indice final - Indice initial + 1)',
            'r : Raison de la suite arithmétique',
            'q : Raison de la suite géométrique',
          ],
          tip: 'Attention : Pour une somme de U_1 à U_n, le nombre de termes est n. De U_0 à U_n, il y a (n+1) termes !',
        ),
        SummarySheetSection(
          title: '2. Raisonnement par Récurrence',
          formulaLatex: r'\forall n \ge n_0, \quad \mathcal{P}(n) \text{ est vraie}',
          explanation: 'Démonstration rigoureuse en trois étapes indissociables :',
          bulletPoints: [
            'Étape 1 (Initialisation) : On vérifie que la proposition P(n) est vraie pour le premier rang n_0.',
            'Étape 2 (Hérédité) : On suppose que P(n) est vraie pour un rang n fixé (Hypothèse de récurrence), et on démontre que P(n+1) est vraie.',
            'Étape 3 (Conclusion) : D\'après le principe de récurrence, P(n) est vraie pour tout n ≥ n_0.',
          ],
        ),
        SummarySheetSection(
          title: '3. Limites de q^n & Monotonie',
          formulaLatex: r'''\lim_{n \to +\infty} q^n = \begin{cases}
0 & \text{si } -1 < q < 1 \\
1 & \text{si } q = 1 \\
+\infty & \text{si } q > 1 \\
\text{Indéterminée (n'existe pas)} & \text{si } q \le -1
\end{cases}''',
          explanation: 'Étude du sens de variation (Monotonie) :',
          bulletPoints: [
            'Si U_{n+1} - U_n > 0 alors (U_n) est strictement croissante.',
            'Si U_{n+1} - U_n < 0 alors (U_n) est strictement décroissante.',
            'Pour des suites à termes strictement positifs : comparer U_{n+1}/U_n à 1.',
          ],
        ),
        SummarySheetSection(
          title: '4. Théorèmes de Convergence & Comparaisons',
          formulaLatex: r'''V_n \le U_n \le W_n \quad \text{et} \quad \lim V_n = \lim W_n = \ell \implies \lim U_n = \ell''',
          explanation: 'Théorèmes cardinaux pour le Baccalauréat :',
          bulletPoints: [
            'Théorème de convergence monotone : Toute suite croissante et majorée est convergente.',
            'Toute suite décroissante et minorée est convergente.',
            'Théorème des Gendarmes : Encadrement par deux suites tendant vers la même limite.',
            'Théorème de comparaison à l\'infini : Si U_n ≥ V_n et lim V_n = +∞, alors lim U_n = +∞.',
          ],
        ),
      ],
    ),

    // 2. FICHE LES OSCILLATEURS (Physique)
    SummarySheet(
      id: 'physique-oscillateurs-classification',
      title: 'Les Oscillateurs Mécaniques',
      subject: 'Physique-Chimie',
      chapterTag: 'oscillateurs',
      imageAssetPath: 'assets/sheets/physique_oscillateurs_classification.jpg',
      sections: [
        SummarySheetSection(
          title: '1. Classification des 4 Oscillateurs Fondamentaux',
          formulaLatex: r'''\begin{aligned}
\text{Pendule élastique} & \longleftrightarrow \text{Ressort + Masse } (m, k) \\
\text{Pendule de torsion} & \longleftrightarrow \text{Fil de torsion + Disque } (C, J_\Delta) \\
\text{Pendule pesant} & \longleftrightarrow \text{Solide oscillant autour d'un axe horizontal } (d, J_\Delta) \\
\text{Pendule simple} & \longleftrightarrow \text{Fil inextensible de longueur } L \text{ + Masse ponctuelle } m
\end{aligned}''',
          explanation: 'Deux approches mécaniques selon la nature du mouvement :',
          bulletPoints: [
            'Translation (Pendule élastique) : Application directe de la IIᵉ Loi de Newton : ∑ F_ext = m · a_G',
            'Rotation (Pendules de torsion, pesant, simple) : Relation Fondamentale de la Dynamique en rotation (R.F.D.) : ∑ M_Δ(F_ext) = J_Δ · θ̈',
          ],
        ),
        SummarySheetSection(
          title: '2. Bilan Dynamique : Translation vs Rotation',
          formulaLatex: r'''\sum \vec{F}_{\text{ext}} = m \cdot \vec{a}_G \quad \Big| \quad \sum \mathcal{M}_\Delta(\vec{F}_{\text{ext}}) = J_\Delta \cdot \ddot{\theta}''',
          explanation: 'Choisir le bon référentiel et le bon axe de projection pour isoler le système mécanique.',
          bulletPoints: [
            'En translation : Repère cartésien (O, i, j). Projection sur l\'axe du mouvement.',
            'En rotation : Coordonnées angulaires θ(t), vitesse angulaire θ̇, accélération angulaire θ̈.',
          ],
        ),
      ],
    ),

    // 3. FICHE ÉTUDE DYNAMIQUE DU PENDULE ÉLASTIQUE (Physique)
    SummarySheet(
      id: 'physique-pendule-elastique-dynamique',
      title: 'Étude Dynamique du Pendule Élastique',
      subject: 'Physique-Chimie',
      chapterTag: 'pendule_elastique',
      imageAssetPath: 'assets/sheets/physique_pendule_elastique_dynamique.jpg',
      sections: [
        SummarySheetSection(
          title: '1. Étude à l\'Équilibre selon la Configuration',
          formulaLatex: r'''\begin{aligned}
\text{Horizontal : } & \Delta \ell_0 = 0 \\
\text{Plan Incliné (angle } \alpha \text{) : } & m \cdot g \cdot \sin\alpha - k \cdot \Delta \ell_0 = 0 \implies \Delta \ell_0 = \frac{m \cdot g \cdot \sin\alpha}{k} \\
\text{Vertical : } & m \cdot g - k \cdot \Delta \ell_0 = 0 \implies \Delta \ell_0 = \frac{m \cdot g}{k}
\end{aligned}''',
          explanation: 'À l\'équilibre : ∑ F_ext = 0 (Le poids P, la réaction R du support et la tension F_0 du ressort s\'annulent).',
        ),
        SummarySheetSection(
          title: '2. Équation Différentielle du Mouvement',
          formulaLatex: r'\ddot{x} + \frac{k}{m} x = 0 \quad \iff \quad \ddot{x} + \omega_0^2 x = 0',
          explanation: 'Nature du mouvement :',
          bulletPoints: [
            'Puisque l\'équation différentielle est linéaire du second ordre sans second membre à coefficients constants positifs :',
            'Le mouvement est une translation oscillatoire harmonique sinusoïdale rectiligne.',
            'Pulsation propre : ω_0 = √(k / m) en rad/s',
          ],
        ),
        SummarySheetSection(
          title: '3. Période Propre & Équation Horaire',
          formulaLatex: r'''T_0 = 2\pi \sqrt{\frac{m}{k}} \qquad x(t) = X_m \cdot \cos\left(\frac{2\pi}{T_0} t + \varphi\right)''',
          explanation: 'Grandeurs caractéristiques de l\'oscillateur :',
          bulletPoints: [
            'T_0 : Période propre des oscillations (en secondes s)',
            'X_m : Amplitude maximale des oscillations (en mètres m), toujours strictement positive',
            'φ : Phase initiale à t = 0 (en radians rad), déterminée par les Conditions Initiales (C.I.)',
          ],
          tip: 'Astuce d\'examen : Si le solide est lâché sans vitesse initiale depuis x_0 > 0 à t=0, alors X_m = x_0 et φ = 0.',
        ),
      ],
    ),
  ];

  /// Recherche une fiche de synthèse par mot-clé (matière, titre ou tag chapitre)
  static SummarySheet? findSheetFor(String query) {
    final lower = query.toLowerCase();
    for (final sheet in sheets) {
      if (sheet.chapterTag.contains(lower) ||
          sheet.title.toLowerCase().contains(lower) ||
          lower.contains(sheet.chapterTag)) {
        return sheet;
      }
    }
    // Par défaut, retourner la première fiche math ou physique si demandée
    if (lower.contains('math')) return sheets.first;
    if (lower.contains('phys')) return sheets[1];
    return sheets.first;
  }
}
