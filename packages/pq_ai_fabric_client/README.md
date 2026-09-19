# pq_ai_fabric_client

Client Dart partagé par `admin_app` et `student_app` pour le Capability Registry du Sovereign AI Gateway.

Le package n'embarque aucun modèle et n'appelle aucune API payante. Il transmet le JWT Supabase courant au Gateway puis expose :

- `listCapabilities()` ;
- `getCapability(id)` ;
- `planCapability(request)`.

Le client ne transmet aucun rôle. Le Gateway déduit `student` ou `admin` de la session authentifiée afin qu'une application Élève ne puisse pas demander les capacités audio/vidéo réservées à l'Administration.

L'URL est injectée dans les applications avec :

```bash
flutter run --dart-define=PQ_AI_GATEWAY_URL=http://ADRESSE_DU_GATEWAY:8000
```

Sur un téléphone ou un émulateur, `127.0.0.1` désigne l'appareil lui-même. Il faut donc fournir une adresse de Gateway joignable sur le réseau de test.
