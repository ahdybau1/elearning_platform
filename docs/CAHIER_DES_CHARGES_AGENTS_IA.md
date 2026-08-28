# CAHIER DES CHARGES â AGENTS IA EDLEARN

**Plateforme E-learning Cameroun â CollÃ¨ge et LycÃ©e**  
**Version : 1.0 consolidÃ©e â 28 aoÃ»t 2026**  
**Statut : spÃ©cification technique et fonctionnelle pour vibe coding**

> Ce document complÃ¨te le cahier maÃ®tre. Il ne remplace aucune exigence du cahier principal. En cas de conflit, les dÃ©cisions fermes les plus rÃ©centes validÃ©es par le porteur du projet, puis le cahier maÃ®tre mis Ã  jour, priment.

---

## 1. Objet

Ce document spÃ©cifie la couche d'agents IA de la plateforme : responsabilitÃ©s, frontiÃ¨res, donnÃ©es, outils, RAG, modÃ¨les, quotas, sÃ©curitÃ©, observabilitÃ©, modes dÃ©gradÃ©s, tests et administration.

L'objectif n'est pas de crÃ©er 26 chatbots indÃ©pendants. Un **agent** est un workflow mÃ©tier spÃ©cialisÃ© qui combine, selon le besoin : rÃ¨gles dÃ©terministes, RAG, Student Model, Competency Graph, outils typÃ©s, cache, modÃ¨les locaux/on-device/serveur, validation humaine et journalisation.

Principe directeur :

> **Le LLM comprend, raisonne, explique, crÃ©e et orchestre ; les bibliothÃ¨ques spÃ©cialisÃ©es calculent, exÃ©cutent, rendent, simulent et stockent.**

---

## 2. Contraintes absolues

1. Aucune API IA commerciale payante n'est une dÃ©pendance obligatoire.
2. Les modÃ¨les sont interchangeables via un Model Provider/Router.
3. Aucun agent n'obtient un accÃ¨s SQL gÃ©nÃ©rique Ã  toute la base.
4. Les outils sont allowlistÃ©s, typÃ©s, autorisÃ©s par contexte et auditÃ©s.
5. Toute sortie structurÃ©e est validÃ©e avant effet mÃ©tier.
6. Publication pÃ©dagogique, notes officielles, sanctions, remboursements et actions financiÃ¨res passent par les services mÃ©tier et les validations requises.
7. Les fonctions pÃ©dagogiques essentielles disposent d'un mode sans LLM lorsque techniquement pertinent.
8. Les contenus destinÃ©s aux mineurs suivent les rÃ¨gles de validation humaine du cahier maÃ®tre.
9. Les quotas protÃ¨gent principalement le **compute distant/gÃ©nÃ©ratif coÃ»teux** ; ils ne doivent pas artificiellement bloquer les moteurs dÃ©terministes, le cache ou les contenus dÃ©jÃ  publiÃ©s.
10. Les valeurs numÃ©riques de quotas ne sont pas codÃ©es en dur avant benchmark rÃ©el.

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

**Local Orchestrator Flutter/Dart** : dÃ©cide si la demande peut Ãªtre rÃ©solue par cache, contenu validÃ©, outil local, RAG local ou modÃ¨le on-device.

**Sovereign AI Gateway** : prend en charge les workflows serveur, RAG global, modÃ¨les plus lourds, queues, Compute Fabric, Ã©valuations et politiques centralisÃ©es.

---

## 4. Contrat standard de tout agent

Chaque agent DOIT dÃ©clarer :

- `agent_id`, `name`, `version`, `status` ;
- mission et non-mission ;
- acteurs autorisÃ©s et scopes ;
- triggers ;
- schÃ©ma JSON d'entrÃ©e et de sortie ;
- donnÃ©es lisibles et donnÃ©es modifiables ;
- tools autorisÃ©s/interdits ;
- politique RAG ;
- politique mÃ©moire ;
- politique modÃ¨le ;
- classe de coÃ»t/quota ;
- timeout, retry, cache et idempotence ;
- mode offline/dÃ©gradÃ© ;
- validations automatiques ;
- Human-In-The-Loop ;
- mÃ©triques ;
- tests ;
- rollback/versioning.

### 4.1 Envelope d'entrÃ©e commun

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

## 5. Routage, modÃ¨les et coÃ»ts

Ordre prÃ©fÃ©rÃ© :

```text
1. rÃ¨gles / moteur dÃ©terministe
2. cache / contenu validÃ©
3. Device AI
4. Device AI + RAG + tools
5. Compute Fabric souverain
6. capacitÃ© externe gratuite autorisÃ©e
7. provider payant optionnel, dÃ©sactivÃ© en AI_ZERO_COST_MODE
```

Les agents ne choisissent pas directement un fournisseur. Ils demandent une **capability** : `classification_small`, `pedagogy_small`, `reasoning_strong`, `vision_ocr`, `embedding`, etc. Le Model Router choisit le moteur autorisÃ©.

### 5.1 Trois cerveaux logiques

- **EduRouter** : petit modÃ¨le/classifieur pour intention, routage, tool calling simple.
- **EduSmall** : modÃ¨le pÃ©dagogique local/on-device ou serveur lÃ©ger pour tutorat courant.
- **EduStrong** : modÃ¨le plus puissant pour tÃ¢ches complexes, uniquement si nÃ©cessaire.

Les 26 agents logiques peuvent partager ces modÃ¨les, prompts, tools et adapters. Il est interdit de crÃ©er 26 gros modÃ¨les sÃ©parÃ©s par dÃ©faut.

---

## 6. Entitlements, quotas et AI Compute Credits

Le droit d'abonnement et le droit IA sont deux concepts distincts.

```text
SUBSCRIPTION -> AI POLICY -> ALLOWANCES / PRIORITY / MODEL TIER / CONCURRENCY
```

L'Admin doit pouvoir dÃ©finir des politiques pour FREE, DAY_PASS, WEEKLY, MONTHLY, PREMIUM, SCHOOL ou futures offres.

Une action IA reÃ§oit un poids de compute calculÃ© Ã  partir de mÃ©triques observables : modÃ¨le, tokens, durÃ©e GPU/CPU, OCR, vision, audio, gÃ©nÃ©ration, taille de contexte, etc. Les valeurs finales sont dÃ©terminÃ©es par benchmark, jamais inventÃ©es dans le code.

Ã quota distant Ã©puisÃ© : basculer vers cache, contenu validÃ©, outil dÃ©terministe, Device AI, modÃ¨le plus lÃ©ger, queue diffÃ©rÃ©e ou message utile. Les cours, exercices existants, examens, jeux publiÃ©s, musiques publiÃ©es, labs dÃ©terministes et offline restent accessibles selon les droits pÃ©dagogiques du plan.

---

# 7. CATALOGUE OFFICIEL DES 26 AGENTS

## AIA-AGT-001 â TutorAgent

**Mission.** Tutorat conversationnel personnalisÃ©, contextualisÃ© par curriculum, Student Model et contenus validÃ©s. Explique, questionne, donne des indices et adapte la profondeur.

**Non-mission.** Ne modifie pas une note officielle, ne publie pas de contenu, ne remplace pas un enseignant dans une dÃ©cision sensible, ne calcule pas approximativement lorsqu'un moteur exact existe.

**EntrÃ©es mÃ©tier.** Question, contexte acadÃ©mique, compÃ©tence ciblÃ©e, historique conversationnel court, maÃ®trise/confidence, prÃ©fÃ©rences d'accessibilitÃ©.

**Sortie.** RÃ©ponse pÃ©dagogique structurÃ©e : `answer`, `steps`, `hints`, `check_for_understanding`, `recommended_next_action`, citations.

**Tools.** `search_validated_content`, `get_skill_context`, `get_student_mastery`, `sympy_solve`, `numeric_compute`, `get_formula`, `get_example`, `create_learning_event`.

**RAG.** Curriculum et contenus publiÃ©s du scope actif uniquement. Citations obligatoires pour les faits pÃ©dagogiques rÃ©cupÃ©rÃ©s.

**MÃ©moire.** MÃ©moire conversationnelle courte + Student Model structurÃ© ; pas de stockage illimitÃ© du chat brut.

**ModÃ¨le.** Cache/dÃ©terministe si possible â EduSmall â EduStrong pour difficultÃ© justifiÃ©e.

**Quota.** Cache/tools/local gÃ©nÃ©ralement 0 remote credits ; infÃ©rence distante pondÃ©rÃ©e.

**Workflow.** Classifier intention â rÃ©cupÃ©rer contexte â rechercher sources â choisir tools â produire rÃ©ponse â vÃ©rifier niveau/factualitÃ© â proposer mini-vÃ©rification â journaliser preuve utile.

**HITL.** Escalade vers enseignant/support selon rÃ¨gles de sÃ©curitÃ© ou impossibilitÃ© pÃ©dagogique.

**CritÃ¨res d'acceptation.** Ne fuit aucun autre profil ; respecte niveau/classe ; cite le RAG ; utilise le moteur exact pour calculs ; mode dÃ©gradÃ© utile ; latence et coÃ»t observables.

---

## AIA-AGT-002 â SocraticAgent

**Mission.** Faire progresser l'Ã©lÃ¨ve par questions graduÃ©es plutÃ´t que donner immÃ©diatement la solution.

**EntrÃ©es.** ProblÃ¨me, tentative de l'Ã©lÃ¨ve, compÃ©tence, niveau de maÃ®trise, nombre d'indices dÃ©jÃ  consommÃ©s.

**Sortie.** `next_question`, `hint_level`, `diagnostic_signal`, `stop_condition`.

**Tools.** RAG, mastery lookup, exact solvers en vÃ©rification interne.

**Interdits.** RÃ©vÃ©ler immÃ©diatement la solution si le mode socratique est actif, sauf demande explicite ou politique d'accessibilitÃ©.

**ModÃ¨le/coÃ»t.** EduSmall privilÃ©giÃ© ; questions prÃ©-gÃ©nÃ©rÃ©es/cache possibles.

**Tests.** Progression des indices, absence de boucle, dÃ©tection de blocage, solution finale correcte.

---

## AIA-AGT-003 â ExplanationAgent

**Mission.** Reformuler une notion validÃ©e selon niveau, langue, style, accessibilitÃ© et difficultÃ©.

**Sortie.** Explication courte/standard/dÃ©taillÃ©e, exemples et analogies clairement identifiÃ©es.

**Tools.** RAG, glossary, formula/math tools, accessibility formatter.

**RÃ¨gle.** Ne transforme pas une analogie en fait scientifique. Ne change pas le sens d'une dÃ©finition officielle.

**Mode dÃ©gradÃ©.** Utiliser variantes Ã©ditoriales prÃ©validÃ©es.

---

## AIA-AGT-004 â ExerciseAgent

**Mission.** GÃ©nÃ©rer ou transformer des exercices alignÃ©s sur compÃ©tences, difficultÃ©, format et curriculum.

**EntrÃ©es.** Nombre, distribution de difficultÃ©, types, compÃ©tences, source/course optionnel, contraintes d'examen.

**Sortie.** Liste d'objets structurÃ©s avec `statement`, `questions`, `answers`, `solution`, `hints`, `difficulty`, `skills`, `prerequisites`, `grading`, `metadata`.

**Tools.** RAG, SymPy/NumPy/SciPy, validators, duplicate detector, curriculum tools.

**Workflow.** Plan de lot â gÃ©nÃ©ration â rÃ©solution indÃ©pendante â validation â dÃ©duplication â classification difficultÃ© â `waiting_review`.

**HITL.** Publication interdite sans workflow Ã©ditorial appropriÃ©.

**Admin.** Accepter/modifier/rÃ©gÃ©nÃ©rer/rejeter exercice par exercice ; statistiques d'acceptation par version d'agent/modÃ¨le.

---

## AIA-AGT-005 â CorrectionAgent

**Mission.** Corriger une tentative Ã  partir d'une solution/barÃ¨me versionnÃ© et expliquer les erreurs.

**Tools.** Exact solvers, code runner, rubric engine, OCR/formula recognition si rÃ©ponse photo.

**RÃ¨gle.** SÃ©parer `machine_score`, `confidence`, `feedback` et `official_grade`. Une note officielle nÃ©cessitant validation humaine ne peut Ãªtre Ã©crite directement.

**Sortie.** score proposÃ©, Ã©tapes correctes/incorrectes, feedback, misconception candidates, confiance, besoin de revue.

---

## AIA-AGT-006 â RevisionAgent

**Mission.** Construire une sÃ©ance de rÃ©vision selon maÃ®trise, oubli estimÃ©, Ã©chÃ©ances et temps disponible.

**Tools.** Student Model, spaced-repetition engine, Learning Orchestrator, content catalog.

**LLM.** Facultatif ; sÃ©lection mÃ©canique dÃ©terministe possible.

**Sortie.** Plan ordonnÃ© d'activitÃ©s avec raison de chaque choix.

---

## AIA-AGT-007 â ExamCoachAgent

**Mission.** PrÃ©parer aux BEPC, Probatoire, BaccalaurÃ©at, examens blancs et autres Ã©valuations configurÃ©es.

**Tools.** Exam catalog, curriculum, mastery, timer/planning, past-paper RAG autorisÃ©.

**RÃ¨gles.** Ne prÃ©tend pas connaÃ®tre une future Ã©preuve confidentielle ; distingue entraÃ®nement, prÃ©diction statistique et information officielle.

**Sortie.** plan, prioritÃ©s, simulations, gestion du temps, lacunes, prochaines actions.

---

## AIA-AGT-008 â DiagnosticAgent

**Mission.** Estimer les compÃ©tences acquises/manquantes Ã  partir de preuves diagnostiques.

**LLM.** Non obligatoire pour scoring ; rÃ¨gles/IRT/BKT ou moteur validÃ© privilÃ©giÃ©s.

**Sortie.** skill estimates + confidence + evidence IDs + next diagnostic action.

**RÃ¨gle.** Diagnostic explicable, contestable, non-Ã©tiquetant.

---

## AIA-AGT-009 â MisconceptionAgent

**Mission.** DÃ©tecter des erreurs conceptuelles rÃ©currentes et proposer une remÃ©diation.

**EntrÃ©es.** Tentatives et erreurs pÃ©dagogiques nÃ©cessaires, pseudonymisÃ©es selon contexte.

**Sortie.** misconception candidate, confidence, evidence, remediation.

**RÃ¨gle.** Une hypothÃ¨se n'est jamais stockÃ©e comme vÃ©ritÃ© dÃ©finitive ; version/confidence obligatoires.

---

## AIA-AGT-010 â RecommendationAgent

**Mission.** Fournir des candidats/recommandations au Learning Orchestrator.

**LLM.** Optionnel. Le moteur dÃ©terministe doit fonctionner sans LLM.

**Sortie.** activitÃ©s candidates, score, raisons, contraintes et alternatives.

**Interdit.** Contourner les droits d'abonnement, rÃ¨gles d'Ã¢ge, fatigue, calendrier ou accessibilitÃ©.

---

## AIA-AGT-011 â GameContentAgent

**Mission.** GÃ©nÃ©rer du contenu/configuration de serious games liÃ©s aux compÃ©tences.

**Sortie.** JSON conforme Ã  un `GameTemplateEngine`, jamais du code Flutter arbitraire par dÃ©faut.

**Tools.** Curriculum, competency graph, game template registry, validators.

**RÃ¨gles.** Score de jeu distinct de maÃ®trise ; transfert vers activitÃ© scolaire mesurÃ© ; pas de dÃ©pendance IA temps rÃ©el obligatoire.

**HITL.** Validation pÃ©dagogique avant publication.

---

## AIA-AGT-012 â MusicLearningAgent

**Mission.** Transformer des objectifs pÃ©dagogiques en contenus musicaux mÃ©morisables et activitÃ©s de transfert.

**Formats.** Chanson mnÃ©motechnique, rap Ã©ducatif, comptine, call-response, spoken word, rythme de formule/dÃ©finition, vocabulaire/prononciation.

**Workflow.** Objectifs â paroles â validation factuelle/pÃ©dagogique â structure musicale â moteur audio autorisÃ© â intelligibilitÃ©/prononciation â synchronisation â activitÃ© de transfert â validation â publication.

**RÃ¨gles.** RÃ©ussite en chant â  maÃ®trise. Pas de contenu protÃ©gÃ© sans licence ; pas de clonage vocal sans autorisation explicite ; enregistrements d'Ã©lÃ¨ves privÃ©s par dÃ©faut.

---

## AIA-AGT-013 â LabAssistantAgent

**Mission.** Guider l'Ã©lÃ¨ve dans un laboratoire virtuel et expliquer les rÃ©sultats d'un simulateur dÃ©terministe.

**Tools.** Selon matiÃ¨re : ngspice, RDKit/Open Babel, 3Dmol.js, SymPy/SciPy, OpenModelica ou simulateurs validÃ©s.

**RÃ¨gle.** Le LLM n'invente pas les rÃ©sultats physiques/chimiques ; le simulateur calcule, l'agent explique.

---

## AIA-AGT-014 â OCRAgent

**Mission.** Extraire texte, structure grossiÃ¨re et zones utiles de PDF/image/scan.

**Tools.** OpenCV preprocessing, PaddleOCR ou moteur validÃ©.

**Sortie.** blocs OCR + coordonnÃ©es + confiance + langue + pages.

**Quota.** Peut Ãªtre pondÃ©rÃ© pour OCR serveur ; OCR local possible hors quota distant.

**RÃ¨gle.** Le rÃ©sultat OCR est une extraction candidate, pas une vÃ©ritÃ© publiÃ©e.

---

## AIA-AGT-015 â FormulaRecognitionAgent

**Mission.** ReconnaÃ®tre formules imprimÃ©es/manuscrites et produire une reprÃ©sentation structurÃ©e (LaTeX/AST) vÃ©rifiable.

**Tools.** Formula recognition engine, parser, SymPy.

**Sortie.** formule, confidence, parse status, semantic validation.

**RÃ¨gle.** Toute formule utilisÃ©e pour correction/calcul doit Ãªtre parsÃ©e/validÃ©e ou envoyÃ©e en revue.

---

## AIA-AGT-016 â DocumentStructuringAgent

**Mission.** Transformer une source importÃ©e en Structured Content compatible Content Factory.

**EntrÃ©es.** OCR/text extraction, styles, images, tableaux, formules, metadata.

**Sortie.** chapitres/leÃ§ons/blocs structurÃ©s, ordre, types de blocs, assets, confidence, ambiguÃ¯tÃ©s.

**Tools.** Pedagogical Catalog, template schemas, OCR/formula agents, validators.

**RÃ¨gle.** Ne publie jamais. Conserve la traÃ§abilitÃ© source â bloc.

---

## AIA-AGT-017 â CurriculumMappingAgent

**Mission.** Proposer le rattachement d'un contenu aux pays/versions/classes/sÃ©ries/matiÃ¨res/chapitres/leÃ§ons/compÃ©tences.

**Tools.** Curriculum Graph, semantic search, taxonomy matcher.

**Sortie.** mappings candidats + confidence + evidence.

**HITL.** Mapping ambigu ou Ã  fort impact soumis au responsable pÃ©dagogique.

---

## AIA-AGT-018 â TeacherAssistantAgent

**Mission.** Aider enseignants/auteurs Ã  prÃ©parer cours, exercices, corrections, plans, feedbacks et analyses de cohorte dans leur scope.

**Tools.** Content Factory, Exercise Factory, cohort analytics, RAG, generators.

**RÃ¨gles.** Respect strict du scope enseignant ; pas d'accÃ¨s global aux Ã©lÃ¨ves ; toute publication suit workflow.

---

## AIA-AGT-019 â ParentInsightAgent

**Mission.** Transformer les donnÃ©es autorisÃ©es d'un enfant liÃ© en synthÃ¨se claire et actionnable.

**Sortie.** progrÃ¨s, forces, points Ã  travailler, recommandations de soutien, alertes autorisÃ©es.

**RÃ¨gles.** Pas de surveillance punitive ; pas d'accÃ¨s aux conversations/donnÃ©es privÃ©es non autorisÃ©es ; langage comprÃ©hensible et non stigmatisant.

**LLM.** RÃ©sumÃ©s peuvent Ãªtre prÃ©-calculÃ©s ; donnÃ©es source dÃ©terministes.

---

## AIA-AGT-020 â ModerationAgent

**Mission.** DÃ©tecter et prioriser contenus communautaires potentiellement contraires aux rÃ¨gles.

**Sortie.** labels, severity, confidence, recommended action.

**RÃ¨gle.** Le modÃ¨le ne prononce pas automatiquement une sanction lourde. Human review selon seuil/politique. Conserver appels et audit.

---

## AIA-AGT-021 â AdminAssistantAgent

**Mission.** Aider un administrateur Ã  comprendre l'Ã©tat de la plateforme, naviguer dans les donnÃ©es autorisÃ©es et prÃ©parer des actions.

**Tools.** Read-only analytics par dÃ©faut, search admin docs, job status, configuration readers.

**Interdits.** SQL arbitraire, modification RLS directe, remboursement/publication/suppression massive sans service mÃ©tier + confirmation/validation.

**RÃ¨gle.** Toute action mutante doit Ãªtre prÃ©sentÃ©e explicitement avant exÃ©cution et passer par permission + audit.

---

## AIA-AGT-022 â SupportTriageAgent

**Mission.** Classer demandes support, dÃ©tecter urgence, rechercher solutions documentÃ©es, router vers la bonne Ã©quipe.

**Sortie.** category, priority, suggested response, routing target, required context.

**RÃ¨gle.** Minimisation des donnÃ©es ; pas de demande de secrets ; aucune action sensible sans procÃ©dure support autorisÃ©e.

---

## AIA-AGT-023 â TranslationAgent

**Mission.** Traduire interfaces/contenus autorisÃ©s en conservant sens pÃ©dagogique, terminologie et formules.

**Tools.** Glossaire versionnÃ©, translation memory, RAG terminologique.

**RÃ¨gle.** Une traduction de contenu pÃ©dagogique publiÃ©e est versionnÃ©e et validÃ©e selon workflow. Ne traduit pas aveuglÃ©ment noms propres, symboles ou terminologie officielle.

---

## AIA-AGT-024 â PedagogicalValidationAgent

**Mission.** PrÃ©contrÃ´ler exactitude, alignement curriculum, niveau, structure, accessibilitÃ©, citations, sÃ©curitÃ© et cohÃ©rence d'un contenu.

**Sortie.** checklist, errors, warnings, confidence, blocking issues, suggested fixes.

**RÃ¨gle.** C'est un prÃ©-validateur ; la publication humaine reste requise lorsque le workflow l'exige.

**Tools.** Curriculum, RAG, exact solvers, schema validators, accessibility checks, duplicate/plagiarism-like internal checks selon droits.

---

## AIA-AGT-025 â FraudRiskAgent

**Mission.** Produire des signaux de risque sur paiements, examens, comptes, promotions ou usages anormaux.

**Sortie.** risk signals + evidence + confidence + recommended review.

**RÃ¨gle.** Signal â  preuve. Pas de sanction automatique lourde sur seul score IA. Features sensibles limitÃ©es, explicabilitÃ© et audit obligatoires.

---

## AIA-AGT-026 â InfrastructureOpsAgent

**Mission.** Observer jobs, modÃ¨les, nÅuds Compute Fabric, files d'attente, erreurs et capacitÃ© ; proposer ou exÃ©cuter uniquement les opÃ©rations techniques explicitement autorisÃ©es.

**Tools.** Metrics/log readers, health checks, deployment status, queue controls, feature flags selon permission.

**Interdits par dÃ©faut.** Shell arbitraire en production, secrets, destruction de donnÃ©es, modification RLS, suppression de backups.

**HITL.** Rollback, dÃ©ploiement, scaling coÃ»teux ou action destructive selon politique d'approbation.

---

# 8. AGENTS ET CONTENT FACTORY ADMIN

Le cÃ´tÃ© Admin doit permettre trois origines Ã©quivalentes de contenu :

```text
MANUEL        IMPORT/UPLOAD        GÃNÃRATION IA
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

Un cours uploadÃ© n'est donc pas affichÃ© comme un simple PDF. Il devient une **source** : extraction â OCR/formules â structuration â mapping curriculum/catalogue â validation â Structured Content â templates configurÃ©s â preview â validation humaine â publication.

Un exercice importÃ© suit la mÃªme philosophie : dÃ©tection Ã©noncÃ©/questions/sous-questions/figures/barÃ¨me/rÃ©ponses/correction â structure d'exercice â renderer configurÃ© â validation.

---

# 9. ADMIN AI CONTROL PLANE

L'Administration Flutter doit exposer progressivement :

- **ADM-AI-001 Agent Registry** : 26 agents, statut, version, propriÃ©taire, permissions, dÃ©ploiement.
- **ADM-AI-002 Agent Detail** : mission, tools, prompts, RAG, modÃ¨les, quotas, mÃ©triques, tests.
- **ADM-AI-003 Prompt Registry** : prompts versionnÃ©s, diff, statut draft/candidate/production/retired, rollback.
- **ADM-AI-004 Tool Registry** : schÃ©mas, permissions, timeout, rate limit, environnements.
- **ADM-AI-005 Model Registry** : modÃ¨le, licence, taille, quantization, benchmark, matÃ©riel, contexte, langues.
- **ADM-AI-006 Model Deployments** : device/server, version, canary, rollback.
- **ADM-AI-007 RAG Sources** : sources, licences, scopes, versions, ingestion, chunks, index.
- **ADM-AI-008 RAG Quality** : recall tests, citation quality, stale sources, retrieval failures.
- **ADM-AI-009 Evaluation Center** : datasets, suites, factuality, safety, pedagogy, latency, resource use.
- **ADM-AI-010 Model Factory** : datasets autorisÃ©s, training runs, LoRA/adapters, evaluations, quantization.
- **ADM-AI-011 Compute Fabric** : nodes, CPU/GPU/RAM/VRAM, availability, trust, queue, utilization.
- **ADM-AI-012 Jobs** : OCR, RAG, gÃ©nÃ©ration, training, PDF, audio, jeux ; cancel/retry selon droits.
- **ADM-AI-013 Quotas & Entitlements** : policies par offre, compute units, reset, priority, concurrency, bonus.
- **ADM-AI-014 Usage Ledger** : consommation append-only et rÃ©conciliation.
- **ADM-AI-015 AI Cost Dashboard** : coÃ»t physique estimÃ©, temps GPU/CPU, cache hit, device offload, coÃ»t par activitÃ©.
- **ADM-AI-016 Agent Analytics** : acceptance/rejection/edit rate, latency, failures, fallback.
- **ADM-AI-017 Safety & Incidents** : flags, escalations, incident timeline, mitigations.
- **ADM-AI-018 Feature Flags** : activation par pays/role/plan/version/device.
- **ADM-AI-019 Audit & Rollback** : historique des changements IA.
- **ADM-AI-020 Learning Orchestrator Policies** et **Mastery Engine Parameters** avec versioning et simulation avant publication.

Les rÃ´les Admin IA, infrastructure, sÃ©curitÃ©, contenu et pÃ©dagogie doivent Ãªtre distincts. `is_admin=true` ne suffit pas.

---

# 10. RAG

Pipeline :

```text
SOURCE VALIDÃE
 -> ingestion versionnÃ©e
 -> nettoyage
 -> segmentation structure-aware
 -> metadata curriculum/permission/version
 -> embeddings locaux
 -> pgvector par dÃ©faut
 -> retrieval filtrÃ©
 -> reranking local si utile
 -> citations
 -> retrieval logs
```

RÃ¨gles :
- documents non fiables isolÃ©s ;
- dÃ©fense contre prompt injection documentaire ;
- aucun chunk d'un autre scope/profil ;
- retrait d'une source propagÃ© Ã  l'index ;
- citation liÃ©e Ã  version/source ;
- rÃ©indexation contrÃ´lÃ©e et observable.

---

# 11. MÃMOIRE

Trois niveaux :

1. **conversation courte** : contexte temporaire minimal ;
2. **mÃ©moire pÃ©dagogique structurÃ©e** : Student Model, maÃ®trise, misconceptions, prÃ©fÃ©rences autorisÃ©es ;
3. **prÃ©fÃ©rences explicites** : langue, accessibilitÃ©, formats.

Interdit : mÃ©moire brute illimitÃ©e par dÃ©faut, mÃ©lange entre profils, conservation sans politique, transformation d'une infÃ©rence fragile en attribut permanent.

---

# 12. TOOLS

CatÃ©gories initiales :

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

Chaque tool possÃ¨de JSON Schema, permissions, scope, timeout, idempotence, journalisation, limites et tests.

---

# 13. MODEL FACTORY

Ne pas entraÃ®ner un foundation model depuis zÃ©ro par dÃ©faut.

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

Datasets possibles uniquement avec droits et gouvernance : curriculum officiel, cours validÃ©s, sujets/corrections autorisÃ©s, erreurs frÃ©quentes, mÃ©thodes pÃ©dagogiques validÃ©es, exemples de tool calling.

---

# 14. COMPUTE FABRIC

Sources de compute possibles : machine dÃ©veloppeur, serveur propre, Ã©tablissement, universitÃ©/partenaire, association/sponsor, nÅud Ã©cole, capacitÃ© gratuite opportuniste.

Une ressource gratuite externe n'est jamais une dÃ©pendance de production garantie.

Chaque nÅud dÃ©clare : identitÃ©, trust level, hardware, modÃ¨les autorisÃ©s, disponibilitÃ©, queue, mÃ©triques, politique de donnÃ©es. Les donnÃ©es personnelles sensibles ne sont pas envoyÃ©es vers un nÅud non approuvÃ©.

---

# 15. OBSERVABILITÃ

Pour chaque run : request/trace ID, agent/version, route, model/version, tools, durÃ©e, retries, cache, compute units, quota decision, error class, validation result, safety flags et rÃ©sultat mÃ©tier minimal pseudonymisÃ©.

Ne jamais mettre secrets, tokens, PIN, donnÃ©es brutes sensibles ou contenu privÃ© inutile dans les logs.

MÃ©triques : latency p50/p95/p99, success/fallback/error, cache hit, device offload, GPU/CPU time, acceptance/edit/rejection, factuality, citation quality, tool accuracy, coÃ»t physique estimÃ©.

---

# 16. ÃVALUATION AVANT PRODUCTION

Aucune nouvelle version de modÃ¨le/prompt/agent ne passe en production sans suite d'Ã©valuation pertinente :

- exactitude/factualitÃ© ;
- alignement curriculum ;
- niveau pÃ©dagogique ;
- citations ;
- tool calling ;
- sÃ©curitÃ© mineurs ;
- confidentialitÃ© ;
- biais ;
- hallucination ;
- robustesse aux prompt injections ;
- latence ;
- RAM/VRAM ;
- consommation ;
- comportement offline/dÃ©gradÃ©.

Comparaison obligatoire Ã  la version actuellement en production et seuils configurables.

---

# 17. DONNÃES IA â MODÃLE CONCEPTUEL

Avant crÃ©ation, auditer les tables Supabase existantes. EntitÃ©s cibles possibles :

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

Principes : UUID/ULID, UTC, FKs explicites, RLS/ABAC, audit append-only pour usages sensibles, idempotence, sÃ©paration PII/analytics, chiffrement, versioning, soft-delete sÃ©lectif.

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
 -> Model route si nÃ©cessaire
 -> Structured output validation
 -> Safety/pedagogical validation
 -> Business service / HITL si effet mÃ©tier
 -> Response
 -> Usage ledger
 -> Metrics/evaluation sample
```

---

# 19. ERREURS ET FALLBACK

Codes mÃ©tier recommandÃ©s : `AGENT_UNAVAILABLE`, `MODEL_UNAVAILABLE`, `QUOTA_EXHAUSTED`, `RAG_EMPTY`, `TOOL_FAILED`, `OUTPUT_INVALID`, `PERMISSION_DENIED`, `HUMAN_REVIEW_REQUIRED`, `OFFLINE_LIMITATION`, `CONTENT_VERSION_CONFLICT`.

Un Ã©chec de modÃ¨le ne doit pas devenir automatiquement une erreur gÃ©nÃ©rale. Le router tente, selon politique : cache â local â modÃ¨le alternatif â queue â mode dÃ©gradÃ©.

---

# 20. SÃCURITÃ DES MINEURS

- minimisation stricte ;
- scope parent/enseignant explicite ;
- consentements versionnÃ©s ;
- voix/images selon politique ;
- pas de profilage opaque Ã  fort impact ;
- pas de sanctions automatiques lourdes ;
- signalement/escalade selon rÃ¨gles validÃ©es ;
- contenus gÃ©nÃ©rÃ©s pour mineurs soumis aux contrÃ´les appropriÃ©s ;
- export/suppression/contestation selon politique de donnÃ©es.

---

# 21. TESTS OBLIGATOIRES PAR AGENT

Chaque agent possÃ¨de au minimum :

1. happy path ;
2. permission denied ;
3. mauvais scope ;
4. RAG vide ;
5. tool timeout ;
6. modÃ¨le indisponible ;
7. quota Ã©puisÃ© ;
8. sortie JSON invalide ;
9. offline/degraded ;
10. prompt injection ;
11. donnÃ©es d'un autre profil ;
12. version rollback ;
13. benchmark coÃ»t/latence ;
14. critÃ¨res pÃ©dagogiques spÃ©cifiques.

---

# 22. ORDRE D'IMPLÃMENTATION POUR CLAUDE CODE

Ne pas implÃ©menter les 26 agents simultanÃ©ment.

### IA-000 â Audit
Inspecter code, DB, services IA existants, dÃ©pendances, secrets/configs, RLS, queues, offline, Content Factory.

### IA-001 â Contracts
CrÃ©er interfaces/envelopes, registry, typed errors, capability model, tool contracts.

### IA-002 â Gateway minimal
Auth, permissions, request IDs, structured validation, observability.

### IA-003 â Tool Gateway
Curriculum/content/RAG/math tools, sans accÃ¨s SQL arbitraire.

### IA-004 â RAG minimal
Sources validÃ©es, ingestion, pgvector, filtres, citations.

### IA-005 â Model Router
Provider abstraction + local provider par dÃ©faut.

### IA-006 â Quota Engine
Policies, entitlements, weighted compute units, ledger, fallback.

### IA-007 â Premier vertical slice
`TutorAgent` sur une matiÃ¨re/leÃ§on test avec RAG + math tool + Student Model read + cache + quota + observabilitÃ©.

### IA-008 â Content Factory agents
OCRAgent â FormulaRecognitionAgent â DocumentStructuringAgent â CurriculumMappingAgent â PedagogicalValidationAgent.

### IA-009 â Exercise vertical slice
ExerciseAgent + CorrectionAgent + validation humaine.

### IA-010 â Learning intelligence
DiagnosticAgent, MisconceptionAgent, RevisionAgent, RecommendationAgent, SocraticAgent, ExplanationAgent, ExamCoachAgent.

### IA-011 â Multimodal factories
GameContentAgent, MusicLearningAgent, LabAssistantAgent.

### IA-012 â Staff/family
TeacherAssistantAgent, ParentInsightAgent, TranslationAgent.

### IA-013 â Operations
ModerationAgent, AdminAssistantAgent, SupportTriageAgent, FraudRiskAgent, InfrastructureOpsAgent.

### IA-014 â Model Factory / Compute Fabric
Seulement aprÃ¨s benchmarks et besoins observÃ©s.

---

# 23. CRITÃRES DE DONE D'UN AGENT

Un agent n'est pas Â« terminÃ© Â» parce qu'un prompt rÃ©pond dans une console. Il est Done seulement si : contrat versionnÃ©, permissions, tools, RAG, route modÃ¨le, quota, cache, erreurs, mode dÃ©gradÃ©, observabilitÃ©, tests, Ã©valuation, Admin visibility, documentation, sÃ©curitÃ© et rollback sont opÃ©rationnels pour son pÃ©rimÃ¨tre.

---

# 24. RÃGLE DE NON-RÃGRESSION POUR VIBE CODING

Claude Code/Antigravity doit toujours commencer un work package par l'inspection du code rÃ©el. Pour chaque modification : `EXISTING -> TARGET -> GAP -> MIGRATION -> TEST`. Ne jamais recrÃ©er une table/route/service en doublon. Ne jamais supprimer une fonctionnalitÃ© compatible. Toute migration destructive exige analyse, sauvegarde/rollback et validation.

---

# 25. RÃGLE D'OR

L'objectif n'est pas d'afficher Â« IA Â» partout. L'objectif est que l'intelligence soit **utile, mesurable, sÃ»re, Ã©conomiquement contrÃ´lable, souveraine, compatible offline et intÃ©grÃ©e au moteur pÃ©dagogique**.

Un bon agent EDLEARN est celui qui utilise le moins de compute nÃ©cessaire pour produire un rÃ©sultat pÃ©dagogique correct, vÃ©rifiable et adaptÃ© Ã  l'Ã©lÃ¨ve.
