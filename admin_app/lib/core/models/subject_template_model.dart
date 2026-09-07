import 'package:flutter/material.dart';
import '../design_system/tokens/elef_colors.dart';
import 'lesson_block_model.dart';

enum SubjectCategory {
  scientifique,
  litteraire,
  technique,
  informatique,
  commercial,
  industriel,
}

/// Modèle d'un template de cours par filière/discipline
class SubjectTemplate {
  final String id;
  final String title;
  final String description;
  final SubjectCategory category;
  final String targetSubject;
  final IconData icon;
  final Color color;
  final List<LessonBlock> Function() generateBlocks;

  const SubjectTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetSubject,
    required this.icon,
    required this.color,
    required this.generateBlocks,
  });

  /// Catalogue de tous les templates EDLEARN / ELEF
  static List<SubjectTemplate> get standardTemplates => [
        // 1. Mathématiques : Fiche Spéciale Suites Numériques (Trait pour trait)
        SubjectTemplate(
          id: 'math_suites_numeriques',
          title: 'Fiche Essentielle : Suites Numériques',
          description:
              'Génère la fiche de synthèse visuelle complète traits pour traits comparant suites arithmétiques et géométriques.',
          category: SubjectCategory.scientifique,
          targetSubject: 'Mathématiques — 1ère / Terminale',
          icon: Icons.functions_rounded,
          color: ElefColors.disciplineMath,
          generateBlocks: _generateSuitesNumeriquesBlocks,
        ),

        // 2. Sciences Physiques : Électrocinétique / Ondes
        SubjectTemplate(
          id: 'physique_ondes_rlc',
          title: 'Physique : Circuit RLC & Oscillations',
          description:
              'Structure complète avec situation de départ concrète, lois de Kirchhoff, équation différentielle, simulation et pièges d\'unité.',
          category: SubjectCategory.scientifique,
          targetSubject: 'Physique-Chimie — Terminale',
          icon: Icons.speed_rounded,
          color: ElefColors.disciplinePhysics,
          generateBlocks: _generatePhysiqueRlcBlocks,
        ),

        // 3. Littéraire : Dissertation / Commentaire composé
        SubjectTemplate(
          id: 'litteraire_commentaire',
          title: 'Lettres : Analyse Littéraire & Stylistique',
          description:
              'Template structuré pour le commentaire de texte : problématique, axes de lecture, citations encadrées et méthode pas-à-pas.',
          category: SubjectCategory.litteraire,
          targetSubject: 'Français / Philosophie',
          icon: Icons.auto_stories_rounded,
          color: ElefColors.disciplineLiterature,
          generateBlocks: _generateLitteraireBlocks,
        ),

        // 4. Informatique : Algorithmique & Python
        SubjectTemplate(
          id: 'nsi_algorithmique',
          title: 'Informatique : Algorithmique & Python',
          description:
              'Template interactif avec énoncé du problème, complexité théorique Big-O, code Python exécutable et cas d\'école.',
          category: SubjectCategory.informatique,
          targetSubject: 'NSI / Informatique',
          icon: Icons.terminal_rounded,
          color: ElefColors.disciplineComputer,
          generateBlocks: _generateNsiBlocks,
        ),

        // 5. Technique & Industriel : Génie Électrique & Mécanique
        SubjectTemplate(
          id: 'technique_moteurs',
          title: 'Industriel : Chaîne d\'Énergie & Actionneurs',
          description:
              'Cahier des charges fonctionnel, formules de rendement et couple, schéma d\'atelier et règles de sécurité.',
          category: SubjectCategory.technique,
          targetSubject: 'Génie Électrique / STI2D',
          icon: Icons.precision_manufacturing_rounded,
          color: ElefColors.disciplineIndustrial,
          generateBlocks: _generateTechniqueBlocks,
        ),

        // 6. Commercial : Analyse Financière & Gestion
        SubjectTemplate(
          id: 'commercial_analyse_financiere',
          title: 'Gestion : Seuil de Rentabilité & SIG',
          description:
              'Étude de rentabilité, marge sur coût variable, compte de résultat et ratios financiers clés.',
          category: SubjectCategory.commercial,
          targetSubject: 'Économie-Gestion / STMG',
          icon: Icons.trending_up_rounded,
          color: ElefColors.disciplineCommercial,
          generateBlocks: _generateCommercialBlocks,
        ),
      ];

  // ---------------------------------------------------------------------------
  // Générateurs de Blocs par Discipline
  // ---------------------------------------------------------------------------

  /// 1. Blocs pour la Fiche Traits pour Traits « Suites Numériques »
  static List<LessonBlock> _generateSuitesNumeriquesBlocks() {
    return [
      LessonBlock.paragraph(
        heading: 'Introduction au Chapitre',
        body:
            'Une suite numérique est une liste ordonnée de nombres réels indexée par les entiers naturels. Ce chapitre fondamental constitue le socle de l\'analyse pour les classes de Première et Terminale.',
        order: 1,
      ),
      // Fiche Visuelle Haute Fidélité Traits pour Traits
      LessonBlock.summaryCard(
        title: 'Fiche Synthèse : Suites Arithmétiques vs Géométriques',
        subtitle:
            'Comparatif des définitions par récurrence, termes généraux, sommes et limites',
        columns: [
          {
            'title': 'Suite Arithmétique',
            'badge': 'Addition (+r)',
            'color': 0xFF38BDF8, // Cyan
            'items': [
              {
                'label': 'Relation de récurrence',
                'formula': r'u_{n+1} = u_n + r \quad (r \in \mathbb{R})',
              },
              {
                'label': 'Terme général (degré 1)',
                'formula': r'u_n = u_0 + nr \quad \text{ou} \quad u_n = u_p + (n-p)r',
              },
              {
                'label': 'Somme des termes consécutifs',
                'formula': r'S_n = (n+1) \times \frac{u_0 + u_n}{2}',
              },
              {
                'label': 'Sens de variation',
                'formula': r'r > 0 \implies \nearrow \quad \text{et} \quad r < 0 \implies \searrow',
              },
              {
                'label': 'Comportement asymptotique',
                'formula': r'\lim_{n \to +\infty} u_n = \begin{cases} +\infty & \text{si } r > 0 \\ -\infty & \text{si } r < 0 \end{cases}',
              },
            ],
          },
          {
            'title': 'Suite Géométrique',
            'badge': 'Multiplication (×q)',
            'color': 0xFFA855F7, // Violet
            'items': [
              {
                'label': 'Relation de récurrence',
                'formula': r'u_{n+1} = q \times u_n \quad (q \in \mathbb{R}^*)',
              },
              {
                'label': 'Terme général (exponentiel)',
                'formula': r'u_n = u_0 \times q^n \quad \text{ou} \quad u_n = u_p \times q^{n-p}',
              },
              {
                'label': 'Somme des termes consécutifs (q ≠ 1)',
                'formula': r'S_n = u_0 \times \frac{1 - q^{n+1}}{1 - q}',
              },
              {
                'label': 'Sens de variation (pour u₀ > 0)',
                'formula': r'q > 1 \implies \nearrow \quad \text{et} \quad 0 < q < 1 \implies \searrow',
              },
              {
                'label': 'Limite de qⁿ',
                'formula': r'\lim_{n \to +\infty} q^n = \begin{cases} 0 & \text{si } -1 < q < 1 \\ +\infty & \text{si } q > 1 \\ \text{Indéfinie} & \text{si } q \le -1 \end{cases}',
              },
            ],
          },
        ],
        keyFormula: r'\text{Somme Générale} = (\text{Nb de termes}) \times \frac{\text{1er terme} + \text{Dernier terme}}{2}',
        bulletPoints: [
          'Le nombre de termes de l\'indice p à l\'indice n est exactement : N = n - p + 1.',
          'Pour une suite arithmétique, la moyenne arithmétique est vérifiée : u_n = (u_{n-1} + u_{n+1}) / 2.',
          'Pour une suite géométrique positive, la moyenne géométrique est vérifiée : u_n^2 = u_{n-1} \\times u_{n+1}.',
        ],
        examTrap:
            'Piège Classique au Bac : Dans la formule de la somme d\'une suite géométrique, la puissance au numérateur correspond TOUJOURS au nombre exact de termes (n - p + 1) et non à l\'indice maximal !',
        order: 2,
      ),
      LessonBlock.example(
        heading: 'Exemple Guidé : Calcul d\'un emprunt ou capital',
        body:
            'Soit un capital initial de 10 000 € placé à un taux annuel composé de 3%. Calculer le capital acquis au bout de 5 ans.',
        formulas: [
          r'C_0 = 10\,000',
          r'C_{n+1} = 1{,}03 \times C_n',
          r'C_5 = 10\,000 \times 1{,}03^5 \approx 11\,592{,}74 \text{ €}',
        ],
        order: 3,
      ),
      LessonBlock.trap(
        heading: 'Confusion Indice 0 vs Indice 1',
        body:
            'Si le premier terme est u_1 au lieu de u_0, la somme de n termes va de u_1 à u_n (soit n termes). La puissance dans la suite géométrique est n, et non n+1.',
        order: 4,
      ),
      LessonBlock.examTip(
        heading: 'Rédaction du Raisonnement par Récurrence',
        body:
            'Pour démontrer une propriété sur une suite, respectez impérativement les 3 étapes réglementaires : Initialisation, Hérédité (en précisant l\'hypothèse de récurrence), et Conclusion.',
        order: 5,
      ),
    ];
  }

  /// 2. Blocs pour Physique RLC
  static List<LessonBlock> _generatePhysiqueRlcBlocks() {
    return [
      LessonBlock.paragraph(
        heading: 'Mise en situation concrète',
        body:
            'Dans un circuit oscillant composé d\'une résistance R, d\'une inductance L et d\'un condensateur C, l\'énergie oscille continuellement entre forme électrique et forme magnétique.',
        order: 1,
      ),
      LessonBlock.definition(
        heading: 'Loi des Mailles & Équation Différentielle',
        body:
            'En appliquant la loi des mailles au circuit série libre, on obtient l\'équation régissant la tension u_C(t) aux bornes du condensateur :',
        formulas: [
          r'\frac{\mathrm{d}^2 u_C}{\mathrm{d}t^2} + \frac{R}{L}\frac{\mathrm{d}u_C}{\mathrm{d}t} + \frac{1}{LC}u_C = 0',
          r'\omega_0 = \frac{1}{\sqrt{LC}} \quad \text{(Pulsation propre)}',
        ],
        order: 2,
      ),
      LessonBlock.method(
        heading: 'Identification des 3 régimes d\'oscillation',
        body:
            'Le discriminant de l\'équation caractéristique détermine le comportement physique du système :',
        steps: [
          'Régime pseudo-périodique : amortissement faible (R < 2√(L/C)). Oscillations amorties de pseudo-période T ≈ 2π√(LC).',
          'Régime critique : retour à l\'équilibre le plus rapide sans oscillation (R = 2√(L/C)).',
          'Régime apériodique : fort amortissement (R > 2√(L/C)), retour lent à zéro.',
        ],
        order: 3,
      ),
      LessonBlock.trap(
        heading: 'Unités SI obligatoires',
        body:
            'Attention à convertir la capacité C en Farads (F) et l\'inductance L en Henrys (H) avant tout calcul numérique. Les microfarads (µF) doivent être multipliés par 10⁻⁶.',
        order: 4,
      ),
    ];
  }

  /// 3. Blocs pour Lettres / Philosophie
  static List<LessonBlock> _generateLitteraireBlocks() {
    return [
      LessonBlock.paragraph(
        heading: 'Problématique & Enjeux de l\'Extrait',
        body:
            'Comment l\'auteur utilise-t-il la polyphonie énonciative et l\'ironie voltairienne pour dénoncer l\'illusion optimiste et la cruauté de la guerre ?',
        order: 1,
      ),
      LessonBlock.definition(
        heading: 'Figures de Style Clés',
        body:
            'L\'antiphrase : figure majeure de l\'ironie consistant à dire le contraire de ce que l\'on pense, en laissant entendre clairement sa véritable pensée.',
        order: 2,
      ),
      LessonBlock.method(
        heading: 'Grille d\'analyse stylistique pas-à-pas',
        body:
            'Pour chaque citation remarquable du texte, structurez votre développement selon le triptyque : Citer le procédé précis -> Analyser son fonctionnement grammatical/rythmique -> Dégager le sens philosophique profond.',
        order: 3,
      ),
      LessonBlock.examTip(
        heading: 'Transition entre les axes',
        body:
            'Bannissez les formules creuses comme "Dans un second temps nous verrons...". Rédigez un bilan synthétique de l\'axe I qui appelle naturellement la problématique de l\'axe II.',
        order: 4,
      ),
    ];
  }

  /// 4. Blocs pour NSI / Informatique
  static List<LessonBlock> _generateNsiBlocks() {
    return [
      LessonBlock.paragraph(
        heading: 'Contexte Algorithmique : Recherche Dichotomique',
        body:
            'La recherche dichotomique (binary search) permet de localiser un élément dans une liste préalablement triée en temps logarithmique O(log n), contre O(n) pour une recherche séquentielle.',
        order: 1,
      ),
      LessonBlock.codeRunner(
        heading: 'Implémentation Référence en Python 3',
        language: 'Python',
        initialCode: '''def recherche_dichotomique(tableau, cible):
    gauche = 0
    droite = len(tableau) - 1
    
    while gauche <= droite:
        milieu = (gauche + droite) // 2
        if tableau[milieu] == cible:
            return milieu  # Trouvé à l'indice milieu
        elif tableau[milieu] < cible:
            gauche = milieu + 1
        else:
            droite = milieu - 1
            
    return -1  # Élément non présent

# Test de validation
valeurs = [2, 5, 8, 12, 16, 23, 38, 56, 72, 91]
print("Indice de 23 :", recherche_dichotomique(valeurs, 23))
print("Indice de 42 :", recherche_dichotomique(valeurs, 42))''',
        expectedOutput: 'Indice de 23 : 5\nIndice de 42 : -1',
        order: 2,
      ),
      LessonBlock.trap(
        heading: 'Précondition impérative',
        body:
            'La dichotomie ne fonctionne QUE sur un tableau impérativement trié ! L\'exécuter sur un tableau non trié conduit à un résultat faux sans lever d\'erreur d\'exécution.',
        order: 3,
      ),
    ];
  }

  /// 5. Blocs pour Technique & Industriel
  static List<LessonBlock> _generateTechniqueBlocks() {
    return [
      LessonBlock.paragraph(
        heading: 'Cahier des charges : Motorisation d\'un convoyeur',
        body:
            'Dimensionnement d\'un moto-réducteur électrique asynchrone pour l\'entraînement d\'une bande transporteuse de pièces métalliques de 350 kg à vitesse constante.',
        order: 1,
      ),
      LessonBlock.formula(
        heading: 'Puissance Mécanique & Couple',
        latexFormula: r'P = C \times \omega \quad \text{avec } \omega = \frac{2\pi N}{60}',
        explanation:
            'P en Watts (W), Couple C en Newtons-mètres (N.m), Vitesse angulaire ω en radians par seconde (rad/s), N en tours par minute (tr/min).',
        order: 2,
      ),
      LessonBlock.method(
        heading: 'Calcul du Rendement Global de la Chaîne',
        body:
            'Le rendement global d\'une chaîne cinématique en série est égal au produit des rendements individuels de chaque organe :',
        steps: [
          'Rendement réducteur à engrenages : η₁ ≈ 0,92',
          'Rendement transmission poulie-courroie : η₂ ≈ 0,95',
          'Rendement global : η_total = η₁ × η₂ ≈ 0,874 (87,4%)',
          'Puissance électrique requise : P_elec = P_utile / η_total',
        ],
        order: 3,
      ),
      LessonBlock.trap(
        heading: 'Règle de sécurité NFC 15-100',
        body:
            'Avant toute intervention sur le bornier du moteur, vérifier impérativement la consignation électrique en 4 étapes : Séparation, Condamnation, VAT (Vérification d\'Absence de Tension), Mise à la terre.',
        order: 4,
      ),
    ];
  }

  /// 6. Blocs pour Commercial & Économie
  static List<LessonBlock> _generateCommercialBlocks() {
    return [
      LessonBlock.paragraph(
        heading: 'Étude du Point Mort & Seuil de Rentabilité',
        body:
            'Le seuil de rentabilité (SR) représente le niveau de chiffre d\'affaires pour lequel l\'entreprise ne dégage ni bénéfice ni perte. Le résultat d\'exploitation est alors égal à zéro.',
        order: 1,
      ),
      LessonBlock.formula(
        heading: 'Formule du Seuil de Rentabilité (SR)',
        latexFormula: r'SR = \frac{\text{Charges Fixes (CF)}}{\text{Taux de Marge sur Coûts Variables (TMCV)}}',
        explanation: 'Où TMCV = (Chiffre d\'Affaires - Coûts Variables) / Chiffre d\'Affaires.',
        order: 2,
      ),
      LessonBlock.summaryCard(
        title: 'Indicateurs Clés de Gestion Commerciale',
        subtitle: 'Ratios fondamentaux pour le pilotage d\'activité',
        columns: [
          {
            'title': 'Rentabilité Opérationnelle',
            'badge': 'Performance',
            'color': 0xFF14B8A6,
            'items': [
              {
                'label': 'Point Mort (en jours)',
                'formula': r'PM = \frac{SR}{CA} \times 360',
              },
              {
                'label': 'Marge de Sécurité',
                'formula': r'MS = CA - SR',
              },
            ],
          },
          {
            'title': 'Trésorerie & BFR',
            'badge': 'Liquidité',
            'color': 0xFFF59E0B,
            'items': [
              {
                'label': 'Besoin en Fonds de Roulement',
                'formula': r'BFR = \text{Stocks} + \text{Créances} - \text{Dettes court terme}',
              },
              {
                'label': 'Trésorerie Nette',
                'formula': r'TN = \text{Fonds de Roulement} - BFR',
              },
            ],
          },
        ],
        keyFormula: r'\text{Indice de Sécurité} = \frac{CA - SR}{CA} \times 100 \text{ (\%)}',
        bulletPoints: [
          'Plus l\'indice de sécurité est élevé (> 20%), plus l\'entreprise résiste à une baisse imprévue de conjoncture.',
          'Le point mort indique la date dans l\'année civile à partir de laquelle l\'activité devient profitable.',
        ],
        examTrap:
            'Attention à ne pas inclure les charges fixes directes dans les coûts variables lors du calcul du TMCV.',
        order: 3,
      ),
    ];
  }
}
