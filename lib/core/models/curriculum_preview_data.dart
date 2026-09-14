class CurriculumCandidateNode {
  final String id;
  final String title;
  final String type; // country, subsystem, cycle, class, subject, chapter
  final int? coefficient;
  final int? trimester;
  final bool isOfficial;
  final String officialSource;
  final List<String> skills;
  final List<CurriculumCandidateNode> children;

  CurriculumCandidateNode({
    required this.id,
    required this.title,
    required this.type,
    this.coefficient,
    this.trimester,
    this.isOfficial = false,
    this.officialSource = 'Exemple local — source officielle non vérifiée',
    this.skills = const [],
    this.children = const [],
  });
}

List<CurriculumCandidateNode> sampleCurriculum() {
  return [
    CurriculumCandidateNode(
      id: 'node_cm_fr',
      title: 'Cameroun — Sous-système Francophone',
      type: 'subsystem',
      officialSource: 'Exemple local — source officielle non vérifiée',
      children: [
        CurriculumCandidateNode(
          id: 'cycle_2',
          title: 'Second Cycle (Lycée)',
          type: 'cycle',
          children: [
            CurriculumCandidateNode(
              id: 'class_tle_c',
              title: 'Terminale C (Scientifique Math & Physique)',
              type: 'class',
              children: [
                CurriculumCandidateNode(
                  id: 'sub_math_tc',
                  title: 'Mathématiques',
                  type: 'subject',
                  coefficient: 7,
                  children: [
                    CurriculumCandidateNode(
                      id: 'chap_1',
                      title:
                          'Chapitre 1 : Limites, Continuité et Suites Réelles',
                      type: 'chapter',
                      trimester: 1,
                      skills: [
                        'Calculer la limite d\'une suite géométrique q^n',
                        'Appliquer le théorème des gendarmes',
                        'Démontrer la convergence d\'une suite monotone bornée',
                      ],
                    ),
                    CurriculumCandidateNode(
                      id: 'chap_2',
                      title:
                          'Chapitre 2 : Dérivation, Tangentes et Étude de Fonctions',
                      type: 'chapter',
                      trimester: 1,
                      skills: [
                        'Calculer la dérivée f\'(x) d\'une fonction rationnelle',
                        'Déterminer l\'équation de la tangente au point d\'abscisse x0',
                        'Dresser le tableau de variation complet',
                      ],
                    ),
                    CurriculumCandidateNode(
                      id: 'chap_3',
                      title:
                          'Chapitre 3 : Fonctions Logarithme Népérien & Exponentielle',
                      type: 'chapter',
                      trimester: 2,
                      skills: [
                        'Résoudre des équations et inéquations avec ln(x) et exp(x)',
                        'Calculer les limites remarquables en 0 et +∞',
                      ],
                    ),
                    CurriculumCandidateNode(
                      id: 'chap_4',
                      title:
                          'Chapitre 4 : Nombres Complexes & Géométrie du Plan',
                      type: 'chapter',
                      trimester: 2,
                      skills: [
                        'Écrire un nombre complexe sous forme algébrique et trigonométrique',
                        'Caractériser une similitude directe du plan',
                      ],
                    ),
                    CurriculumCandidateNode(
                      id: 'chap_5',
                      title:
                          'Chapitre 5 : Primitives, Intégration et Calcul d\'Aires',
                      type: 'chapter',
                      trimester: 3,
                      skills: [
                        'Calculer une intégrale par parties',
                        'Déterminer la valeur moyenne et l\'aire sous la courbe',
                      ],
                    ),
                  ],
                ),
                CurriculumCandidateNode(
                  id: 'sub_phys_tc',
                  title: 'Physique & Chimie',
                  type: 'subject',
                  coefficient: 6,
                  children: [
                    CurriculumCandidateNode(
                      id: 'chap_pc_1',
                      title: 'Chapitre 1 : Cinématique et Lois de Newton',
                      type: 'chapter',
                      trimester: 1,
                      skills: [
                        'Appliquer la 2e loi de Newton (P = mg, somme des forces = ma)',
                        'Déterminer les équations horaires d\'un projectile',
                      ],
                    ),
                    CurriculumCandidateNode(
                      id: 'chap_pc_2',
                      title:
                          'Chapitre 2 : Circuit RLC et Oscillations Électriques',
                      type: 'chapter',
                      trimester: 2,
                      skills: [
                        'Établir l\'équation différentielle de charge du condensateur RC',
                        'Calculer la constante de temps tau = RC',
                      ],
                    ),
                  ],
                ),
              ],
            ),
            CurriculumCandidateNode(
              id: 'class_tle_d',
              title: 'Terminale D (Sciences Expérimentales & SVT)',
              type: 'class',
              children: [
                CurriculumCandidateNode(
                  id: 'sub_svt_td',
                  title: 'Sciences de la Vie et de la Terre',
                  type: 'subject',
                  coefficient: 6,
                  children: [
                    CurriculumCandidateNode(
                      id: 'chap_svt_1',
                      title: 'Chapitre 1 : Génétique et Brassage Chromosomique',
                      type: 'chapter',
                      trimester: 1,
                      skills: [
                        'Analyser un arbre généalogique héréditaire',
                        'Expliquer les mécanismes de méiose et fécondation',
                      ],
                    ),
                  ],
                ),
              ],
            ),
            CurriculumCandidateNode(
              id: 'class_1ere_c',
              title: 'Première C (Mathématiques & Sciences Physiques)',
              type: 'class',
              children: [
                CurriculumCandidateNode(
                  id: 'sub_math_1c',
                  title: 'Mathématiques',
                  type: 'subject',
                  coefficient: 6,
                  children: [
                    CurriculumCandidateNode(
                      id: 'chap_1c_1',
                      title:
                          'Chapitre 1 : Polynômes du Second Degré & Équations',
                      type: 'chapter',
                      trimester: 1,
                      skills: [
                        'Calculer le discriminant Delta = b^2 - 4ac',
                        'Trouver le sommet et les racines d\'une parabole',
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}
