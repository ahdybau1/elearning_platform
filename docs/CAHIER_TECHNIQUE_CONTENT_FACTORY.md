# CAHIER TECHNIQUE â EDLEARN CONTENT FACTORY

## 1. But
Transformer crÃ©ation manuelle, PDF/DOCX/scans, exercices, examens et gÃ©nÃ©rations IA en **contenu pÃ©dagogique structurÃ©**, rendu par les mÃªmes composants configurables dans l'Admin, l'application Ã©lÃ¨ve, le PDF et les packages offline.

## 2. Principe canonique
`SOURCE -> EXTRACTION -> STRUCTURATION -> CURRICULUM MAPPING -> CATALOG MAPPING -> VALIDATION -> HUMAN REVIEW -> VERSION -> RENDERERS -> PUBLICATION`.

Le fichier uploadÃ© est une source, pas automatiquement l'interface finale. Le contenu canonique ne doit pas Ãªtre un gros HTML : il est composÃ© de blocs typÃ©s avec contenu, mÃ©tadonnÃ©es, ordre, version, provenance et renderer/template key.

## 3. EntrÃ©es Admin
- CrÃ©er manuellement.
- Importer PDF/DOCX/TXT/image/scan.
- GÃ©nÃ©rer avec IA.
- GÃ©nÃ©rer des exercices depuis un cours.
- Extraire exercices/examens/corrigÃ©s d'un document.
- Importer en masse via formats structurÃ©s validÃ©s.

## 4. Catalogues pÃ©dagogiques
Catalogues administrables et versionnÃ©s par matiÃ¨re. Exemples : dÃ©finition, thÃ©orÃ¨me, preuve, formule, exemple, mÃ©thode, expÃ©rience, protocole, carte, frise, biographie, dialogue, vocabulaire, audio, exercice, rÃ©sumÃ©. Ne pas hardcoder la taxonomie dans les Ã©crans Flutter.

## 5. Rendering Engine
Registre `renderer_key -> widget renderer`. Premiers types : paragraph, heading, definition, theorem, formula, example, image, video, exercise, summary. Responsive mobile/tablette/desktop, thÃ¨mes, accessibilitÃ©, PDF et offline Ã  partir de la mÃªme source structurÃ©e.

## 6. Upload pipeline
1. stocker original + checksum/provenance ; 2. extraction native ; 3. OCR si nÃ©cessaire ; 4. reconnaissance formules ; 5. structuration ; 6. mapping curriculum/compÃ©tences ; 7. mapping catalogue ; 8. signaler Ã©lÃ©ments manquants ; 9. preview ; 10. correction humaine ; 11. validation ; 12. publication/versioning.

## 7. Course Generator
Le gÃ©nÃ©rateur reÃ§oit pays/section/classe/sÃ©rie/matiÃ¨re/chapitre/leÃ§on, rÃ©cupÃ¨re curriculum, compÃ©tences, prÃ©requis, RAG validÃ©, catalogue et rÃ¨gles pÃ©dagogiques. Il retourne du JSON conforme au schÃ©ma Content Factory, jamais une page Flutter arbitraire.

## 8. Exercise Factory
CrÃ©ation, import, extraction et gÃ©nÃ©ration. Structure : statement, questions, answers, solution, hints, difficulty, skills, prerequisites, answer_mode, grading, provenance. Validation individuelle accepter/modifier/rÃ©gÃ©nÃ©rer/rejeter.

## 9. Workflow
DRAFT -> AI_PRECHECK -> WAITING_REVIEW -> NEEDS_CHANGES/APPROVED -> SCHEDULED/PUBLISHED -> ARCHIVED. Toute modification publiÃ©e crÃ©e une nouvelle version ; rollback auditÃ©.

## 10. Jobs
OCR, parsing, gÃ©nÃ©ration massive, PDF et ingestion RAG sont asynchrones : queued/processing/waiting_validation/completed/failed/cancelled avec progression, retry, idempotence et notification.

## 11. SÃ©curitÃ©
RBAC/ABAC, RLS cÃ´tÃ© donnÃ©es, fichiers scannÃ©s, limites taille/type, provenance, audit, aucun agent avec SQL arbitraire, publication humaine par dÃ©faut.

## 12. Jalon E2E initial
Admin crÃ©e un cours Terminale C MathÃ©matiques -> ajoute blocs -> preview -> draft -> review -> approve -> publish -> l'Ã©lÃ¨ve ouvre la leÃ§on et obtient le rendu configurÃ©. DeuxiÃ¨me jalon : upload document -> structuration -> preview -> correction -> publication. TroisiÃ¨me : cours -> gÃ©nÃ©ration exercices -> revue individuelle -> publication -> tentative Ã©lÃ¨ve -> correction/mastery evidence.
