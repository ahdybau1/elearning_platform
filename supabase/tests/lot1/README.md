# Tests du Lot 1 (sécurité des accès)

Rejoue toutes les migrations sur une base PostgreSQL **jetable**, insère des données de test, puis
lance 15 scénarios d'attaque (`OK` = protection en place, `FAILLE` = trou).

```bash
cd ~/elearning_platform/supabase/tests/lot1
./run.sh            # état sans la migration 85 → montre les failles
./run.sh avec_85    # avec la migration 85 → doit afficher 15 OK
```

Prérequis : PostgreSQL 16 local (utilisateur système `postgres`). `supabase_stubs.sql` imite le strict
nécessaire de Supabase (rôles `anon`/`authenticated`/`service_role`, `auth.uid()`, `cron`, `storage`).
La migration 65 (seed à identifiants codés en dur) est ignorée, et `create extension pg_cron` est
retiré à la volée.

**Ne jamais lancer `seed.sql` sur la base de production.**
