# CAHIER TECHNIQUE — EDLEARN CONTENT FACTORY

## 1. But
Transformer création manuelle, PDF/DOCX/scans, exercices, examens et générations IA en **contenu pédagogique structuré**, rendu par les mêmes composants configurables dans l'Admin, l'application élève, le PDF et les packages offline.

## 2. Principe canonique
`SOURCE -> EXTRACTION -> STRUCTURATION -> CURRICULUM MAPPING -> CATALOG MAPPING -> VALIDATION -> HUMAN REVIEW -> VERSION -> RENDERERS -> PUBLICATION`.

Le fichier uploadé est une source, pas automatiquement l'interface finale. Le contenu canonique ne doit pas être un gros HTML : il est composé de blocs typés avec contenu, métadonnées, ordre, version, provenance et renderer/template key.

## 3. Entrées Admin
- Créer manuellement.
- Importer PDF/DOCX/TXT/image/scan.
- Générer avec IA.
- Générer des exercices depuis un cours.
- Extraire exercices/examens/corrigés d'un document.
- Importer en masse via formats structurés validés.

## 4. Catalogues pédagogiques
Catalogues administrables et versionnés par matière. Exemples : définition, théorème, preuve, formule, exemple, méthode, expérience, protocole, carte, frise, biographie, dialogue, vocabulaire, audio, exercice, résumé. Ne pas hardcoder la taxonomie dans les écrans Flutter.

## 5. Rendering Engine
Registre `renderer_key -> widget renderer`. Premiers types : paragraph, heading, definition, theorem, formula, example, image, video, exercise, summary. Responsive mobile/tablette/desktop, thèmes, accessibilité, PDF et offline à partir de la même source structurée.

## 6. Upload pipeline
1. stocker original + checksum/provenance ; 2. extraction native ; 3. OCR si nécessaire ; 4. reconnaissance formules ; 5. structuration ; 6. mapping curriculum/compétences ; 7. mapping catalogue ; 8. signaler éléments manquants ; 9. preview ; 10. correction humaine ; 11. validation ; 12. publication/versioning.

## 7. Course Generator
Le générateur reçoit pays/section/classe/série/matière/chapitre/leçon, récupère curriculum, compétences, prérequis, RAG validé, catalogue et règles pédagogiques. Il retourne du JSON conforme au schéma Content Factory, jamais une page Flutter arbitraire.

## 8. Exercise Factory
Création, import, extraction et génération. Structure : statement, questions, answers, solution, hints, difficulty, skills, prerequisites, answer_mode, grading, provenance. Validation individuelle accepter/modifier/régénérer/rejeter.

## 9. Workflow
DRAFT -> AI_PRECHECK -> WAITING_REVIEW -> NEEDS_CHANGES/APPROVED -> SCHEDULED/PUBLISHED -> ARCHIVED. Toute modification publiée crée une nouvelle version ; rollback audité.

## 10. Jobs
OCR, parsing, génération massive, PDF et ingestion RAG sont asynchrones : queued/processing/waiting_validation/completed/failed/cancelled avec progression, retry, idempotence et notification.

## 11. Sécurité
RBAC/ABAC, RLS côté données, fichiers scannés, limites taille/type, provenance, audit, aucun agent avec SQL arbitraire, publication humaine par défaut.

## 12. Jalon E2E initial
Admin crée un cours Terminale C Mathématiques -> ajoute blocs -> preview -> draft -> review -> approve -> publish -> l'élève ouvre la leçon et obtient le rendu configuré. Deuxième jalon : upload document -> structuration -> preview -> correction -> publication. Troisième : cours -> génération exercices -> revue individuelle -> publication -> tentative élève -> correction/mastery evidence.
