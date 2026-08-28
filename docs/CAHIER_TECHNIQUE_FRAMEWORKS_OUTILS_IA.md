# CAHIER TECHNIQUE — FRAMEWORKS, MOTEURS ET OUTILS EDLEARN

**Version : 1.0 — 28 août 2026**  
**Statut : architecture cible, à valider par benchmark avant verrouillage**

## 1. Règle d'architecture
EDLEARN applique le principe : **le LLM comprend, raisonne, explique, crée et orchestre ; les bibliothèques spécialisées calculent, exécutent, rendent, simulent et stockent.** Aucun framework n'est adopté uniquement parce qu'il est populaire. Chaque dépendance doit avoir une mission, une licence vérifiée, un benchmark, un fallback et un propriétaire opérationnel.

## 2. Stack de référence
| Domaine | Choix principal | Alternatives / fallback | Usage |
|---|---|---|---|
| Frontend | Flutter / Dart | PWA/Web Flutter selon existant | Élève, famille, admin |
| Backend IA | FastAPI / Python | services existants conservés | AI Gateway, tools, orchestration |
| Orchestration | LangGraph | workflow déterministe interne | workflows agents stateful |
| Abstractions IA | LangChain ciblé | SDK natifs | intégrations seulement si utile |
| Model gateway | LiteLLM-compatible | provider adapters internes | routage multi-modèles |
| Serving serveur | vLLM | Ollama, llama.cpp | modèles open-weight serveur |
| Local/desktop | llama.cpp | Ollama | GGUF / quantifié |
| Browser/PWA | WebLLM | serveur/local deterministic | WebGPU si compatible |
| Mobile/edge | ONNX Runtime, ExecuTorch, LiteRT-LM | llama.cpp mobile | petits modèles/classifieurs |
| Fine-tuning | Unsloth + PEFT | Transformers natif | LoRA/QLoRA |
| Symbolique maths | SymPy | SageMath optionnel | calcul exact, vérification |
| Numérique | NumPy + SciPy | moteur spécialisé | calcul scientifique |
| Formules UI | KaTeX/MathJax | Flutter math renderer compatible | rendu LaTeX |
| Documents | LaTeX/Tectonic | Typst optionnel | PDF scientifique |
| Diagrammes | Mermaid, Graphviz, PlantUML | TikZ | graphes/UML |
| Graphiques | PGFPlots / Plotly/ECharts selon surface | Flutter charts | visualisation |
| OCR | PaddleOCR | moteur OCR benchmarké | documents/scans |
| Prétraitement vision | OpenCV | — | deskew, crop, contraste |
| Formules OCR | modèle spécialisé + parser | revue humaine | formules manuscrites/imprimées |
| STT | whisper.cpp | sherpa-onnx | transcription locale |
| TTS | Piper | sherpa-onnx | synthèse locale |
| Audio pipeline | FFmpeg | — | conversion/normalisation |
| Jeux | Flame Engine | Godot | jeux Flutter / jeux complexes |
| Musique | Tone.js + MuseScore | AudioCraft/MusicGen si licence/compute OK | MIDI, partition, audio éducatif |
| Code Python web | Pyodide | sandbox serveur | exécution réelle |
| Code multi-langage | Judge0 | sandbox conteneur interne | exercices de programmation |
| Circuits | ngspice | CircuitJS | simulation déterministe |
| Chimie | RDKit + Open Babel | — | molécules/calculs |
| Molécules 3D | 3Dmol.js | — | visualisation |
| Modélisation physique | OpenModelica | Matter.js/Box2D selon cas | laboratoires |
| Géométrie interactive | GeoGebra/JSXGraph à évaluer | moteur Flutter | constructions |
| Vecteurs RAG | PostgreSQL + pgvector | Qdrant si benchmark | défaut souverain |
| Recherche texte | PostgreSQL FTS | Meilisearch/Typesense | recherche hybride |
| Cache | Valkey/Redis-compatible + PostgreSQL | cache mémoire local | réponses/semantic cache |
| Jobs | queue + workers | Celery ou alternative légère après audit | OCR, PDF, génération, ingestion |
| Observabilité IA | OpenTelemetry + solution self-hosted; Langfuse candidat | métriques internes | traces, coût, latence, eval |
| Données | Supabase/PostgreSQL existant | — | source métier |

## 3. Règles de sélection
1. Vérifier d'abord la stack réellement présente dans le repo.
2. Ne pas remplacer une dépendance fonctionnelle sans gap analysis.
3. Préférer open source/open-weight et self-hostable.
4. Vérifier licence du code **et** des poids de modèles.
5. Mesurer RAM, VRAM, CPU, batterie, latence, taille disque, qualité FR/EN et coût serveur.
6. Prévoir un fallback déterministe ou contenu validé pour les fonctions critiques.
7. Les APIs payantes restent optionnelles et désactivables.

## 4. Routage compute
```text
Demande -> déterministe/cache ? -> oui: exécuter
                         -> non: device AI possible ? -> oui: local
                                                   -> non: quota distant disponible ?
                                                          -> oui: Compute Fabric
                                                          -> non: mode dégradé/local
```

## 5. Matrice agents — moteurs
- Tutor/Socratic/Explanation : RAG + EduSmall/EduStrong + SymPy/science tools selon matière.
- Exercise/Correction : règles + RAG + SymPy/Judge0/outils spécialisés + LLM pour explication.
- OCR/FormulaRecognition/DocumentStructuring : OpenCV + PaddleOCR + formula OCR + validation.
- GameContent : LLM produit JSON validé ; Flame/Godot exécute.
- MusicLearning : LLM produit objectif/paroles/structure ; Tone.js/MuseScore/audio engine rend.
- LabAssistant : LLM guide ; ngspice/RDKit/OpenModelica/etc. simulent.
- InfrastructureOps : métriques/health/jobs ; aucun accès arbitraire aux secrets.

## 6. Interdictions
- Pas de calcul mathématique exact confié uniquement au LLM.
- Pas de simulation scientifique inventée par le LLM.
- Pas de HTML/Flutter arbitraire généré comme format canonique d'un cours.
- Pas de dépendance à un free tier externe comme fondation de production.
- Pas de clé fournisseur dans Flutter.
- Pas de framework ajouté sans ADR ou justification dans le journal technique.

## 7. Benchmark obligatoire
Avant passage PRODUCTION, consigner : version, licence, taille, hardware, débit, p50/p95, qualité, mémoire, énergie/batterie si device, erreurs, coût estimé, compatibilité offline, résultat de sécurité et décision GO/NO-GO.
