# CAHIER DES CHARGES — AGENTS IA EDLEARN

**Plateforme E-learning Cameroun — Collège et Lycée**  
**Version : 1.0 consolidée — 28 août 2026**  
**Statut : spécification technique et fonctionnelle pour vibe coding**

> Ce document complète le cahier maître. Il ne remplace aucune exigence du cahier principal. En cas de conflit, les décisions fermes les plus récentes validées par le porteur du projet, puis le cahier maître mis à jour, priment.

---

## 1. Objet

Ce document spécifie la couche d'agents IA de la plateforme : responsabilités, frontières, données, outils, RAG, modèles, quotas, sécurité, observabilité, modes dégradés, tests et administration.

L'objectif n'est pas de créer 26 chatbots indépendants. Un **agent** est un workflow métier spécialisé qui combine, selon le besoin : règles déterministes, RAG, Student Model, Competency Graph, outils typés, cache, modèles locaux/on-device/serveur, validation humaine et journalisation.

Principe directeur :

> **Le LLM comprend, raisonne, explique, crée et orchestre ; les bibliothèques spécialisées calculent, exécutent, rendent, simulent et stockent.**

---

## 2. Contraintes absolues

1. Aucune API IA commerciale payante n'est une dépendance obligatoire.
2. Les modèles sont interchangeables via un Model Provider/Router.
3. Aucun agent n'obtient un accès SQL générique à toute la base.
4. Les outils sont allowlistés, typés, autorisés par contexte et audités.
5. Toute sortie structurée est validée avant effet métier.
6. Publication pédagogique, notes officielles, sanctions, remboursements et actions financières passent par les services métier et les validations requises.
7. Les fonctions pédagogiques essentielles disposent d'un mode sans LLM lorsque techniquement pertinent.
8. Les contenus destinés aux mineurs suivent les règles de validation humaine du cahier maître.
9. Les quotas protègent principalement le **compute distant/génératif coûteux** ; ils ne doivent pas artificiellement bloquer les moteurs déterministes, le cache ou les contenus déjà publiés.
10. Les valeurs numériques de quotas ne sont pas codées en dur avant benchmark réel.

Configuration cible :

```env
AI_ZERO_COST_MODE=true
AI_QUOTA_ENGINE=true
LOCAL_AI_COUNTS_AGAINST_QUOTA=false
DETERMINISTIC_TOOLS_COUNTS_AGAINST_QUOTA=false
CACHED_AI_COUNTS_AGAINST_QUOTA=false
REMOTE_COMPUTE_QUOTA=true
PROVIDER_LOCK_IN=false
```

---

## 3. Architecture cible

```text
Flutter / PWA
    |
    +-- LocalTaskRouter
    |     +-- cache
    |     +-- local RAG
    |     +-- deterministic tools
    |     +-- Device AI
    |
    +-- Sovereign AI Gateway (FastAPI)
          +-- authentication / authorization
          +-- Agent Orchestrator (LangGraph cible)
          +-- Entitlement & Quota Engine
          +-- RAG services
          +-- Tool Gateway
          +-- Shared Cache
          +-- Model Router / LiteLLM-compatible abstraction
          +-- Compute Scheduler
          +-- Observability / Evaluation
          |
          +-- vLLM / llama.cpp / Ollama / ONNX / device runtimes
          +-- optional providers disabled by default
```

### 3.1 Deux orchestrateurs

**Local Orchestrator Flutter/Dart** : décide si la demande peut être résolue par cache, contenu validé, outil local, RAG local ou modèle on-device.

**Sovereign AI Gateway** : prend en charge les workflows serveur, RAG global, modèles plus lourds, queues, Compute Fabric, évaluations et politiques centralisées.

---

## 4. Contrat standard de tout agent

Chaque agent DOIT déclarer :

- `agent_id`, `name`, `version`, `status` ;
- mission et non-mission ;
- acteurs autorisés et scopes ;
- triggers ;
- schéma JSON d'entrée et de sortie ;
- données lisibles et données modifiables ;
- tools autorisés/interdits ;
- politique RAG ;
- politique mémoire ;
- politique modèle ;
- classe de coût/quota ;
- timeout, retry, cache et idempotence ;
- mode offline/dégradé ;
- validations automatiques ;
- Human-In-The-Loop ;
- métriques ;
- tests ;
- rollback/versioning.

### 4.1 Envelope d'entrée commun

```json
{
  "request_id": "uuid",
  "agent_id": "AIA-AGT-001",
  "actor": {"account_id": "uuid", "role": "student", "scopes": []},
  "profile_id": "uuid-or-null",
  "academic_context": {
    "country_id": "uuid",
    "curriculum_version_id": "uuid",
    "class_id": "uuid",
    "series_id": "uuid-or-null",
    "subject_id": "uuid-or-null",
    "chapter_id": "uuid-or-null",
    "lesson_id": "uuid-or-null",
    "skill_ids": []
  },
  "locale": "fr-CM",
  "device_context": {"online": true, "device_tier": "low"},
  "entitlement_context": {"plan_id": "uuid", "ai_policy_id": "uuid"},
  "payload": {}
}
```

### 4.2 Envelope de sortie commun

```json
{
  "request_id": "uuid",
  "status": "success|partial|needs_review|rejected|failed",
  "result": {},
  "citations": [],
  "tool_trace_summary": [],
  "safety": {"flags": [], "human_review_required": false},
  "usage": {"route": "deterministic|cache|device|server", "compute_units": 0},
  "agent_version": "semver",
  "model_version": "string-or-null"
}
```

---

## 5. Routage, modèles et coûts

Ordre préféré :

```text
1. règles / moteur déterministe
2. cache / contenu validé
3. Device AI
4. Device AI + RAG + tools
5. Compute Fabric souverain
6. capacité externe gratuite autorisée
7. provider payant optionnel, désactivé en AI_ZERO_COST_MODE
```

Les agents ne choisissent pas directement un fournisseur. Ils demandent une **capability** : `classification_small`, `pedagogy_small`, `reasoning_strong`, `vision_ocr`, `embedding`, etc. Le Model Router choisit le moteur autorisé.

### 5.1 Trois cerveaux logiques

- **EduRouter** : petit modèle/classifieur pour intention, routage, tool calling simple.
- **EduSmall** : modèle pédagogique local/on-device ou serveur léger pour tutorat courant.
- **EduStrong** : modèle plus puissant pour tâches complexes, uniquement si nécessaire.

Les 26 agents logiques peuvent partager ces modèles, prompts, tools et adapters. Il est interdit de créer 26 gros modèles séparés par défaut.

---

## 6. Entitlements, quotas et AI Compute Credits

Le droit d'abonnement et le droit IA sont deux concepts distincts.

```text
SUBSCRIPTION -> AI POLICY -> ALLOWANCES / PRIORITY / MODEL TIER / CONCURRENCY
```

L'Admin doit pouvoir définir des politiques pour FREE, DAY_PASS, WEEKLY, MONTHLY, PREMIUM, SCHOOL ou futures offres.

Une action IA reçoit un poids de compute calculé à partir de métriques observables : modèle, tokens, durée GPU/CPU, OCR, vision, audio, génération, taille de contexte, etc. Les valeurs finales sont déterminées par benchmark, jamais inventées dans le code.

À quota distant épuisé : basculer vers cache, contenu validé, outil déterministe, Device AI, modèle plus léger, queue différée ou message utile. Les cours, exercices existants, examens, jeux publiés, musiques publiées, labs déterministes et offline restent accessibles selon les droits pédagogiques du plan.

---

# 7. CATALOGUE OFFICIEL DES 26 AGENTS

## AIA-AGT-001 — TutorAgent

**Mission.** Tutorat conversationnel personnalisé, contextualisé par curriculum, Student Model et contenus validés. Explique, questionne, donne des indices et adapte la profondeur.

**Non-mission.** Ne modifie pas une note officielle, ne publie pas de contenu, ne remplace pas un enseignant dans une décision sensible, ne calcule pas approximativement lorsqu'un moteur exact existe.

**Entrées métier.** Question, contexte académique, compétence ciblée, historique conversationnel court, maîtrise/confidence, préférences d'accessibilité.

**Sortie.** Réponse pédagogique structurée : `answer`, `steps`, `hints`, `check_for_understanding`, `recommended_next_action`, citations.

**Tools.** `search_validated_content`, `get_skill_context`, `get_student_mastery`, `sympy_solve`, `numeric_compute`, `get_formula`, `get_example`, `create_learning_event`.

**RAG.** Curriculum et contenus publiés du scope actif uniquement. Citations obligatoires pour les faits pédagogiques récupérés.

**Mémoire.** Mémoire conversationnelle courte + Student Model structuré ; pas de stockage illimité du chat brut.

**Modèle.** Cache/déterministe si possible — EduSmall — EduStrong pour difficulté justifiée.

**Quota.** Cache/tools/local généralement 0 remote credits ; inférence distante pondérée.

**Workflow.** Classifier intention — récupérer contexte — rechercher sources — choisir tools — produire réponse — vérifier niveau/factualité — proposer mini-vérification — journaliser preuve utile.

**HITL.** Escalade vers enseignant/support selon règles de sécurité ou impossibilité pédagogique.

**Critères d'acceptation.** Ne fuit aucun autre profil ; respecte niveau/classe ; cite le RAG ; utilise le moteur exact pour calculs ; mode dégradé utile ; latence et coût observables.

---

## AIA-AGT-002 — SocraticAgent

**Mission.** Faire progresser l'élève par questions graduées plutôt que donner immédiatement la solution.

**Entrées.** Problème, tentative de l'élève, compétence, niveau de maîtrise, nombre d'indices déjà consommés.

**Sortie.** `next_question`, `hint_level`, `diagnostic_signal`, `stop_condition`.

**Tools.** RAG, mastery lookup, exact solvers en vérification interne.

**Interdits.** Révéler immédiatement la solution si le mode socratique est actif, sauf demande explicite ou politique d'accessibilité.

**Modèle/coût.** EduSmall privilégié ; questions pré-générées/cache possibles.

**Tests.** Progression des indices, absence de boucle, détection de blocage, solution finale correcte.

---

## AIA-AGT-003 — ExplanationAgent

**Mission.** Reformuler une notion validée selon niveau, langue, style, accessibilité et difficulté.

**Sortie.** Explication courte/standard/détaillée, exemples et analogies clairement identifiées.

**Tools.** RAG, glossary, formula/math tools, accessibility formatter.

**Règle.** Ne transforme pas une analogie en fait scientifique. Ne change pas le sens d'une définition officielle.

**Mode dégradé.** Utiliser variantes éditoriales prévalidées.

---

## AIA-AGT-004 — ExerciseAgent

**Mission.** Générer ou transformer des exercices alignés sur compétences, difficulté, format et curriculum.

**Entrées.** Nombre, distribution de difficulté, types, compétences, source/course optionnel, contraintes d'examen.

**Sortie.** Liste d'objets structurés avec `statement`, `questions`, `answers`, `solution`, `hints`, `difficulty`, `skills`, `prerequisites`, `grading`, `metadata`.

**Tools.** RAG, SymPy/NumPy/SciPy, validators, duplicate detector, curriculum tools.

**Workflow.** Plan de lot — génération — résolution indépendante — validation — déduplication — classification difficulté — `waiting_review`.

**HITL.** Publication interdite sans workflow éditorial approprié.

**Admin.** Accepter/modifier/régénérer/rejeter exercice par exercice ; statistiques d'acceptation par version d'agent/modèle.

---

## AIA-AGT-005 — CorrectionAgent

**Mission.** Corriger une tentative à partir d'une solution/barème versionné et expliquer les erreurs.

**Tools.** Exact solvers, code runner, rubric engine, OCR/formula recognition si réponse photo.

**Règle.** Séparer `machine_score`, `confidence`, `feedback` et `official_grade`. Une note officielle nécessitant validation humaine ne peut être écrite directement.

**Sortie.** score proposé, étapes correctes/incorrectes, feedback, misconception candidates, confiance, besoin de revue.

---

## AIA-AGT-006 — RevisionAgent

**Mission.** Construire une séance de révision selon maîtrise, oubli estimé, échéances et temps disponible.

**Tools.** Student Model, spaced-repetition engine, Learning Orchestrator, content catalog.

**LLM.** Facultatif ; sélection mécanique déterministe possible.

**Sortie.** Plan ordonné d'activités avec raison de chaque choix.

---

## AIA-AGT-007 — ExamCoachAgent

**Mission.** Préparer aux BEPC, Probatoire, Baccalauréat, examens blancs et autres évaluations configurées.

**Tools.** Exam catalog, curriculum, mastery, timer/planning, past-paper RAG autorisé.

**Règles.** Ne prétend pas connaître une future épreuve confidentielle ; distingue entraînement, prédiction statistique et information officielle.

**Sortie.** plan, priorités, simulations, gestion du temps, lacunes, prochaines actions.

---

## AIA-AGT-008 — DiagnosticAgent

**Mission.** Estimer les compétences acquises/manquantes à partir de preuves diagnostiques.

**LLM.** Non obligatoire pour scoring ; règles/IRT/BKT ou moteur validé privilégiés.

**Sortie.** skill estimates + confidence + evidence IDs + next diagnostic action.

**Règle.** Diagnostic explicable, contestable, non-étiquetant.

---

## AIA-AGT-009 — MisconceptionAgent

**Mission.** Détecter des erreurs conceptuelles récurrentes et proposer une remédiation.

**Entrées.** Tentatives et erreurs pédagogiques nécessaires, pseudonymisées selon contexte.

**Sortie.** misconception candidate, confidence, evidence, remediation.

**Règle.** Une hypothèse n'est jamais stockée comme vérité définitive ; version/confidence obligatoires.

---

## AIA-AGT-010 — RecommendationAgent

**Mission.** Fournir des candidats/recommandations au Learning Orchestrator.

**LLM.** Optionnel. Le moteur déterministe doit fonctionner sans LLM.

**Sortie.** activités candidates, score, raisons, contraintes et alternatives.

**Interdit.** Contourner les droits d'abonnement, règles d'âge, fatigue, calendrier ou accessibilité.

---

## AIA-AGT-011 — GameContentAgent

**Mission.** Générer du contenu/configuration de serious games liés aux compétences.

**Sortie.** JSON conforme à un `GameTemplateEngine`, jamais du code Flutter arbitraire par défaut.

**Tools.** Curriculum, competency graph, game template registry, validators.

**Règles.** Score de jeu distinct de maîtrise ; transfert vers activité scolaire mesuré ; pas de dépendance IA temps réel obligatoire.

**HITL.** Validation pédagogique avant publication.

---

## AIA-AGT-012 — MusicLearningAgent

**Mission.** Transformer des objectifs pédagogiques en contenus musicaux mémorisables et activités de transfert.

**Formats.** Chanson mnémotechnique, rap éducatif, comptine, call-response, spoken word, rythme de formule/définition, vocabulaire/prononciation.

**Workflow.** Objectifs — paroles — validation factuelle/pédagogique — structure musicale — moteur audio autorisé — intelligibilité/prononciation — synchronisation — activité de transfert — validation — publication.

**Règles.** Réussite en chant —  maîtrise. Pas de contenu protégé sans licence ; pas de clonage vocal sans autorisation explicite ; enregistrements d'élèves privés par défaut.

---

## AIA-AGT-013 — LabAssistantAgent

**Mission.** Guider l'élève dans un laboratoire virtuel et expliquer les résultats d'un simulateur déterministe.

**Tools.** Selon matière : ngspice, RDKit/Open Babel, 3Dmol.js, SymPy/SciPy, OpenModelica ou simulateurs validés.

**Règle.** Le LLM n'invente pas les résultats physiques/chimiques ; le simulateur calcule, l'agent explique.

---

## AIA-AGT-014 — OCRAgent

**Mission.** Extraire texte, structure grossière et zones utiles de PDF/image/scan.

**Tools.** OpenCV preprocessing, PaddleOCR ou moteur validé.

**Sortie.** blocs OCR + coordonnées + confiance + langue + pages.

**Quota.** Peut être pondéré pour OCR serveur ; OCR local possible hors quota distant.

**Règle.** Le résultat OCR est une extraction candidate, pas une vérité publiée.

---

## AIA-AGT-015 — FormulaRecognitionAgent

**Mission.** Reconnaître formules imprimées/manuscrites et produire une représentation structurée (LaTeX/AST) vérifiable.

**Tools.** Formula recognition engine, parser, SymPy.

**Sortie.** formule, confidence, parse status, semantic validation.

**Règle.** Toute formule utilisée pour correction/calcul doit être parsée/validée ou envoyée en revue.

---

## AIA-AGT-016 — DocumentStructuringAgent

**Mission.** Transformer une source importée en Structured Content compatible Content Factory.

**Entrées.** OCR/text extraction, styles, images, tableaux, formules, metadata.

**Sortie.** chapitres/leçons/blocs structurés, ordre, types de blocs, assets, confidence, ambiguïtés.

**Tools.** Pedagogical Catalog, template schemas, OCR/formula agents, validators.

**Règle.** Ne publie jamais. Conserve la traçabilité source — bloc.

---

## AIA-AGT-017 — CurriculumMappingAgent

**Mission.** Proposer le rattachement d'un contenu aux pays/versions/classes/séries/matières/chapitres/leçons/compétences.

**Tools.** Curriculum Graph, semantic search, taxonomy matcher.

**Sortie.** mappings candidats + confidence + evidence.

**HITL.** Mapping ambigu ou à fort impact soumis au responsable pédagogique.

---

## AIA-AGT-018 — TeacherAssistantAgent

**Mission.** Aider enseignants/auteurs à préparer cours, exercices, corrections, plans, feedbacks et analyses de cohorte dans leur scope.

**Tools.** Content Factory, Exercise Factory, cohort analytics, RAG, generators.

**Règles.** Respect strict du scope enseignant ; pas d'accès global aux élèves ; toute publication suit workflow.

---

## AIA-AGT-019 — ParentInsightAgent

**Mission.** Transformer les données autorisées d'un enfant lié en synthèse claire et actionnable.

**Sortie.** progrès, forces, points à travailler, recommandations de soutien, alertes autorisées.

**Règles.** Pas de surveillance punitive ; pas d'accès aux conversations/données privées non autorisées ; langage compréhensible et non stigmatisant.

**LLM.** Résumés peuvent être pré-calculés ; données source déterministes.

---

## AIA-AGT-020 — ModerationAgent

**Mission.** Détecter et prioriser contenus communautaires potentiellement contraires aux règles.

**Sortie.** labels, severity, confidence, recommended action.

**Règle.** Le modèle ne prononce pas automatiquement une sanction lourde. Human review selon seuil/politique. Conserver appels et audit.

---

## AIA-AGT-021 — AdminAssistantAgent

**Mission.** Aider un administrateur à comprendre l'état de la plateforme, naviguer dans les données autorisées et préparer des actions.

**Tools.** Read-only analytics par défaut, search admin docs, job status, configuration readers.

**Interdits.** SQL arbitraire, modification RLS directe, remboursement/publication/suppression massive sans service métier + confirmation/validation.

**Règle.** Toute action mutante doit être présentée explicitement avant exécution et passer par permission + audit.

---

## AIA-AGT-022 — SupportTriageAgent

**Mission.** Classer demandes support, détecter urgence, rechercher solutions documentées, router vers la bonne équipe.

**Sortie.** category, priority, suggested response, routing target, required context.

**Règle.** Minimisation des données ; pas de demande de secrets ; aucune action sensible sans procédure support autorisée.

---

## AIA-AGT-023 — TranslationAgent

**Mission.** Traduire interfaces/contenus autorisés en conservant sens pédagogique, terminologie et formules.

**Tools.** Glossaire versionné, translation memory, RAG terminologique.

**Règle.** Une traduction de contenu pédagogique publiée est versionnée et validée selon workflow. Ne traduit pas aveuglément noms propres, symboles ou terminologie officielle.

---

## AIA-AGT-024 — PedagogicalValidationAgent

**Mission.** Précontrôler exactitude, alignement curriculum, niveau, structure, accessibilité, citations, sécurité et cohérence d'un contenu.

**Sortie.** checklist, errors, warnings, confidence, blocking issues, suggested fixes.

**Règle.** C'est un pré-validateur ; la publication humaine reste requise lorsque le workflow l'exige.

**Tools.** Curriculum, RAG, exact solvers, schema validators, accessibility checks, duplicate/plagiarism-like internal checks selon droits.

---

## AIA-AGT-025 — FraudRiskAgent

**Mission.** Produire des signaux de risque sur paiements, examens, comptes, promotions ou usages anormaux.

**Sortie.** risk signals + evidence + confidence + recommended review.

**Règle.** Signal —  preuve. Pas de sanction automatique lourde sur seul score IA. Features sensibles limitées, explicabilité et audit obligatoires.

---

## AIA-AGT-026 — InfrastructureOpsAgent

**Mission.** Observer jobs, modèles, nœuds Compute Fabric, files d'attente, erreurs et capacité ; proposer ou exécuter uniquement les opérations techniques explicitement autorisées.

**Tools.** Metrics/log readers, health checks, deployment status, queue controls, feature flags selon permission.

**Interdits par défaut.** Shell arbitraire en production, secrets, destruction de données, modification RLS, suppression de backups.

**HITL.** Rollback, déploiement, scaling coûteux ou action destructive selon politique d'approbation.

---

# 8. AGENTS ET CONTENT FACTORY ADMIN

Le côté Admin doit permettre trois origines équivalentes de contenu :

```text
MANUEL        IMPORT/UPLOAD        GÉNÉRATION IA
   \               |                  /
    +--------------+-----------------+
                   |
             STRUCTURED CONTENT
                   |
           PEDAGOGICAL CATALOG
                   |
            TEMPLATE/RENDERER
                   |
               PREVIEW
                   |
             HUMAN REVIEW
                   |
              VERSIONING
                   |
               PUBLISH
          /          |          \
       APP          PDF       OFFLINE
```

Un cours uploadé n'est donc pas affiché comme un simple PDF. Il devient une **source** : extraction — OCR/formules — structuration — mapping curriculum/catalogue — validation — Structured Content — templates configurés — preview — validation humaine — publication.

Un exercice importé suit la même philosophie : détection énoncé/questions/sous-questions/figures/barème/réponses/correction — structure d'exercice — renderer configuré — validation.

---

# 9. ADMIN AI CONTROL PLANE

L'Administration Flutter doit exposer progressivement :

- **ADM-AI-001 Agent Registry** : 26 agents, statut, version, propriétaire, permissions, déploiement.
- **ADM-AI-002 Agent Detail** : mission, tools, prompts, RAG, modèles, quotas, métriques, tests.
- **ADM-AI-003 Prompt Registry** : prompts versionnés, diff, statut draft/candidate/production/retired, rollback.
- **ADM-AI-004 Tool Registry** : schémas, permissions, timeout, rate limit, environnements.
- **ADM-AI-005 Model Registry** : modèle, licence, taille, quantization, benchmark, matériel, contexte, langues.
- **ADM-AI-006 Model Deployments** : device/server, version, canary, rollback.
- **ADM-AI-007 RAG Sources** : sources, licences, scopes, versions, ingestion, chunks, index.
- **ADM-AI-008 RAG Quality** : recall tests, citation quality, stale sources, retrieval failures.
- **ADM-AI-009 Evaluation Center** : datasets, suites, factuality, safety, pedagogy, latency, resource use.
- **ADM-AI-010 Model Factory** : datasets autorisés, training runs, LoRA/adapters, evaluations, quantization.
- **ADM-AI-011 Compute Fabric** : nodes, CPU/GPU/RAM/VRAM, availability, trust, queue, utilization.
- **ADM-AI-012 Jobs** : OCR, RAG, génération, training, PDF, audio, jeux ; cancel/retry selon droits.
- **ADM-AI-013 Quotas & Entitlements** : policies par offre, compute units, reset, priority, concurrency, bonus.
- **ADM-AI-014 Usage Ledger** : consommation append-only et réconciliation.
- **ADM-AI-015 AI Cost Dashboard** : coût physique estimé, temps GPU/CPU, cache hit, device offload, coût par activité.
- **ADM-AI-016 Agent Analytics** : acceptance/rejection/edit rate, latency, failures, fallback.
- **ADM-AI-017 Safety & Incidents** : flags, escalations, incident timeline, mitigations.
- **ADM-AI-018 Feature Flags** : activation par pays/role/plan/version/device.
- **ADM-AI-019 Audit & Rollback** : historique des changements IA.
- **ADM-AI-020 Learning Orchestrator Policies** et **Mastery Engine Parameters** avec versioning et simulation avant publication.

Les rôles Admin IA, infrastructure, sécurité, contenu et pédagogie doivent être distincts. `is_admin=true` ne suffit pas.

---

# 10. RAG

Pipeline :

```text
SOURCE VALIDÉE
 -> ingestion versionnée
 -> nettoyage
 -> segmentation structure-aware
 -> metadata curriculum/permission/version
 -> embeddings locaux
 -> pgvector par défaut
 -> retrieval filtré
 -> reranking local si utile
 -> citations
 -> retrieval logs
```

Règles :
- documents non fiables isolés ;
- défense contre prompt injection documentaire ;
- aucun chunk d'un autre scope/profil ;
- retrait d'une source propagé à l'index ;
- citation liée à version/source ;
- réindexation contrôlée et observable.

---

# 11. MÉMOIRE

Trois niveaux :

1. **conversation courte** : contexte temporaire minimal ;
2. **mémoire pédagogique structurée** : Student Model, maîtrise, misconceptions, préférences autorisées ;
3. **préférences explicites** : langue, accessibilité, formats.

Interdit : mémoire brute illimitée par défaut, mélange entre profils, conservation sans politique, transformation d'une inférence fragile en attribut permanent.

---

# 12. TOOLS

Catégories initiales :

- curriculum/competency tools ;
- content/RAG tools ;
- Student Model/mastery tools ;
- SymPy/NumPy/SciPy ;
- OCR/vision/formula tools ;
- code execution sandbox ;
- game/music/lab engines ;
- workflow/content draft tools ;
- analytics read tools ;
- support/admin controlled tools.

Chaque tool possède JSON Schema, permissions, scope, timeout, idempotence, journalisation, limites et tests.

---

# 13. MODEL FACTORY

Ne pas entraîner un foundation model depuis zéro par défaut.

Pipeline cible :

```text
OPEN-WEIGHT BASE MODEL
 -> DATASET FACTORY
 -> LoRA / QLoRA / PEFT
 -> EVALUATION
 -> QUANTIZATION
 -> DEVICE/SERVER ARTIFACT
 -> CANARY
 -> PRODUCTION
 -> MONITORING
 -> ROLLBACK
```

Fine-tuning apprend surtout **comment** l'agent travaille ; RAG apporte **quoi** consulter.

Datasets possibles uniquement avec droits et gouvernance : curriculum officiel, cours validés, sujets/corrections autorisés, erreurs fréquentes, méthodes pédagogiques validées, exemples de tool calling.

---

# 14. COMPUTE FABRIC

Sources de compute possibles : machine développeur, serveur propre, établissement, université/partenaire, association/sponsor, nœud école, capacité gratuite opportuniste.

Une ressource gratuite externe n'est jamais une dépendance de production garantie.

Chaque nœud déclare : identité, trust level, hardware, modèles autorisés, disponibilité, queue, métriques, politique de données. Les données personnelles sensibles ne sont pas envoyées vers un nœud non approuvé.

---

# 15. OBSERVABILITÉ

Pour chaque run : request/trace ID, agent/version, route, model/version, tools, durée, retries, cache, compute units, quota decision, error class, validation result, safety flags et résultat métier minimal pseudonymisé.

Ne jamais mettre secrets, tokens, PIN, données brutes sensibles ou contenu privé inutile dans les logs.

Métriques : latency p50/p95/p99, success/fallback/error, cache hit, device offload, GPU/CPU time, acceptance/edit/rejection, factuality, citation quality, tool accuracy, coût physique estimé.

---

# 16. ÉVALUATION AVANT PRODUCTION

Aucune nouvelle version de modèle/prompt/agent ne passe en production sans suite d'évaluation pertinente :

- exactitude/factualité ;
- alignement curriculum ;
- niveau pédagogique ;
- citations ;
- tool calling ;
- sécurité mineurs ;
- confidentialité ;
- biais ;
- hallucination ;
- robustesse aux prompt injections ;
- latence ;
- RAM/VRAM ;
- consommation ;
- comportement offline/dégradé.

Comparaison obligatoire à la version actuellement en production et seuils configurables.

---

# 17. DONNÉES IA — MODÈLE CONCEPTUEL

Avant création, auditer les tables Supabase existantes. Entités cibles possibles :

```text
ai_agents
ai_agent_versions
ai_prompts
ai_prompt_versions
ai_tools
ai_agent_tools
ai_models
ai_model_deployments
ai_runs
ai_tool_calls
ai_rag_sources
ai_rag_ingestions
ai_rag_chunks
ai_evaluations
ai_eval_runs
ai_cache_entries
ai_policies
ai_entitlements
ai_usage_ledger
ai_compute_nodes
ai_compute_jobs
ai_training_datasets
ai_training_runs
ai_adapters
ai_incidents
```

Principes : UUID/ULID, UTC, FKs explicites, RLS/ABAC, audit append-only pour usages sensibles, idempotence, séparation PII/analytics, chiffrement, versioning, soft-delete sélectif.

---

# 18. WORKFLOW D'UN RUN IA

```text
REQUEST
 -> AuthN/AuthZ
 -> Academic/Profile Context
 -> Entitlement check
 -> Local/cache/deterministic decision
 -> Agent selection
 -> RAG context
 -> Tool plan
 -> Model route si nécessaire
 -> Structured output validation
 -> Safety/pedagogical validation
 -> Business service / HITL si effet métier
 -> Response
 -> Usage ledger
 -> Metrics/evaluation sample
```

---

# 19. ERREURS ET FALLBACK

Codes métier recommandés : `AGENT_UNAVAILABLE`, `MODEL_UNAVAILABLE`, `QUOTA_EXHAUSTED`, `RAG_EMPTY`, `TOOL_FAILED`, `OUTPUT_INVALID`, `PERMISSION_DENIED`, `HUMAN_REVIEW_REQUIRED`, `OFFLINE_LIMITATION`, `CONTENT_VERSION_CONFLICT`.

Un échec de modèle ne doit pas devenir automatiquement une erreur générale. Le router tente, selon politique : cache — local — modèle alternatif — queue — mode dégradé.

---

# 20. SÉCURITÉ DES MINEURS

- minimisation stricte ;
- scope parent/enseignant explicite ;
- consentements versionnés ;
- voix/images selon politique ;
- pas de profilage opaque à fort impact ;
- pas de sanctions automatiques lourdes ;
- signalement/escalade selon règles validées ;
- contenus générés pour mineurs soumis aux contrôles appropriés ;
- export/suppression/contestation selon politique de données.

---

# 21. TESTS OBLIGATOIRES PAR AGENT

Chaque agent possède au minimum :

1. happy path ;
2. permission denied ;
3. mauvais scope ;
4. RAG vide ;
5. tool timeout ;
6. modèle indisponible ;
7. quota épuisé ;
8. sortie JSON invalide ;
9. offline/degraded ;
10. prompt injection ;
11. données d'un autre profil ;
12. version rollback ;
13. benchmark coût/latence ;
14. critères pédagogiques spécifiques.

---

# 22. ORDRE D'IMPLÉMENTATION POUR CLAUDE CODE

Ne pas implémenter les 26 agents simultanément.

### IA-000 — Audit
Inspecter code, DB, services IA existants, dépendances, secrets/configs, RLS, queues, offline, Content Factory.

### IA-001 — Contracts
Créer interfaces/envelopes, registry, typed errors, capability model, tool contracts.

### IA-002 — Gateway minimal
Auth, permissions, request IDs, structured validation, observability.

### IA-003 — Tool Gateway
Curriculum/content/RAG/math tools, sans accès SQL arbitraire.

### IA-004 — RAG minimal
Sources validées, ingestion, pgvector, filtres, citations.

### IA-005 — Model Router
Provider abstraction + local provider par défaut.

### IA-006 — Quota Engine
Policies, entitlements, weighted compute units, ledger, fallback.

### IA-007 — Premier vertical slice
`TutorAgent` sur une matière/leçon test avec RAG + math tool + Student Model read + cache + quota + observabilité.

### IA-008 — Content Factory agents
OCRAgent — FormulaRecognitionAgent — DocumentStructuringAgent — CurriculumMappingAgent — PedagogicalValidationAgent.

### IA-009 — Exercise vertical slice
ExerciseAgent + CorrectionAgent + validation humaine.

### IA-010 — Learning intelligence
DiagnosticAgent, MisconceptionAgent, RevisionAgent, RecommendationAgent, SocraticAgent, ExplanationAgent, ExamCoachAgent.

### IA-011 — Multimodal factories
GameContentAgent, MusicLearningAgent, LabAssistantAgent.

### IA-012 — Staff/family
TeacherAssistantAgent, ParentInsightAgent, TranslationAgent.

### IA-013 — Operations
ModerationAgent, AdminAssistantAgent, SupportTriageAgent, FraudRiskAgent, InfrastructureOpsAgent.

### IA-014 — Model Factory / Compute Fabric
Seulement après benchmarks et besoins observés.

---

# 23. CRITÈRES DE DONE D'UN AGENT

Un agent n'est pas « terminé » parce qu'un prompt répond dans une console. Il est Done seulement si : contrat versionné, permissions, tools, RAG, route modèle, quota, cache, erreurs, mode dégradé, observabilité, tests, évaluation, Admin visibility, documentation, sécurité et rollback sont opérationnels pour son périmètre.

---

# 24. RÈGLE DE NON-RÉGRESSION POUR VIBE CODING

Claude Code/Antigravity doit toujours commencer un work package par l'inspection du code réel. Pour chaque modification : `EXISTING -> TARGET -> GAP -> MIGRATION -> TEST`. Ne jamais recréer une table/route/service en doublon. Ne jamais supprimer une fonctionnalité compatible. Toute migration destructive exige analyse, sauvegarde/rollback et validation.

---

# 25. RÈGLE D'OR

L'objectif n'est pas d'afficher « IA » partout. L'objectif est que l'intelligence soit **utile, mesurable, sûre, économiquement contrôlable, souveraine, compatible offline et intégrée au moteur pédagogique**.

Un bon agent EDLEARN est celui qui utilise le moins de compute nécessaire pour produire un résultat pédagogique correct, vérifiable et adapté à l'élève.
