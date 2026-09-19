# EDLEARN Sovereign AI Gateway

Gateway FastAPI authentifié partagé par les applications Élève et Administration. Il conserve les agents existants et ajoute le **PQ Open Capability Registry** : une couche de sélection zéro coût pour les outils et modèles locaux ou auto-hébergés.

## Fonctions présentes

- authentification et autorisation Supabase ;
- registre et invocation des agents existants ;
- Tool Gateway allowlisté ;
- RAG et Model Router existants ;
- traçage et quotas ;
- registre de 31 capacités multimodales et 100 composants GitHub contrôlés ;
- planification déterministe selon rôle, licence, matériel, réseau, cible et GPU ;
- lecture scientifique en trois étapes : structure, verbalisation française, TTS ;
- index de découverte séparé de 1 656 dépôts et shortlist désactivée de 50 projets ;
- blocage de toute API payante ou carte bancaire dans la politique Zero-Cost Absolute.

Le catalogue n'installe et n'exécute aucun dépôt automatiquement. Chaque adapter est activé séparément après revue de licence, scan de sécurité et benchmark. Le rôle est dérivé de l'identité authentifiée : l'Élève peut générer du texte et des images et utiliser la lecture vocale, tandis que la génération audio créative, musicale et vidéo reste réservée à l'Administration.

## Lancer localement

```bash
cd gateway
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

## Valider le catalogue

```bash
cd gateway
PYTHONPATH=. python scripts/validate_capability_catalog.py
PYTHONPATH=. python -m unittest discover -s tests -v
```

## API Capability Registry

Les trois routes exigent un JWT Supabase valide.

```bash
curl http://localhost:8000/v1/capabilities \
  -H "Authorization: Bearer <JWT>"

curl http://localhost:8000/v1/capabilities/audio.transcribe \
  -H "Authorization: Bearer <JWT>"

curl -X POST http://localhost:8000/v1/capabilities/plan \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{
    "capability_id": "audio.transcribe",
    "available_targets": ["android", "server_cpu"],
    "device_tier": "L1",
    "online": false,
    "commercial_use": true,
    "allow_conditional_licenses": false,
    "allow_gpu": false
  }'
```

## Utilisation Flutter

Le package `packages/pq_ai_fabric_client` est une dépendance commune de `admin_app` et `student_app`. L'adresse du Gateway est injectée sans secret :

```bash
flutter run --dart-define=PQ_AI_GATEWAY_URL=http://ADRESSE_DU_GATEWAY:8000
```

Les providers Riverpod des deux applications réutilisent automatiquement le JWT de la session Supabase courante.

## Limite volontaire de cette tranche

Cette fondation décide **ce qui peut être utilisé** ; elle ne prétend pas que les 100 composants sont déjà installés. Les premiers adapters à implémenter après fusion sont : MathJax/Speech Rule Engine/MathCAT pour la lecture scientifique, documents/OCR, transcription locale, transcodage, puis embeddings et RAG locaux. Les générations musique et vidéo restent des workers GPU Administration optionnels et différés.
