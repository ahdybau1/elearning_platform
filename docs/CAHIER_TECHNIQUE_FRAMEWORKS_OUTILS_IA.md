# CAHIER TECHNIQUE â FRAMEWORKS, MOTEURS ET OUTILS EDLEARN

**Version : 1.0 â 28 aoÃ»t 2026**  
**Statut : architecture cible, Ã  valider par benchmark avant verrouillage**

## 1. RÃ¨gle d'architecture
EDLEARN applique le principe : **le LLM comprend, raisonne, explique, crÃ©e et orchestre ; les bibliothÃ¨ques spÃ©cialisÃ©es calculent, exÃ©cutent, rendent, simulent et stockent.** Aucun framework n'est adoptÃ© uniquement parce qu'il est populaire. Chaque dÃ©pendance doit avoir une mission, une licence vÃ©rifiÃ©e, un benchmark, un fallback et un propriÃ©taire opÃ©rationnel.

## 2. Stack de rÃ©fÃ©rence
| Domaine | Choix principal | Alternatives / fallback | Usage |
|---|---|---|---|
| Frontend | Flutter / Dart | PWA/Web Flutter selon existant | ÃlÃ¨ve, famille, admin |
| Backend IA | FastAPI / Python | services existants conservÃ©s | AI Gateway, tools, orchestration |
| Orchestration | LangGraph | workflow dÃ©terministe interne | workflows agents stateful |
| Abstractions IA | LangChain ciblÃ© | SDK natifs | intÃ©grations seulement si utile |
| Model gateway | LiteLLM-compatible | provider adapters internes | routage multi-modÃ¨les |
| Serving serveur | vLLM | Ollama, llama.cpp | modÃ¨les open-weight serveur |
| Local/desktop | llama.cpp | Ollama | GGUF / quantifiÃ© |
| Browser/PWA | WebLLM | serveur/local deterministic | WebGPU si compatible |
| Mobile/edge | ONNX Runtime, ExecuTorch, LiteRT-LM | llama.cpp mobile | petits modÃ¨les/classifieurs |
| Fine-tuning | Unsloth + PEFT | Transformers natif | LoRA/QLoRA |
| Symbolique maths | SymPy | SageMath optionnel | calcul exact, vÃ©rification |
| NumÃ©rique | NumPy + SciPy | moteur spÃ©cialisÃ© | calcul scientifique |
| Formules UI | KaTeX/MathJax | Flutter math renderer compatible | rendu LaTeX |
| Documents | LaTeX/Tectonic | Typst optionnel | PDF scientifique |
| Diagrammes | Mermaid, Graphviz, PlantUML | TikZ | graphes/UML |
| Graphiques | PGFPlots / Plotly/ECharts selon surface | Flutter charts | visualisation |
| OCR | PaddleOCR | moteur OCR benchmarkÃ© | documents/scans |
| PrÃ©traitement vision | OpenCV | â | deskew, crop, contraste |
| Formules OCR | modÃ¨le spÃ©cialisÃ© + parser | revue humaine | formules manuscrites/imprimÃ©es |
| STT | whisper.cpp | sherpa-onnx | transcription locale |
| TTS | Piper | sherpa-onnx | synthÃ¨se locale |
| Audio pipeline | FFmpeg | â | conversion/normalisation |
| Jeux | Flame Engine | Godot | jeux Flutter / jeux complexes |
| Musique | Tone.js + MuseScore | AudioCraft/MusicGen si licence/compute OK | MIDI, partition, audio Ã©ducatif |
| Code Python web | Pyodide | sandbox serveur | exÃ©cution rÃ©elle |
| Code multi-langage | Judge0 | sandbox conteneur interne | exercices de programmation |
| Circuits | ngspice | CircuitJS | simulation dÃ©terministe |
| Chimie | RDKit + Open Babel | â | molÃ©cules/calculs |
| MolÃ©cules 3D | 3Dmol.js | â | visualisation |
| ModÃ©lisation physique | OpenModelica | Matter.js/Box2D selon cas | laboratoires |
| GÃ©omÃ©trie interactive | GeoGebra/JSXGraph Ã  Ã©valuer | moteur Flutter | constructions |
| Vecteurs RAG | PostgreSQL + pgvector | Qdrant si benchmark | dÃ©faut souverain |
| Recherche texte | PostgreSQL FTS | Meilisearch/Typesense | recherche hybride |
| Cache | Valkey/Redis-compatible + PostgreSQL | cache mÃ©moire local | rÃ©ponses/semantic cache |
| Jobs | queue + workers | Celery ou alternative lÃ©gÃ¨re aprÃ¨s audit | OCR, PDF, gÃ©nÃ©ration, ingestion |
| ObservabilitÃ© IA | OpenTelemetry + solution self-hosted; Langfuse candidat | mÃ©triques internes | traces, coÃ»t, latence, eval |
| DonnÃ©es | Supabase/PostgreSQL existant | â | source mÃ©tier |

## 3. RÃ¨gles de sÃ©lection
1. VÃ©rifier d'abord la stack rÃ©ellement prÃ©sente dans le repo.
2. Ne pas remplacer une dÃ©pendance fonctionnelle sans gap analysis.
3. PrÃ©fÃ©rer open source/open-weight et self-hostable.
4. VÃ©rifier licence du code **et** des poids de modÃ¨les.
5. Mesurer RAM, VRAM, CPU, batterie, latence, taille disque, qualitÃ© FR/EN et coÃ»t serveur.
6. PrÃ©voir un fallback dÃ©terministe ou contenu validÃ© pour les fonctions critiques.
7. Les APIs payantes restent optionnelles et dÃ©sactivables.

## 4. Routage compute
```text
Demande -> dÃ©terministe/cache ? -> oui: exÃ©cuter
                         -> non: device AI possible ? -> oui: local
                                                   -> non: quota distant disponible ?
                                                          -> oui: Compute Fabric
                                                          -> non: mode dÃ©gradÃ©/local
```

## 5. Matrice agents â moteurs
- Tutor/Socratic/Explanation : RAG + EduSmall/EduStrong + SymPy/science tools selon matiÃ¨re.
- Exercise/Correction : rÃ¨gles + RAG + SymPy/Judge0/outils spÃ©cialisÃ©s + LLM pour explication.
- OCR/FormulaRecognition/DocumentStructuring : OpenCV + PaddleOCR + formula OCR + validation.
- GameContent : LLM produit JSON validÃ© ; Flame/Godot exÃ©cute.
- MusicLearning : LLM produit objectif/paroles/structure ; Tone.js/MuseScore/audio engine rend.
- LabAssistant : LLM guide ; ngspice/RDKit/OpenModelica/etc. simulent.
- InfrastructureOps : mÃ©triques/health/jobs ; aucun accÃ¨s arbitraire aux secrets.

## 6. Interdictions
- Pas de calcul mathÃ©matique exact confiÃ© uniquement au LLM.
- Pas de simulation scientifique inventÃ©e par le LLM.
- Pas de HTML/Flutter arbitraire gÃ©nÃ©rÃ© comme format canonique d'un cours.
- Pas de dÃ©pendance Ã  un free tier externe comme fondation de production.
- Pas de clÃ© fournisseur dans Flutter.
- Pas de framework ajoutÃ© sans ADR ou justification dans le journal technique.

## 7. Benchmark obligatoire
Avant passage PRODUCTION, consigner : version, licence, taille, hardware, dÃ©bit, p50/p95, qualitÃ©, mÃ©moire, Ã©nergie/batterie si device, erreurs, coÃ»t estimÃ©, compatibilitÃ© offline, rÃ©sultat de sÃ©curitÃ© et dÃ©cision GO/NO-GO.
