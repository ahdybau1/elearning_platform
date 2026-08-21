# Cahier des Charges — Plateforme E-learning Collège & Lycée

**Application Élève & Famille + Application Administration**
Architecture technique et modèle de données inclus
Version MVP — Cameroun
Document de référence pour le développement

> Transcrit intégralement depuis le PDF fourni le 2026-08-21, pour ne plus jamais le perdre lors d'un résumé de conversation. Conservé tel quel — ne pas modifier ce fichier sans raison explicite de le faire évoluer avec le projet réel (auquel cas dater la modification).

---

## Sommaire

- **PARTIE 1 — APPLICATION ÉLÈVE**
  1. Présentation générale
  2. Structure académique et profils (2.1)
  3. Contenu pédagogique (2.2)
  4. Examens officiels nationaux (2.3)
  5. Épreuves par établissement (2.3bis)
  6. Modèle d'abonnement, paiement et cycle de vie complet (2.4)
  7. Inscription et authentification (2.5)
  8. Forum (2.6)
  9. Messagerie / Contact administration (2.7)
  10. Assistant Intelligence Artificielle (2.8)
  11. Paramètres (2.10) et Accessibilité (2.10bis)
  12. Soutien / Dons (2.11)
  13. Examens blancs et Olympiades (2.12)
  14. Gamification (2.13)
  15. Révision intelligente espacée (2.14)
  16. Communautés d'étude — WhatsApp (2.15)
  17. Espace parent (2.16)
  18. Synchronisation hors-ligne intelligente (2.17)
  19. Rappels d'échéances d'examens officiels (2.18)
  20. Architecture de navigation (2.19)
  21. Exigences non-fonctionnelles
  22. Roadmap
- **PARTIE 2 — APPLICATION ADMINISTRATION** (30 sections + rappel des périmètres d'accès + points en suspens)
- **PARTIE 3 — ARCHITECTURE TECHNIQUE ET STRATÉGIE DE DÉMARRAGE**
- **PARTIE 4 — MODÈLE DE DONNÉES DÉTAILLÉ** (~40 tables)
- **PARTIE 5 — LOGIQUE DÉTAILLÉE ET EXEMPLES CHIFFRÉS** (8 exemples complets)

---

## CAHIER DES CHARGES COMPLET

### Plateforme E-learning — Collège & Lycée

Ce document couvre l'intégralité des spécifications fonctionnelles, techniques et organisationnelles des deux applications de l'écosystème : l'application destinée aux élèves, parents et enseignants, et l'application d'administration centrale qui pilote l'ensemble du système.

---

# PARTIE 1 — APPLICATION ÉLÈVE

**Diagramme de cas d'utilisation général** (acteurs : Élève, Parent, Enseignant, Administrateur — cas d'usage : suivre sa progression, s'inscrire/choisir profil, consulter cours et exercices, passer un examen/composer, consulter le forum, utiliser l'assistant IA, payer un abonnement, suivre la progression de l'enfant, contacter l'administration, soumettre un cours, corriger une composition, gérer les épreuves d'établissement, créer des exercices, valider le contenu, consulter les statistiques et revenus, gérer l'arbre académique, gérer les comptes et rôles, gérer les remboursements, configurer la matrice de droits).

## 1. Présentation générale

### 1.1 Vision du projet

Créer un écosystème d'e-learning complet destiné aux élèves de collège et de lycée, structuré selon les systèmes éducatifs nationaux (en commençant par le Cameroun), offrant cours, exercices, accès aux sujets d'examens officiels et internes, accompagnement par intelligence artificielle, et une dimension communautaire et compétitive (forum, communautés d'étude, olympiades). L'écosystème comprend une application élève (web + mobile) et une application d'administration séparée, qui concentre toute la complexité technique (agents IA, templates, configuration).

### 1.2 Public cible

- Élèves du collège et du lycée (système éducatif camerounais pour le MVP)
- Parents (souvent détenteurs de l'appareil et payeurs de l'abonnement)
- Enseignants (créateurs de contenu validé, via l'application d'administration uniquement)

### 1.3 Proposition de valeur

- Contenu structuré selon l'arbre académique réel du pays (sections, enseignements, classes, séries)
- Préparation aux examens officiels nationaux ET accès à des épreuves de multiples établissements
- Accompagnement personnalisé par intelligence artificielle (tutorat, révision adaptative)
- Fonctionnement hors-ligne adapté aux contraintes de connectivité locales
- Modèle d'abonnement flexible, avec palier gratuit permanent
- Communautés d'échange officielles par classe (via WhatsApp)
- Rythme pédagogique réel respecté (déblocage progressif du contenu par trimestre, invisible pour l'élève)

### 1.4 Plateformes

- Application Web élève (PWA installable sur ordinateur), fonctionnement en ligne
- Application mobile élève (Android — Play Store, iOS — App Store), avec mode hors-ligne progressif
- Application Administration (web, séparée) — non accessible aux élèves

## 2. Structure académique et profils (2.1)

### 2.1 Hiérarchie académique visible côté élève

L'arbre académique a une profondeur variable selon le pays :

```
Pays
`-- Section (ex: Anglophone / Francophone / Bilingue — cas du Cameroun)
    `-- Type d'enseignement (Général / Technique / Industriel / Commercial)
        `-- Classe (6e, 5e, 4e, 3e, 2nde, 1ère, Terminale)
            `-- Série (C, A4, TI, D... — apparaît à partir de la 2nde)
                `-- Matière
                    `-- Chapitre
                        `-- Leçon
```

Le découpage par trimestre existe en coulisses, géré uniquement côté administration. Ce n'est jamais un niveau de navigation visible — l'élève navigue toujours par Matière → Chapitre → Leçon, sans jamais voir le mot « Trimestre ».

### 2.2 Règles de gestion de l'arbre

- Profondeur de l'arbre variable selon le pays (certains pays auront moins de niveaux)
- Les séries n'apparaissent qu'à certains niveaux (2nde, 1ère, Terminale au Cameroun)
- Une matière peut être associée à une seule classe, ou à un groupe de classes liées entre elles qui partagent un tronc commun (le contenu est alors unique et partagé, sans duplication)
- Création strictement en cascade, gérée côté administration : rien n'existe sans qu'un pays soit créé en premier

### 2.3 Modèle Compte / Profil

- **Compte** = identité unique (email, mot de passe, nom, prénom, téléphone, informations de paiement)
- **Profil** = classe précise + abonnement propre + progression propre + historique propre, rattaché à un compte
- Un compte peut avoir plusieurs profils (ex : un élève en 3e qui veut aussi réviser la 2nde)
- Chaque profil = un abonnement payé séparément (pas de mutualisation entre profils)
- Écran de sélection de profil après connexion si plusieurs profils existent (modèle type « qui regarde ? », à la Netflix)

### 2.4 Cloisonnement strict (règle transversale)

Cette règle s'applique à TOUTES les fonctionnalités, y compris la boutique, sans aucune exception :

- Un profil ne voit QUE le contenu de sa classe/série
- La classe du profil actif est toujours déduite automatiquement — jamais redemandée à l'élève dans les sous-fonctionnalités
- Pour ajouter une classe : bouton « Ajouter une classe » → nouveau profil + nouvel abonnement
- Pas de « changement de classe » sur un profil existant : un profil reste lié à sa classe jusqu'à archivage

### 2.5 Gestion des profils

- Suppression côté utilisateur = archivage (profil masqué côté utilisateur, données conservées en base)
- Réactivation possible

### 2.6 Passage de classe en fin d'année scolaire

L'abonnement annuel est lié à l'année scolaire officielle (ex : septembre à juin/juillet), jamais à une durée glissante de 365 jours à partir de la date de paiement. Cela empêche qu'un seul abonnement serve indéfiniment sur plusieurs années scolaires.

```
Fin d'année scolaire (date configurée par pays)
|
|-- CAS A — L'élève valide son passage en classe supérieure
|   |-- Nouveau profil créé pour la nouvelle classe (et nouvelle série si applicable)
|   |-- Nouvel abonnement requis pour cette nouvelle classe/année scolaire
|   |-- Progression/statistiques REMISES À ZÉRO pour la nouvelle classe
|   |-- L'ancien profil devient consultable via un bouton dédié « Historique / Ancienne classe »
|   |     → lecture seule : statistiques, scores, progression de l'année précédente
|   `-- Profil archivé mais consultable, pas supprimé
|
`-- CAS B — L'élève NE valide PAS de passage (redouble, ou ne confirme pas)
    |-- Le profil reste sur la MÊME classe
    |-- Toutes les informations de l'année précédente sont CONSERVÉES (historique visible)
    |-- La progression/statistiques de la nouvelle période sont REMISES À ZÉRO
    |-- Un NOUVEL abonnement est exigé pour la nouvelle année scolaire sur cette même classe
    `-- L'année scolaire affichée dans l'application se met à jour automatiquement
```

### 2.7 Affichage permanent du contexte temporel

- Date du jour et année scolaire en cours toujours visibles (ex : « Année scolaire 2026-2027 »)
- Compte à rebours vers l'examen officiel national du niveau du profil actif (ex : « Plus que 47 jours avant le BEPC »)
- Notifications renforcées autour des échéances (ouverture paiement, fin abonnement, campagne de passage de classe, countdown examens) — détail complet en section 6 (Partie 1)

### 2.8 Continuité en cas de changement d'établissement physique réel

Le profil est rattaché à une classe/série, jamais à un établissement physique précis (les établissements ne concernent que la fonctionnalité « Épreuves par établissement »). Un élève qui change d'école dans la vraie vie garde donc son compte, son profil, sa progression et son abonnement strictement intacts, sans aucune action requise.

## 3. Contenu pédagogique (2.2)

### 3.1 Structure (vue élève, navigation simple)

```
Matière
  `-- Chapitre
      |-- Introduction du chapitre (texte d'ouverture, avant les leçons)
      `-- Leçon(s)
          |-- Cours (texte + médias : image/vidéo/tout type de média)
          `-- Exercices de fin de leçon (liés à cette leçon précisément)
      `-- Exercices de fin de chapitre (synthèse, couvre l'ensemble des leçons)
```

### 3.2 Page Exercices — structure à trois niveaux d'indépendance

```
Exercices
  |-- Rattachés à une leçon précise (créés par enseignant et/ou générés par IA)
  |-- Rattachés à un chapitre, hors leçon précise (entraînement général, approfondissement)
  `-- Indépendants de tout chapitre/leçon (mélange de chapitres, type examen)
```

Navigation cohérente : chapitre → leçons → exercices de chaque leçon. Si pas de découpage en leçons, exercices directement au niveau du chapitre. Les exercices indépendants sont accessibles depuis la page Exercices générale.

### 3.3 Déblocage progressif par trimestre (mécanisme invisible)

- Seul le contenu déjà couvert (trimestres commencés + en cours) est visible
- Le contenu d'un trimestre futur reste invisible/verrouillé (pas de consultation, téléchargement, ni impression possible)
- Comportement **cumulatif** : rien ne disparaît au passage d'un trimestre à l'autre, le contenu s'additionne progressivement
- Déblocage entièrement automatique, basé sur la date du jour comparée au calendrier scolaire configuré par pays

### 3.4 Règles de gestion des exercices

- Type d'exercice : entraînement (correction visible directement) ou évaluation (correction débloquée après tentative)
- Modes de réponse configurables par épreuve : clavier/texte, QCM, réponse manuscrite sur tablette, écrit papier scanné/photographié, oral (audio ou vidéo)
- Chaque élément (cours, exercice, document) est rattaché à un palier d'abonnement minimum requis (voir section 6 — Modèle d'abonnement)
- Le contenu non accessible au palier actuel apparaît discrètement flouté/verrouillé, sans mention commerciale explicite permanente ; au clic, une proposition claire et précise du palier exact nécessaire s'affiche, avec bouton direct vers le paiement

### 3.5 Suivi de progression (détaillé)

- Pourcentage de leçons vues par chapitre/matière
- Score par exercice + historique complet des tentatives (pas seulement la dernière)
- Temps passé par session/leçon
- Nombre d'exercices/sujets traités vs disponibles
- Alimente : tableau de bord élève, module de révision intelligente, gamification

### 3.6 Protection documentaire (vue élève)

- Cours et exercices consultés prioritairement via un lecteur intégré sécurisé (anti-capture d'écran logiciel, anti-diffusion vers un second écran)
- Téléchargement PDF en option, avec filigrane visible + filigrane forensique invisible, limite de téléchargements côté serveur
- Détail technique complet en section Administration (Protection documentaire / DRM), §2.8

## 4. Examens officiels nationaux (2.3)

```
Examen officiel (BEPC=3e, Probatoire=1ère, Bac=Terminale — cas Cameroun)
  `-- Accès par Matière → liste des années disponibles
      OU
  `-- Accès par Année → liste des matières disponibles
      `-- Sujet (document)
          `-- Correction (masquée par défaut, débloquée après tentative)
```

- Filtrage strict par profil actif (un profil 3e ne voit jamais le Probatoire ou le Bac)
- Chaque examen officiel est lié à une classe précise de l'arbre académique du pays
- Un niveau sans examen officiel (ex : 6e, 5e, 4e) n'affiche simplement pas cette fonctionnalité

## 5. Épreuves par établissement (2.3bis)

Différence avec les examens officiels nationaux : épreuves internes propres à chaque établissement (devoirs, compositions, examens blancs internes), distinctes des sujets nationaux.

```
Page Épreuves par établissement
  `-- Choix du mode de filtrage par l'élève :
      OPTION A — Par établissement
        Établissement → Matière (classe déduite du profil) → Année → Sujet/Correction
      OPTION B — Par matière
        Matière → Établissement(s) → Année → Sujet/Correction
```

- Catalogue ouvert : tout élève peut consulter les épreuves de n'importe quel établissement, peu importe le sien
- La classe est toujours déduite du profil actif, jamais redemandée
- Un enseignant est rattaché à un ou plusieurs établissements ; il ne publie que sous le label de l'établissement concerné
- Création d'établissement réservée aux administrateurs uniquement (aucune délégation aux enseignants)

## 6. Modèle d'abonnement, paiement et cycle de vie complet (2.4)

**Diagramme d'état — cycle de vie d'un abonnement** : `Essai gratuit` → (premier paiement effectué) → `Payant actif` ⇄ `En cours de renouvellement` (paiement de renouvellement reçu / J-3/J-1 avant expiration) ; `Payant actif` → (cumul mensuel atteint → requalification) → boucle sur lui-même ; `Payant actif` → (expiration atteinte sans paiement) → `Gratuit permanent` ; `Essai gratuit` → (essai expire sans paiement) → `Gratuit permanent` ; `Gratuit permanent` → (nouveau paiement à tout moment) → `Payant actif`.

### 6.1 Principe général — système de paliers configurables

Il n'existe pas une simple règle binaire gratuit/payant. Chaque palier (Gratuit, Journalier, Hebdomadaire, Mensuel, Annuel) a son propre périmètre d'accès aux contenus et fonctionnalités, défini et modifiable par l'administration via une matrice de droits. Un abonnement court (jour/semaine) peut être volontairement plus restreint qu'un abonnement long, même si tous deux sont payants. Seul un palier suffisamment complet (typiquement mensuel/annuel, à définir par le porteur de projet) donne l'accès total.

**Hiérarchie des paliers** : Gratuit < Journalier < Hebdomadaire < Mensuel < Annuel

### 6.2 Mécanisme de cumul mensuel (limité strictement au palier Mensuel)

```
Compteur de dépense cumulée par profil, sur le mois calendaire en cours
  |-- Chaque paiement journalier/hebdomadaire s'additionne au compteur
  |-- Cumul atteint/dépasse le prix du Mensuel → requalification automatique « Mensuel »
  |     pour le reste du mois, débloque le contenu Mensuel, NOTIFICATION immédiate à l'élève
  |     (« Bonne nouvelle ! Vous avez maintenant accès à tout le contenu du mois »)
  |-- Compteur remis à zéro au mois suivant (le cumul ne se reporte pas indéfiniment)
  `-- Ne s'applique JAMAIS vers l'Annuel (l'Annuel reste un choix délibéré et dédié)
```

### 6.3 Cycle de vie complet d'un abonnement — détail du passage automatique au palier gratuit

C'est **le point central à bien spécifier** : l'expiration d'un abonnement payant n'est jamais silencieuse. Le système suit un cycle d'alertes progressives, puis un changement d'état automatique et notifié.

```
ÉTAT : Abonnement payant actif
|
|-- J-3 avant expiration → NOTIFICATION push + in-app + email/SMS si configuré
|     « Votre abonnement [Classe] se termine dans 3 jours. Renouvelez pour
|       garder l'accès complet. » + bouton direct de renouvellement
|
|-- J-1 avant expiration → NOTIFICATION de rappel renforcée (même canal + bannière
|     persistante dans l'application tant que non renouvelé)
|
|-- JOUR J (expiration effective, à minuit selon le calendrier de l'abonnement)
|   |-- Le système repasse AUTOMATIQUEMENT le profil au palier « Gratuit permanent »
|   |-- NOTIFICATION immédiate et explicite à l'ouverture suivante de l'application :
|   |     « Votre abonnement a expiré. Vous êtes maintenant en accès gratuit.
|   |       Réabonnez-vous pour retrouver l'accès complet à [Classe]. »
|   |-- Un écran dédié (pas juste une notification discrète) résume :
|   |     - ce qui reste accessible au palier gratuit
|   |     - ce qui devient inaccessible (flouté, avec rappel du palier nécessaire)
|   |     - bouton de réabonnement immédiat
|   |-- La progression, l'historique, les scores, les badges restent CONSERVÉS et
|   |     visibles (lecture seule pour les parties non incluses au palier gratuit)
|   `-- Le contenu publicitaire (cf. section 6.6) s'active à partir de cet instant
|
`-- APRÈS expiration (relances de réactivation)
    |-- J+1, J+7, J+30 → notifications de relance espacées, non intrusives
    |     (pas de spam quotidien — fréquence dégressive)
    `-- Si réabonnement → retour immédiat à l'état « Abonnement payant actif »,
          notification de confirmation, progression reprise exactement où elle était
```

### 6.4 Catalogue des notifications liées à l'abonnement (résumé)

| Déclencheur | Canal(aux) | Contenu |
|---|---|---|
| J-3 avant expiration | Push + in-app | Rappel avec bouton de renouvellement |
| J-1 avant expiration | Push + in-app (bannière persistante) | Rappel renforcé |
| Jour J — expiration effective | Push + in-app (écran dédié) | Confirmation du passage au gratuit, récapitulatif des accès perdus |
| Cumul mensuel atteint | In-app | Confirmation de la requalification Mensuel automatique |
| Après relance J+1 / J+7 / J+30 | Push | Incitation au réabonnement, fréquence dégressive |
| Paiement Mobile Money en échec/ambigu | In-app + ticket support automatique | Information à l'élève + file de réconciliation côté admin |
| Campagne de passage de classe ouverte | Push + in-app | Invitation à confirmer le passage en classe supérieure |
| Remboursement accepté/refusé | In-app + email | Notification de la décision avec motif |

Ce catalogue est entièrement géré et personnalisable depuis l'application Administration (templates de notification, déclencheurs, canaux — voir partie Administration, section 15 Paramètres système).

### 6.5 Paiement

- Mobile Money obligatoire : Orange Money + MTN MoMo
- Carte bancaire en complément (utile pour la diaspora)
- Agrégateur de paiement (ex : Monetbil, Notch Pay, Campay) plutôt qu'une connexion directe aux opérateurs télécoms — voir justification détaillée dans la Partie 3
- Historique de facturation consultable dans le profil
- Réconciliation manuelle prévue côté administration pour les paiements en statut ambigu (débité côté opérateur mais non confirmé côté application, ou inversement)

### 6.6 Publicité (palier gratuit uniquement)

- Affichée uniquement sur le palier gratuit permanent — jamais en abonnement payant, jamais pendant l'essai gratuit initial
- Réseau publicitaire automatisé (type Google AdMob) en complément de partenariats directs négociés (marques locales, opérateurs Mobile Money, acteurs éducatifs)
- Emplacements en bannières uniquement — pas d'interstitiels intrusifs entre deux exercices, pour préserver l'expérience d'apprentissage
- Filtrage strict pour public mineur (catégories interdites : alcool, jeux d'argent, contenu adulte)

### 6.7 Parrainage

- Code/lien personnel généré par l'élève
- Un nouvel inscrit qui utilise ce code → récompense au parrain ET au parrainé (jours d'abonnement offerts, ou réduction sur le prochain abonnement)
- Suivi du nombre de parrainages réussis par utilisateur, gestion des abus (faux comptes)

### 6.8 Politique de remboursement (trois cas distincts)

| Cas | Délai de recevabilité | Traitement |
|---|---|---|
| Erreur technique prouvée (double facturation, paiement débité sans accès accordé) | 30 jours | Quasi automatique une fois l'erreur confirmée par la réconciliation |
| Insatisfaction simple (changement d'avis) | 48 heures après paiement, et seulement si le contenu n'a pas été significativement consommé | Étude au cas par cas |
| Changement de situation (déménagement, abandon scolaire) | 14 jours après l'événement, preuve raisonnable demandée | Remboursement partiel possible (prorata du temps non consommé) |

Décision (acceptée/refusée avec motif obligatoire dans les deux cas) prise par le Super-administrateur ou un administrateur explicitement mandaté selon le montant et le cas. Remboursement exécuté via le même canal que le paiement initial.

## 7. Inscription et authentification (2.5)

### 7.1 Parcours d'inscription (wizard multi-étapes)

| Étape | Contenu |
|---|---|
| 1 | Identité (nom, prénom, email, mot de passe) |
| 2 | Téléphone + vérification OTP |
| 3 | Pays |
| 4 | Section / Type d'enseignement / Classe / Série |
| 5 | Photo de profil (optionnelle, peut être ajoutée plus tard) |
| 6 | Choix de l'abonnement ou activation de l'essai gratuit |
| 7 | Paiement (si pas d'essai gratuit choisi) |

- Barre de progression visible (« Étape 3/7 »)
- Navigation avant/arrière possible sans perte de données déjà saisies
- Reprise possible en cas d'abandon en cours de route (pas de re-saisie complète)
- Pas de consentement parental requis à l'inscription (décision ferme du porteur de projet)

### 7.2 Guide d'onboarding après la première connexion

- Court guide interactif expliquant la navigation principale, le fonctionnement des profils (1 profil = 1 classe = 1 abonnement), le principe de l'abonnement/palier gratuit, la présentation de l'IA/forum/fonctionnalités clés
- Peut être passé à tout moment par l'élève qui préfère explorer seul
- Réactivable après une mise à jour majeure de l'application

### 7.3 Authentification multi-niveaux

- Email + mot de passe
- Vérification email obligatoire
- Vérification téléphone par OTP/SMS
- Authentification à deux facteurs (2FA), optionnelle pour les élèves
- Biométrie locale mobile (empreinte digitale / Face ID)

### 7.4 Session unique stricte (anti-partage de compte)

- Un seul accès actif à la fois, toutes plateformes confondues (mobile OU web, jamais les deux simultanément)
- Nouvelle connexion détectée → déconnexion immédiate et automatique de l'ancienne session, avec message explicite : « Compte utilisé sur un autre appareil — reconnectez-vous pour reprendre l'accès »
- Aucune exception (pas de mode « appareil secondaire » type WhatsApp Web)
- Ce mécanisme répond directement à la préoccupation de partage de compte entre plusieurs familles, sans recourir à la géolocalisation (écartée pour des raisons légales et de fiabilité technique sur public mineur)

## 8. Forum (2.6)

```
Forum
  `-- Espace par classe du profil actif (cloisonné)
      |-- Sous-espace par matière
      `-- Sous-espace « vie scolaire / général »
```

- Filtrage automatique (mots-clés ou moteur IA), bouton « signaler » sur chaque message
- File de modération humaine côté administration
- Rôle « modérateur » dédié, distinct de « admin »

## 9. Messagerie / Contact administration (2.7)

```
Ticket
  |-- Catégorie (paiement / technique / contenu / autre)
  |-- Objet + description
  |-- Statut (ouvert / en cours / répondu / fermé)
  |-- Pièce jointe possible (capture d'écran, ex : bug)
  `-- Fil de réponses (utilisateur ↔ admin)
```

- Tickets identifiés séparément selon qu'ils viennent de l'élève ou du parent
- Notification à l'utilisateur à chaque réponse

## 10. Assistant Intelligence Artificielle (2.8)

```
Assistant IA
  |-- Tuteur : explique un point de cours, reformule, donne des exemples contextualisés
  |-- Génération d'exercices/quiz personnalisés (basés sur les points faibles du profil)
  `-- Feedback/correction sur réponses (explique l'erreur, pas juste « faux »)
```

- Contexte fourni à l'IA : pays/classe/série/matière du profil actif
- Priorité au programme du profil, sans bloquer totalement le hors-programme
- Modération stricte des entrées/sorties (public mineur)
- Positionnement comme outil d'aide, jamais comme autorité absolue
- Accès selon le palier d'abonnement actif (matrice de droits)

## 11. Paramètres (2.10) et Accessibilité (2.10bis)

### 11.1 Paramètres

- Notifications (activer/désactiver par type, cf. catalogue section 6.4)
- Langue de l'interface (français/anglais) — distincte de la langue du contenu pédagogique, qui dépend de la section académique, jamais d'une traduction automatique
- Gestion des profils (liste, ajout, archivage)
- Informations du compte (email, mot de passe, téléphone)
- Confidentialité (visibilité sur le forum)
- Gestion du stockage hors-ligne (voir/supprimer le cache)
- Apparence : mode clair / sombre / automatique (suit les réglages système)
- Déconnexion / suppression de compte
- Demande de suppression/export de données personnelles (droit à l'oubli)

### 11.2 Accessibilité

- Taille de police ajustable
- Contraste élevé (option dédiée, distincte du mode sombre)
- Compatibilité avec les lecteurs d'écran natifs (VoiceOver iOS, TalkBack Android) — intégrée dès la conception
- Sous-titres disponibles sur tout contenu vidéo de cours
- Navigation complète possible au clavier sur la version web

## 12. Soutien / Dons (2.11)

```
Page Soutien
  |-- Soutenir l'application (don libre, montant libre, Mobile Money/carte)
  `-- Soutenir une œuvre caritative externe (liste de causes, objectif de collecte, montant atteint)
```

Reçu de don généré automatiquement.

## 13. Examens blancs et Olympiades (2.12)

```
Événement (examen_blanc / olympiade)
  |-- Pays / Classe / Matière(s) concernées
  |-- Date(s) d'ouverture / fermeture de participation
  |-- Tarif (inclus abonnement pour examens blancs / payant séparément pour olympiades)
  |-- Épreuve(s)
  |   |-- QCM/numérique → notation automatique, résultat immédiat
  |   `-- Rédaction/oral → correction humaine, résultat différé
  `-- Résultats
      |-- Note individuelle (toujours visible)
      `-- Classement
          |-- Olympiade → rang exact, palmarès
          `-- Examen blanc → tranche/percentile (préserve les élèves en difficulté)
```

### 13.1 Modalités de composition étendues

| Mode | Description | Type de correction |
|---|---|---|
| Écrit numérique | Clavier/texte direct dans l'app | Automatique possible |
| Écrit manuscrit tablette | Capture via stylet/écran tactile | Humaine |
| Écrit papier scanné/photographié | Composition sur papier, photo envoyée depuis l'app, qualité minimale requise | Humaine |
| QCM mobile | Réponse courte sans calcul lourd | Automatique |
| Oral | Enregistrement audio ou vidéo, durée max configurable | Humaine |

### 13.2 Contestation de note

```
Réclamation de note
  |-- Déclenchée depuis la page de résultats, délai limité après publication
  |-- Motif obligatoire
  |-- Transmise au correcteur d'origine ou à un second correcteur
  |-- Décision : note maintenue / note révisée, motif communiqué
  `-- Statut suivi via le système de tickets (catégorie dédiée)
```

## 14. Gamification (2.13)

```
Système de récompenses (basé sur le suivi de progression existant)
  |-- Badges (chapitre terminé, série de bonnes réponses, régularité...)
  |-- Streak (jours consécutifs d'activité)
  `-- Points d'expérience cumulés (visibles dans le profil)
```

## 15. Révision intelligente espacée (2.14)

```
Module de révision adaptative (extension de l'Assistant IA)
  |-- Analyse des points faibles (basée sur le suivi de progression)
  |-- Planification automatique à intervalles croissants (répétition espacée)
  `-- Notifications ciblées (« Tu n'as pas revu les fractions depuis 5 jours »)
```

## 16. Communautés d'étude — WhatsApp (2.15)

```
Communauté WhatsApp officielle
  |-- Créée et gérée par l'admin pays (jamais par les élèves)
  |-- Une communauté = une classe précise (cloisonnement strict)
  `-- Accès via lien d'invitation affiché dans l'app, filtré par profil actif
```

MVP sur WhatsApp (adoption locale maximale). Évolution possible vers Telegram si la modération/scale devient difficile à gérer manuellement.

## 17. Espace parent (2.16)

```
Compte parent (identité propre, créé séparément du compte élève)
  |-- Lié à un ou plusieurs profils élève
  |-- Accès complet : contenu, progression, scores, IA, forum, communautés
  |-- Gestion de l'abonnement et des paiements (si payeur)
  `-- Communication propre avec l'administration (tickets identifiés « parent »)
```

- Navigation « en tant que » l'élève possible sur le même appareil sans réauthentification constante
- Les actions sensibles (paiement, contact admin) restent toujours attribuées au compte parent

## 18. Synchronisation hors-ligne intelligente (2.17)

```
Téléchargement automatique du contenu
  |-- Déclenché dès connexion détectée
  |-- Priorité : programme du trimestre en cours du profil actif
  |-- Secondaire : exercices liés, anciens sujets du niveau du profil
  `-- Gestion du stockage configurable (Paramètres)
```

## 19. Rappels d'échéances d'examens officiels (2.18)

```
Notification programmée
  |-- Basée sur le calendrier officiel du pays (maintenu par l'admin pays)
  |-- Intervalles : J-60, J-30, J-7
  `-- Lien direct vers le module de révision intelligente
```

## 20. Architecture de navigation (2.19)

| Groupe | Pages incluses |
|---|---|
| Mon espace | Accueil, Profil, Paramètres, Espace parent |
| Apprentissage | Cours, Exercices, Assistant IA |
| Évaluation | Examens officiels, Épreuves par établissement, Examens blancs & Olympiades |
| Communauté | Forum, Communautés d'étude (WhatsApp) |
| Services | Boutique, Soutien/Dons |
| Support | Messagerie / Tickets |

## 21. Exigences non-fonctionnelles

- Multiplateforme : Web (PWA installable), Android, iOS — Application Administration séparée
- Mode hors-ligne : synchronisation intelligente et progressive
- Performance : adaptée aux contraintes de connectivité variables (réseau faible/instable fréquent)
- Sécurité : authentification multi-niveaux, session unique stricte, protection documentaire (DRM), modération stricte
- Scalabilité : architecture pensée pour extension multi-pays après le MVP Cameroun
- Conformité : droit à l'oubli, portabilité des données, sans consentement parental obligatoire
- Accessibilité : intégrée dès la conception

## 22. Roadmap

| Phase | Contenu |
|---|---|
| MVP | Structure académique, contenu pédagogique de base, examens officiels, modèle d'abonnement avec matrice de droits de base, inscription/authentification, App Administration version de base |
| Phase 2 | Épreuves par établissement, forum, gamification, communautés WhatsApp, synchronisation hors-ligne |
| Phase 3 | Assistant IA, examens blancs/olympiades, révision intelligente, dons |

---

# PARTIE 2 — APPLICATION ADMINISTRATION

## Préambule : architecture base de données

**Décision** : une seule base de données, partagée entre l'application élève et l'application admin, sécurisée par :

- Row Level Security (RLS) au niveau base de données — permissions strictes par rôle
- Deux applications/API distinctes — l'admin n'est pas une simple page cachée de l'app élève
- Authentification renforcée obligatoire côté admin (2FA non-optionnelle)
- Journalisation complète de toutes les actions admin (traçabilité)
- Environnements séparés dev/staging/production

Justification : éviter la duplication/synchronisation permanente de contenu et de données de progression entre deux bases séparées, tout en garantissant un cloisonnement de sécurité réel via les permissions au niveau base de données plutôt qu'au seul niveau applicatif.

## 1. Gestion de l'arbre académique

Principe directeur : pour chaque entité de l'arbre, l'admin dispose de l'intégralité des opérations suivantes, pas seulement créer/modifier/supprimer : **Créer, Lire/consulter, Modifier, Désactiver, Réactiver, Supprimer définitivement, Dupliquer, Déplacer/rattacher à un autre parent, Lier/délier à d'autres entités, Voir l'historique des modifications, Voir les dépendances avant suppression.**

### 1.1 Gestion des pays

Créer, consulter (vue d'ensemble : nombre de sections, classes, élèves actifs, enseignants), modifier (nom, langues officielles, devise, calendrier scolaire officiel), désactiver/réactiver, supprimer définitivement (action critique réservée au super-admin, double confirmation), dupliquer la structure comme point de départ pour un nouveau pays, visualiser l'arbre complet, historique des modifications.

### 1.2 Gestion des sections

Créer une section au sein d'un pays (ex : Anglophone, Francophone, Bilingue), consulter/modifier/désactiver/réactiver/supprimer, dupliquer/déplacer vers un autre pays, historique. Un pays peut n'avoir aucune section si non pertinent.

### 1.3 Gestion des types d'enseignement

Créer/consulter/modifier/désactiver/réactiver/supprimer, dupliquer/déplacer vers une autre section, historique.

### 1.4 Gestion des classes

Créer/consulter/modifier/désactiver/réactiver/supprimer, associer/retirer un examen officiel national lié à une classe, dupliquer/déplacer, lier deux ou plusieurs classes entre elles quand elles partagent des matières communes, délier des classes précédemment liées, fusionner deux classes en une seule (migration des profils élève concernés), voir le nombre d'élèves actifs/séries/matières rattachées avant suppression/fusion, historique.

### 1.5 Gestion des matières et de leur portée (lien classe ↔ matière)

- Une matière peut être associée à une seule classe (contenu propre à cette classe)
- Une matière peut être associée à un groupe de classes liées entre elles — le contenu est alors unique et partagé par toutes les classes du groupe, sans duplication
- Si une classe est retirée d'un groupe lié, ses élèves perdent l'accès au contenu partagé sauf réassociation individuelle
- Toute modification du contenu d'une matière partagée s'applique simultanément à toutes les classes liées concernées

### 1.6 Gestion des séries

Créer une série au sein d'une classe (C, A4, TI, D...), consulter/modifier/désactiver/réactiver/supprimer, dupliquer/déplacer, définir/modifier les matières applicables, historique.

### 1.7 Règles de cascade et d'intégrité

- Impossible de créer un niveau enfant sans son parent ; interface guidée proposant uniquement les options valides
- Affichage systématique des dépendances avant suppression
- Suppression : blocage par défaut, cascade disponible en option explicite (case à cocher explicite « supprimer aussi tout le contenu lié »)
- Vérification de cohérence automatique après déplacement/fusion/liaison
- Toutes les opérations journalisées (audit log, section 13)

### 1.8 Découpage temporel par trimestre (mécanisme back-end, invisible côté élève)

Structure de configuration (admin uniquement) :

```
Classe/Série → Trimestre (dates définies par pays/année scolaire) → Matière → Chapitre → Leçon
```

Ce que l'élève voit réellement (navigation inchangée) :

```
Matière → Chapitre (visible si trimestre commencé) → Leçon
```

- L'élève ne voit jamais le mot « Trimestre » — navigation simple Matière → Chapitre → Leçon
- Comportement cumulatif : le contenu déjà débloqué reste toujours visible, seul le contenu futur reste verrouillé
- Déblocage entièrement automatique selon la date du jour vs calendrier configuré ; réactualisation automatique chaque année scolaire
- L'admin peut forcer un déblocage anticipé exceptionnel (ex : avance pédagogique décidée par un établissement)
- Objectif : empêcher l'accès anticipé à tout le programme (anti-piratage) et respecter le rythme pédagogique réel

## 2. Gestion du contenu pédagogique

### 2.1 Matières

Créer/modifier/supprimer, associer à une ou plusieurs classes/séries (cf. règle 1.5).

### 2.2 Chapitres

Créer/modifier/supprimer, rédiger l'introduction du chapitre, réordonner les chapitres, rattachement à un trimestre (1.8).

### 2.3 Leçons

Créer/modifier/supprimer, éditeur de contenu (texte enrichi, médias : image/vidéo/audio/PDF/document, formules mathématiques/scientifiques), réordonner les leçons.

### 2.4 Gestion des exercices et structure de la page Exercices

Structure à trois niveaux d'indépendance :

```
Exercices
  |-- Rattachés à une leçon précise (enseignant et/ou IA)
  |-- Rattachés à un chapitre, hors leçon précise (entraînement général, approfondissement)
  `-- Indépendants de tout chapitre/leçon (mélange de chapitres, type examen)
```

Création/modification/suppression, rattachement, type (entraînement/évaluation), niveau de difficulté (simple/intermédiaire/approfondissement), format (QCM, réponse courte/numérique, rédaction, réponse manuscrite, texte à trous, flashcard), rédaction énoncé + correction, réordonner. Palier d'abonnement minimum requis assigné à chaque exercice.

### 2.5 Workflow de validation du contenu

**Diagramme d'état — cycle de vie d'un contenu pédagogique** :
`Brouillon` → (enseignant soumet) → `En attente de validation` → (admin approuve) → `Publié` → (nouvelle version publiée) → `Archivé (nouvelle version)` ; `En attente de validation` → (admin rejette, motif) → `À corriger` → (enseignant corrige et resoumet) → `En attente de validation` ; `Publié` → (enseignant modifie, nouvelle version) → `En attente de validation`.

```
Enseignant/Admin contenu crée → statut « en attente de validation »
  `-- Pré-analyse automatique par IA (orthographe, cohérence, conformité au template)
      `-- Admin pays (ou rôle habilité) review →
          |-- Approuvé → statut « publié », visible aux élèves
          |-- Rejeté → retour à l'auteur avec motif, statut « à corriger »
          `-- Modifié puis approuvé directement
```

File d'attente avec rapport de pré-analyse IA joint, historique des validations, notifications automatiques à l'auteur.

### 2.6 Versioning du contenu après publication

- Toute modification d'un contenu déjà publié crée une nouvelle version (pas d'écrasement silencieux)
- Historique complet consultable (qui, quand, quoi)
- Repasse par le workflow de validation avant remplacement de la version visible
- Retour à une version antérieure possible en cas d'erreur
- Le PDF déjà téléchargé par un élève n'est pas modifié rétroactivement ; seul le contenu en ligne reflète la version la plus récente

### 2.7 Gestion des médias

Bibliothèque centralisée réutilisable entre leçons, vérification taille/format des fichiers.

### 2.8 Protection documentaire (DRM) — cours, exercices, sujets, documents boutique

Principe directeur : combiner blocage technique réel (là où c'est possible) et traçabilité forensique (pour les cas où le blocage physique est impossible), plutôt que de promettre une protection à 100 % qui n'existe nulle part dans l'industrie.

**Mode lecteur intégré** (par défaut, recommandé pour tout contenu sensible) :

- Chiffrement + rendu sécurisé via DRM matériel (type Widevine L1, ou équivalent type DRM-X)
- Blocage réel de l'enregistrement d'écran logiciel (écran noir produit par les outils d'enregistrement)
- Blocage de la diffusion vers un second écran (AirPlay, Miracast, HDMI externe, projecteur)
- Liaison appareil-licence (device binding)
- Filigrane dynamique plein écran (nom, email, ID utilisateur)
- Pas de fonction d'impression ni de copier-coller dans ce mode

**Mode téléchargement PDF** (optionnel, présenté comme moins protégé) :

- Filigrane visible (nom, email, téléphone, logo, lien plateforme) sur chaque page
- **Filigrane forensique invisible**, intégré dans les pixels/le texte : résiste à la photo, au scan, à la photocopie ; permet d'identifier la source d'une fuite a posteriori
- PDF protégé par mot de passe lié au compte
- Limite de téléchargements comptée côté serveur (configurable)

**Limites techniques reconnues (transparence nécessaire)** :

- Aucune technologie ne peut empêcher un appareil photo/caméra externe de filmer physiquement un écran — seule la traçabilité forensique s'applique alors
- Aucune technologie ne peut empêcher la photocopie d'un document déjà imprimé sur papier — seule la traçabilité forensique s'applique alors
- Ces deux cas restent peu praticables à grande échelle pour un fraudeur (qualité dégradée, geste lent et visible, risque d'identification élevé)

**Implication budgétaire** : coûts de licence et intégration technique non triviale (Widevine, DRM-X ou équivalents) — à chiffrer en phase technique, possiblement priorisé sur le contenu le plus sensible/monétisé (boutique, sujets d'examens) plutôt que sur l'intégralité du contenu dès le MVP.

**Administration de cette protection** : activer/désactiver le mode protégé par type de contenu, configurer la limite de téléchargement, consulter le journal des téléchargements par utilisateur/document, extraire et consulter le filigrane forensique d'un document suspecté d'avoir fuité, suspendre un compte identifié comme source d'une fuite.

## 3. Gestion des examens officiels nationaux

Créer/modifier/supprimer un examen officiel et l'associer à une classe ; par année/matière : upload sujet + correction, visibilité de la correction ; définir/modifier les dates clés du calendrier officiel (alimente les rappels côté élève et le countdown).

## 4. Gestion des établissements et épreuves

### 4.1 Gestion des établissements

Créer/modifier/désactiver un établissement (nom, pays, ville/région), lister les enseignants rattachés. **Création réservée exclusivement aux administrateurs** — aucune délégation aux enseignants, qui ne peuvent que demander leur rattachement à un établissement existant.

### 4.2 Gestion des épreuves d'établissement

Créer/modifier/supprimer une épreuve (classe, matière, année, sujet, correction), soumis au workflow de validation.

## 5. Gestion des comptes et profils

### 5.1 Comptes élève

Rechercher (nom, email, téléphone, classe), voir le détail complet (infos, profils, connexions, paiements), modifier les informations, suspendre/réactiver/supprimer définitivement, réinitialiser mot de passe/forcer déconnexion.

### 5.2 Profils élève

Voir tous les profils d'un compte, modifier manuellement un profil, archiver/réactiver/supprimer définitivement, voir l'historique de progression détaillé, transférer un profil d'un compte à un autre.

### 5.3 Comptes parent

Rechercher, voir les profils liés, modifier/suspendre/réactiver/supprimer, gérer manuellement la liaison parent ↔ élève.

### 5.4 Comptes enseignant

File des demandes en attente, valider/rejeter/demander un complément, voir les enseignants actifs et leur périmètre (multi-établissements, cf. section 22), modifier le périmètre, suspendre/réactiver/révoquer définitivement.

## 6. Gestion des abonnements et paiements

> **Règle de confidentialité financière stricte** : l'ensemble des données financières (revenus, montants, statistiques de paiement, chiffre d'affaires) n'est visible que par le Super-administrateur. Aucun autre rôle n'y a accès, même en lecture, sans exception.

### 6.1 Grille tarifaire, matrice de droits et logique d'héritage

Chaque élément de l'application (cours, leçon, exercice, document boutique, fonctionnalité — absolument tout) est rattaché à un palier d'abonnement minimum requis.

**Règle d'assignation par défaut** :

```
Création d'un élément
  `-- Par défaut → palier « Gratuit »
      |-- Si l'admin ne sélectionne rien → reste Gratuit
      |-- Si l'admin clique « Payant » sans précision → équivaut à « Journalier »
      |     et hérite vers le haut (Journalier, Hebdomadaire, Mensuel, Annuel tous accès)
      `-- Si l'admin choisit explicitement un palier supérieur (ex : « Mensuel »)
            → seuls Mensuel et Annuel y donnent accès (pas d'héritage descendant)
```

Hiérarchie des paliers : Gratuit < Journalier < Hebdomadaire < Mensuel < Annuel.

Mécanisme de cumul limité strictement au palier Mensuel (détaillé dans la Partie 1, section 6.2).

**Matrice de droits** : lignes = chaque palier, colonnes = chaque fonctionnalité/contenu (cours, exercices, examens officiels, épreuves établissement, événements, hors-ligne, boutique, publicité, IA, forum, communautés...), cellule = accès complet / accès limité (avec paramètre) / aucun accès. Tarifs par niveau scolaire × durée, modifiables à tout moment (historique conservé). Modification appliquée immédiatement, avec notification si l'accès d'un profil change. Accès à cette configuration : Super-admin par défaut, délégable explicitement.

### 6.1bis Floutage et incitation à l'abonnement

Un élément non accessible ne doit jamais afficher de mention explicite (« ceci nécessite l'abonnement payant ») en navigation passive. Mécanismes configurables : flou visuel progressif, aperçu partiel, compteur discret (« + 20 exercices »), verrou visuel discret.

Au clic sur un élément flouté/verrouillé :

```
Clic → Affichage contextuel précis :
  « Ce contenu fait partie de l'abonnement [palier exact requis] — débloquez-le maintenant »
  |-- Bouton direct vers le paiement du palier exact requis pour CET élément
  |-- Rappel du prix correspondant
  `-- Retour possible sans obligation de payer (pas de blocage forcé de la navigation)
```

Statistiques de conversion (taux de clic, taux de conversion clic→abonnement, comparaison d'efficacité entre mécanismes) — accès Super-admin uniquement.

### 6.2 Suivi des transactions

Liste complète, filtrage par statut, détail, export comptable. Montants : Super-admin uniquement.

### 6.3 Gestion des abonnements actifs

Vue d'ensemble (sans montants pour les autres rôles), forcer prolongation/annulation, statistiques de renouvellement en %.

### 6.4 Codes promotionnels / parrainage

Créer/désactiver, suivre l'utilisation.

## 7. Gestion de la boutique

Ajouter/modifier/retirer un document, associé à une classe précise (cloisonnement strict), définir et modifier le prix à tout moment, suivre les ventes (montants réservés au Super-admin), gérer la protection DRM si applicable.

## 8. Gestion du forum

Vue d'ensemble par pays/classe/matière, file des signalements (voir en contexte, supprimer/avertir/suspendre l'auteur), gérer les mots-clés filtrés automatiquement ou le moteur de détection IA, statistiques d'activité.

## 9. Gestion des communautés d'étude (WhatsApp)

Créer une communauté/groupe WhatsApp et l'associer à une classe précise (lien d'invitation), modifier/désactiver un lien, vue d'ensemble par pays/classe. Suivi du nombre de membres : saisie manuelle et approximative par l'admin (pas d'API de comptage fiable côté WhatsApp).

## 10. Gestion des tickets de support

File de tous les tickets (élève/parent distingués), filtrage, assignation, réponse directe, statistiques (temps de réponse, volume).

## 11. Gestion des examens blancs et Olympiades

Créer un événement (type, pays, classe(s), matière(s), dates, tarif), ajouter les épreuves, interface de correction humaine (assignation, saisie des notes, incluant oral/manuscrit), publier les résultats, générer le classement, statistiques de participation.

## 12. Gestion des dons / soutien

Historique des dons, gestion des œuvres caritatives affichées, suivi de la collecte, génération automatique des reçus.

## 13. Gestion des rôles et permissions

Principe directeur : le Super-admin dispose d'un pouvoir total. Rôles fixes prédéfinis pour le MVP, périmètre toujours ajustable, architecture pensée pour évoluer vers le granulaire plus tard sans refonte complète.

### 13.1 Gestion des comptes administrateurs

Créer, consulter la liste, modifier, suspendre/réactiver, supprimer définitivement (réservé super-admin), forcer déconnexion/réinitialisation mot de passe/2FA.

### 13.2 Attribution des pouvoirs (rôles fixes pour le MVP)

- Attribution d'un rôle fixe (super-admin, admin pays, admin contenu, enseignant, modérateur, support)
- **Permissions par défaut, ajustables ensuite** : à la nomination, un ensemble d'actions est présélectionné selon le rôle ; le Super-admin peut ajouter ou retirer des actions spécifiques à tout moment, sans changer le rôle global
- Périmètre personnalisable (pays/classes/matières/établissements)
- Date d'expiration automatique des droits possible (accès temporaire)
- Duplication du profil de permissions d'un administrateur existant
- Architecture interne en permissions nommées (évolutif vers granulaire sans refonte)

### 13.3 Gestion des validations d'utilisateurs

Valider/rejeter inscriptions enseignant, créations d'établissement, et tout futur type de demande nécessitant approbation.

### 13.4 Gestion directe des comptes utilisateurs

Le Super-admin peut créer, ajouter ou supprimer n'importe quel utilisateur — pouvoir total et sans restriction. Validation manuelle exceptionnelle, suspension/réactivation, suppression définitive. Pouvoirs configurables par rôle (ex : support suspend mais ne supprime pas).

### 13.5 Audit, traçabilité totale et accès base de données direct

- Historique complet par administrateur, filtrable, sans exception
- **Toute suppression effectuée par n'importe quel administrateur doit être retrouvable et consultable par le Super-admin** — aucune suppression n'est anonyme ou invisible à ses yeux
- Alertes automatiques sur actions sensibles (suppression de pays, suppression en masse)
- Export de l'audit log
- **Accès direct à la base de données** depuis l'application admin, réservé exclusivement au Super-admin : capacité technique de consultation/correction/intervention exceptionnelle, intégrée à l'app admin, jamais délégable même temporairement

### 13.6 Hiérarchie et délégation

Délégation de second niveau possible (ex : admin pays gère les enseignants/modérateurs de son pays). Un administrateur ne peut jamais s'auto-attribuer des pouvoirs supérieurs. Le super-admin garde toujours la visibilité et le contrôle total sur toute délégation.

## 14. Statistiques et tableaux de bord globaux

- **Visibles par tous les rôles habilités** (sans données financières) : utilisateurs actifs, taux de renouvellement (%), contenu le plus/moins consulté, taux de réussite moyen, activité forum/support
- **Visibles par le Super-admin uniquement** : revenus, chiffre d'affaires global et par segment, export financier complet, coûts des agents IA, statistiques de conversion du floutage

## 15. Paramètres système

### 15.1 Personnalisation de l'interface

Thème visuel (couleurs, logo, polices), possibilité d'imposer une charte différente par pays, activer/désactiver des modules de navigation par pays, gestion des textes/libellés (multilingue) sans nouveau déploiement, prévisualisation avant publication.

### 15.2 Notifications et signaux système

- Templates de notification (email/push/SMS) par type d'événement
- Déclencheurs automatiques configurables (catalogue complet en Partie 1, section 6.4 — expiration abonnement, cumul mensuel, relances, réconciliation paiement, campagne de passage de classe, remboursement)
- Envoi manuel ciblé (annonce à un pays/classe)
- Historique et taux d'ouverture si mesurable
- Signaux internes (alertes incidents techniques, pics d'erreurs, tentatives de fraude détectées)

### 15.3 Gestion des langues disponibles

Ajouter/retirer une langue (élève et admin), gérer les traductions de l'interface uniquement (distinct du contenu pédagogique, cf. section 30).

### 15.4 Configuration technique

Agrégateur de paiement (clés API, environnements), logs système, historique des incidents, sauvegardes base de données.

## 16. Intelligence artificielle côté administration

Principe directeur : l'IA assiste les tâches répétitives ou de premier niveau ; la décision finale sur la publication de contenu reste toujours humaine. L'administration héberge l'ensemble des agents IA — elle concentre la complexité technique, l'application élève ne fait que consommer le résultat.

### 16.0 Catalogage exhaustif des éléments par matière

Constat fondateur : chaque matière a sa propre structure d'éléments pédagogiques. Travail préalable indispensable, mené par l'équipe pédagogique, avant toute construction de template — l'IA ne peut classer correctement que si on lui donne d'abord les catégories qui existent.

**Proposition de catalogue de départ (à compléter avec les enseignants)** :

| Matière | Types d'éléments pédagogiques |
|---|---|
| Mathématiques | Définition, propriété, théorème, démonstration, exemple, méthode, exercice d'application, exercice d'approfondissement |
| Français | Texte support, biographie d'auteur, notion grammaticale, figure de style, méthodologie (dissertation/commentaire), exercice de langue |
| Physique-Chimie | Définition, loi, formule, expérience/protocole, schéma, application numérique, exercice |
| SVT | Définition, schéma annoté, observation, expérience, synthèse, exercice |
| Histoire-Géographie | Repère chronologique, document source, carte, biographie, synthèse, exercice |
| Langues vivantes | Vocabulaire, règle de grammaire, dialogue type, exercice de compréhension, exercice d'expression |

**Gestion du catalogue** (interface admin dédiée) : créer/modifier un type d'élément pour une matière, désactiver/réactiver (sans casser le contenu existant), supprimer définitivement (si aucune dépendance), historique des modifications, duplication d'un catalogue existant vers une matière proche. Accès : Super-admin et Admin contenu (selon délégation).

### 16.1 Pipeline de traitement d'un cours uploadé

```
Upload (texte/PDF/photo/scan)
  → 1. Identification de la matière
  → 2. Découpage et association aux éléments du catalogue (16.0)
  → 3. Génération du rendu template (ordinateur/tablette/mobile/projecteur)
  → 4. Génération SIMULTANÉE d'un PDF téléchargeable
```

- OCR pour les photos/scans manuscrits (vérification humaine renforcée, risque d'erreur plus élevé)
- Détection des éléments manquants par l'IA (pas d'introduction, pas d'exemple, pas de difficulté assignée) avec proposition de complément, toujours soumise à validation humaine
- Décision de publication toujours humaine — l'IA ne publie jamais seule
- Cohérence visuelle garantie à l'échelle de toute l'application, peu importe l'auteur d'origine

### 16.1bis Génération automatique d'exercices par IA

Une fois un chapitre/leçon structuré, génération proposée (QCM, réponse ouverte, texte à trous, flashcards, entraînement/approfondissement) selon le catalogue de types d'exercices ; soumis au même workflow de validation ; acceptation/modification/rejet individuel par l'enseignant ; statistique de taux d'acceptation.

### 16.2 Détection automatique en modération (forum)

Moteur IA pour la détection fine (sous-entendus, contournements orthographiques), plus fin qu'une simple liste de mots-clés. Décision de sanction toujours humaine (modérateur).

### 16.3 Infrastructure d'agents IA et stratégie de routage multi-modèles

**Précision stratégique fondamentale** : nos agents IA sont des systèmes construits par notre équipe (prompts, catalogue, pipeline, orchestration) s'appuyant sur des modèles existants via API — il n'est ni réaliste ni nécessaire d'entraîner un modèle de zéro. Notre propriété intellectuelle réside dans le système construit autour du modèle (le pipeline, les prompts, le catalogue, les règles métier), pas dans le modèle lui-même.

Concrètement, un « agent IA » dans ce projet est un programme (back-end, Node.js ou équivalent) qui orchestre les étapes suivantes :

- Reçoit le fichier ou la donnée d'entrée (ex : cours uploadé par un enseignant)
- Décide quel service externe appeler selon la tâche (OCR, structuration, génération)
- Construit un prompt précis incluant le catalogue de la matière concernée
- Appelle l'API du modèle choisi (Claude ou Gemini selon la tâche, cf. tableau ci-dessous)
- Réceptionne, valide la structure de la réponse, et la transmet au workflow de validation humaine
- Sauvegarde le résultat formaté dans la base de données

**Stratégie de routage par tâche** (pas un seul modèle pour tout) :

| Tâche | Modèle recommandé | Justification |
|---|---|---|
| Structuration de cours (16.1) | Claude (Sonnet) | Nuance et fiabilité importantes, volume plus faible (un cours à la fois) |
| Génération d'exercices (16.1bis) | Claude (Sonnet) | Qualité pédagogique prioritaire |
| Modération du forum (16.2) | Gemini (Flash/Flash-Lite) | Haut volume, tâche plus simple (classification), coût prioritaire |
| OCR (scans manuscrits) | Gemini (multimodal natif) | Gère nativement l'image, économique à volume élevé |

Routage configurable, non figé en dur dans le code (les prix/capacités évoluent vite). Le free tier de Gemini est utilisable en phase de prototypage avant mise en production réelle, sans coût.

### 16.4 Méthodologie de construction des agents IA

- Définir précisément chaque tâche (entrée exacte, sortie exacte attendue, critère de succès mesurable, ex : « 90 % des éléments correctement catégorisés sur un échantillon test ») avant tout développement
- Le catalogue par matière (16.0) est un prérequis humain, pas un travail d'IA
- Choisir l'approche technique selon la tâche : LLM pour structuration/génération, service OCR dédié pour les scans, modèle plus léger/spécialisé pour la modération de masse
- Humain dans la boucle systématique au démarrage, sans exception ; réduction de supervision seulement après plusieurs mois d'usage réel et des statistiques de fiabilité solides
- Anticiper le coût et la latence dès la conception : traitement asynchrone (en arrière-plan, avec notification une fois terminé) pour les opérations en masse comme la génération de 50 exercices
- Ordre de construction recommandé : structuration de cours (16.1) → pré-validation → génération d'exercices (16.1bis) → modération du forum (16.2)

### 16.5 Suivi des coûts d'utilisation des agents IA

Tableau de suivi par type d'agent et par fournisseur (Claude / Gemini), coût moyen par contenu traité, mise en regard avec les revenus pour piloter la rentabilité réelle, alertes de dépassement de seuil configurable. Accès : Super-admin uniquement.

## 17. Gestion des modalités de réponse aux exercices

Configuration par exercice/type : clavier/texte, réponse manuscrite sur tablette/écran tactile (capture image ou reconnaissance d'écriture), QCM/sélection. Correction automatique si fiable (calcul/réponse courte), correction humaine sinon (rédactions manuscrites). Interface de correction des soumissions manuscrites.

## 18. Import / export en masse

Import en masse de contenu pédagogique et de sujets/corrections via fichier structuré (CSV/Excel, modèle fourni) ; validation automatique avant import (détection d'erreurs, doublons) avec rapport précis ; import soumis au même workflow de validation que la saisie unitaire ; export en masse pour sauvegarde/audit/migration ; modèles de fichiers téléchargeables (templates vierges).

## 19. Conformité et protection des mineurs

- Pas de consentement parental requis à l'inscription (décision ferme du porteur de projet)
- Workflow de demande de suppression de données (« droit à l'oubli ») : réception, traitement, confirmation, traçabilité
- Politique de conservation des données configurable (durée avant suppression des comptes inactifs)
- Export des données personnelles à la demande (portabilité)
- Journal spécifique des actions liées à la confidentialité
- Modération renforcée (forum, IA, contenu) comme principale ligne de protection des mineurs, en l'absence de filtre parental à l'entrée

### 19bis. Guide d'onboarding à l'inscription (configuration admin)

Créer/modifier les étapes du guide (texte, images, ordre), définir si obligatoire ou peut être passé à tout moment, statistiques de complétion (taux, étape d'abandon la plus fréquente), réactivation du guide après une mise à jour majeure.

## 20. Annonces générales de la plateforme

Bannière d'annonce générale (tous utilisateurs ou filtrée par pays/classe) : maintenance, nouvelle fonctionnalité, message de circonstance. Période d'affichage automatique (début/fin), niveau d'urgence/style visuel (information, avertissement, urgent), historique des annonces passées.

## 21. Réconciliation des paiements Mobile Money

File des paiements en statut ambigu (débité opérateur mais non confirmé application, ou inversement), outil de rapprochement manuel entre relevé agrégateur et transactions enregistrées, validation manuelle exceptionnelle sur preuve de paiement (via ticket support), statistiques du taux d'échec/latence par opérateur (Orange Money vs MTN MoMo). Montants : Super-admin uniquement.

## 22. Gestion des enseignants multi-établissements

Un compte enseignant peut être rattaché à plusieurs établissements simultanément, périmètre (matières, classes) défini indépendamment par établissement, contenu soumis toujours clairement associé à l'établissement d'origine, ajout/retrait d'un établissement de rattachement sans recréer une nouvelle demande complète.

## 23. Gestion de l'année scolaire et du passage de classe

### 23.1 Configuration

Dates de début/fin de l'année scolaire par pays, durée de validité des abonnements liée à cette période (pas une durée glissante de 365 jours), date d'ouverture de la campagne de passage de classe.

### 23.2 Campagne de passage de classe

```
Fin d'année scolaire
  |-- CAS A — Passage validé : nouveau profil/abonnement, progression RESET,
  |     ancien profil consultable en lecture seule
  `-- CAS B — Non-validé (redoublement) : profil maintenu sur la même classe,
        historique conservé, progression de la nouvelle période RESET,
        NOUVEL abonnement exigé pour la nouvelle année scolaire
```

Lancement de la campagne par l'admin pays, suivi du taux de confirmation, forçage manuel en cas de litige.

### 23.3 Affichage du contexte temporel

Configuration des countdowns vers les examens officiels, notifications renforcées (ouverture paiement, fin abonnement, campagne de passage, countdown examens) — voir le catalogue complet de notifications en Partie 1, section 6.4.

## 24. Gestion du palier gratuit et de la publicité

### 24.1 Palier gratuit permanent

Défini via la matrice de droits (section 6.1), message d'incitation au réabonnement configurable, écran dédié affiché au moment du passage automatique (cf. Partie 1, section 6.3).

### 24.2 Publicités

Emplacements réservés au palier gratuit uniquement (jamais en payant, jamais pendant l'essai gratuit), réseau automatisé en complément de partenariats directs négociés (upload visuels, lien, période, ciblage par pays), liste noire de catégories/annonceurs interdits, statistiques de revenus publicitaires (Super-admin uniquement).

### 24.3 Parrainage

Configuration des récompenses (jours offerts, réduction) pour parrain et parrainé, suivi des parrainages et taux de conversion, gestion des abus (faux comptes).

## 25. Gestion de la session unique

Un seul accès actif à la fois, toutes plateformes confondues (mobile OU web, jamais les deux) ; nouvelle connexion → déconnexion immédiate et automatique de l'ancienne session avec message explicite ; journal des connexions par compte ; détection de changements fréquents d'appareil (signal possible de partage de compte à investiguer).

## 26. Gestion des modalités de composition étendues

Configuration par épreuve : écrit numérique, écrit manuscrit tablette, écrit papier scanné/photographié (seuil de qualité requis, retour automatique si illisible), QCM mobile, oral (audio ou vidéo, durée max configurable). Interface de correction adaptée par format (lecteur audio/vidéo intégré, visualiseur d'image). Correction humaine systématique hors QCM/réponse courte numérique.

## 27. Gestion de la contestation de note

File des réclamations (délai de recevabilité configurable), motif obligatoire, assignation à un correcteur (d'origine ou second correcteur), décision (maintenue/révisée) avec motif communiqué, suivi via le système de tickets (catégorie dédiée), statistiques de taux de révision.

## 28. Gestion des remboursements

File des demandes (motif précisé, délai configurable selon motif, cf. les 3 cas détaillés en Partie 1 section 6.8) ; décision par le Super-admin **ou un administrateur explicitement mandaté** selon le cas et le montant : acceptée (exécution via canal de paiement initial) ou refusée (motif obligatoire communiqué : délai dépassé, preuve insuffisante, aucune erreur constatée) ; historique des décisions ; statistiques par motif.

## 29. Accessibilité (configuration admin)

Vérification de conformité du contenu (sous-titres, alternatives textuelles) intégrée à la pré-validation IA, statistiques d'usage des fonctionnalités d'accessibilité côté élève (taille de police, contraste) pour prioriser les efforts futurs.

## 30. Gestion multilingue de l'interface et du contenu

Distinction fondamentale à respecter dans toute l'administration :

- **Langue de l'interface** : choix personnel de l'utilisateur, simple traduction de libellés
- **Langue du contenu pédagogique** : déterminée par la section académique (ex : anglophone vs francophone) — jamais une traduction automatique, contenu indépendant créé et validé séparément par section, les programmes pouvant différer

L'admin ne doit jamais proposer de « traduire automatiquement » un cours d'une section vers une autre.

## Rappel des périmètres d'accès par rôle

| Rôle | Accès |
|---|---|
| Super-admin | Toutes sections (1-30), tous pays, seul à voir les finances, configure la matrice de droits, accès direct base de données |
| Admin pays | Sections 1-5, 6.2/6.3 (sans montants), 7-13, 14 (sans revenus), 16, 18-20, 22-23, 24.1/24.3, 25-27, 29-30, limité à son pays |
| Admin contenu | Sections 2, 4, 16.0/16.1/16.1bis, 18, 29, limité à son périmètre |
| Enseignant | Sections 2, 4.2, soumission via 16.1/16.1bis, limité à établissement(s)/matières/classes |
| Modérateur | Section 8 et 16.2 uniquement |
| Support | Sections 5 (lecture), 6.2 (lecture, sans montants), 10, 19, 27, 28 (réception ; décision si mandaté) |

## Points en suspens à trancher en phase technique

- Fiabilité de la reconnaissance d'écriture manuscrite (sections 17/26) : à valider par des tests techniques
- Budget et fournisseur DRM définitif (section 2.8) : à arbitrer sur devis réels
- Format exact des modèles d'import en masse (section 18) : à concevoir une fois le schéma de base de données finalisé
- Contenu précis de chaque palier dans la matrice de droits (section 6.1) : décision business réservée au porteur de projet, volontairement non figée ici
- Catalogue exhaustif par matière (section 16.0) : la proposition fournie est un point de départ, à compléter avec de vrais enseignants pour toutes les matières du programme

---

# PARTIE 3 — ARCHITECTURE TECHNIQUE ET STRATÉGIE DE DÉMARRAGE

**Diagramme d'architecture système** — composants et flux : App Élève (Web/PWA) et App Élève (Android/iOS) et App Administration (Web, séparée) communiquent avec : WhatsApp (liens communautés), Auth (JWT + 2FA admin), Storage (médias, PDF, cache), Edge Functions (paiement, notifications, cumul mensuel), API Claude (structuration, exercices), API Gemini (OCR, modération) ; toutes lisent/écrivent PostgreSQL + Row Level Security ; Edge Functions communique avec l'Agrégateur de paiement (Campay / Notch Pay) via webhook de confirmation / initier paiement, qui lui-même communique avec les Opérateurs Mobile Money (Orange Money / MTN MoMo).

## 31. Stack technique recommandée

| Composant | Choix recommandé | Justification |
|---|---|---|
| Outil de construction | Claude Code | Agent de développement autonome, adapté à un projet complexe multi-fichiers piloté par tâches |
| Base de données | Supabase (PostgreSQL + Row Level Security) | Cohérent avec l'écosystème déjà utilisé par le porteur de projet ; RLS natif indispensable pour le cloisonnement élève/admin |
| Hébergement back-end / fonctions serveur | Vercel + Supabase Edge Functions | Palier gratuit généreux, déploiement rapide, pas de gestion de serveur |
| Application mobile + web | Flutter (ou React selon préférence finale) | Open-source, un seul code base pour Web/Android/iOS |
| Agents IA — structuration/génération | API Claude (Sonnet) | Qualité et nuance pour le contenu pédagogique |
| Agents IA — modération/OCR/volume | API Gemini (Flash/Flash-Lite) | Palier gratuit généreux, économique à grande échelle |
| Paiement Mobile Money | Agrégateur (Campay, Notch Pay ou Monetbil) | Voir justification détaillée ci-dessous |

## 32. Pourquoi un agrégateur de paiement plutôt qu'une connexion directe aux opérateurs

Deux niveaux d'intégration sont possibles pour le Mobile Money au Cameroun :

- **Connexion directe aux opérateurs** (MTN, Orange) : techniquement lourde (API souvent anciennes), et surtout administrativement longue — signer des contrats directs avec chaque opérateur pour obtenir des clés de production peut prendre des semaines, voire des mois. Incompatible avec un délai de lancement serré.
- **Agrégateur** (Campay, Monetbil, Notch Pay) : a déjà négocié l'accès technique et juridique avec l'ensemble des opérateurs. Expose une API REST moderne, sans frais d'installation ni d'abonnement mensuel — la rémunération de l'agrégateur se fait par commission sur chaque transaction réussie, ce qui est cohérent avec une stratégie de coût initial nul.

Ce qui reste à construire en interne, et qui constitue la vraie valeur ajoutée technique du projet : la logique métier autour du paiement, pas l'infrastructure bancaire elle-même.

### 32.1 Logique de paiement à construire (via Supabase Edge Functions)

```
1. L'élève initie un paiement → l'application appelle une Edge Function
2. L'Edge Function appelle l'API de l'agrégateur pour initier la transaction
3. L'agrégateur envoie le code USSD au téléphone de l'élève (validation Mobile Money)
4. Une fois validé côté opérateur, l'agrégateur notifie l'application via un Webhook
   (URL sécurisée exposée par une Edge Function dédiée)
5. La fonction de réception du Webhook :
   - Vérifie la signature cryptographique de la requête (anti-fraude, anti-faux Webhook)
   - Met à jour la table des transactions et le statut de l'abonnement du profil
   - Recalcule automatiquement le compteur de cumul mensuel (section 6.2, Partie 1)
   - Déclenche les notifications appropriées (confirmation de paiement, déblocage du contenu)
6. En cas d'échec ou d'absence de confirmation dans un délai donné, la transaction
   passe en file de réconciliation manuelle (section 21, Partie 2)
```

Cette architecture événementielle (Webhook + mise à jour automatique) est ce qui permet au système de fonctionner sans intervention humaine pour la grande majorité des paiements, tout en gardant un filet de sécurité (réconciliation manuelle) pour les cas ambigus.

## 33. Stratégie de démarrage à coût initial nul

Le porteur de projet souhaite consacrer son budget de démarrage principalement à l'outillage de développement (Claude Code), plutôt qu'à l'infrastructure. C'est réaliste pour la phase de lancement, à condition de bien choisir les paliers gratuits :

| Brique | Solution à coût nul au démarrage | Limite à surveiller |
|---|---|---|
| Base de données + authentification | Supabase (palier gratuit) | Limite de stockage et de requêtes — à surveiller dès les premiers milliers d'utilisateurs |
| Hébergement web et fonctions serveur | Vercel (palier gratuit) | Limite de temps d'exécution et de bande passante |
| Framework applicatif | Flutter (open-source) | Aucun coût de licence |
| IA — prototypage | Palier gratuit Gemini | Limite de requêtes par minute — risque de blocage en cas de pics d'usage simultané |
| Paiement Mobile Money | Agrégateur sans frais fixe | Commission prélevée uniquement sur transaction réussie — aucun coût avant la première vente |

**Point de vigilance important** : le palier gratuit de Gemini a des limites de requêtes par minute. Si plusieurs enseignants uploadent du contenu simultanément en période de rentrée, le système peut être temporairement bloqué. Il faut prévoir un traitement asynchrone avec file d'attente (cf. section 16.4) pour absorber ces pics sans dégrader l'expérience, plutôt que de bloquer l'utilisateur en attente d'une réponse immédiate.

## 34. Méthodologie de mise en œuvre recommandée

- Construire l'application Administration en premier (elle concentre toute la complexité : agents IA, arbre académique, matrice de droits)
- Démarrer le développement et les tests avec les paliers gratuits (Gemini, Supabase, Vercel)
- Implémenter en priorité : structuration de cours par IA → workflow de validation → génération d'exercices
- Brancher le paiement Mobile Money via agrégateur et Edge Functions dès que la structure académique et le contenu de base existent
- Construire l'application Élève en consommant la même base de données, une fois l'admin stabilisée
- Basculer progressivement de Gemini vers Claude pour les tâches de structuration fine, au fur et à mesure que les revenus couvrent ce coût

---

# PARTIE 4 — MODÈLE DE DONNÉES DÉTAILLÉ

Le modèle de données complet compte environ 40 tables, présenté en trois diagrammes entité-relation thématiques : (1) identité, profils et abonnements, (2) arbre académique et contenu pédagogique, (3) communauté, support, administration et IA.

## 35. Principes de conception

- Base de données unique PostgreSQL (Supabase), partagée entre l'application élève et l'application admin
- Sécurisation par Row Level Security (RLS) : chaque table porte des politiques d'accès selon le rôle de l'utilisateur authentifié
- L'arbre académique est modélisé en structure générique (table « node » avec parent_id + type + niveau) pour absorber la profondeur variable selon les pays, plutôt qu'une table dédiée par niveau (pays, section, classe...)

## 36. Entités principales

### 36.1 Identité et profils

| Table | Champs clés | Description |
|---|---|---|
| accounts | id, email, password_hash, phone, first_name, last_name, photo_url, created_at | Compte unique : identité, authentification |
| profiles | id, account_id (FK), class_node_id (FK), status (actif/archivé), subscription_tier, school_year | Un profil = une classe + un abonnement + un historique |
| parent_accounts | id, email, phone, first_name, last_name | Compte parent distinct |
| parent_profile_links | parent_account_id (FK), profile_id (FK), relation_type | Liaison parent ↔ profil élève |
| sessions | id, account_id (FK), device_fingerprint, platform, created_at, is_active | Gestion de la session unique stricte |

### 36.2 Arbre académique générique

| Table | Champs clés | Description |
|---|---|---|
| academic_nodes | id, parent_id (FK self), node_type (pays/section/enseignement/classe/série), name, country_id, display_order | Arbre générique à profondeur variable |
| subjects | id, name, node_id (FK, classe ou groupe lié) | Matière, rattachée à une classe ou un groupe |
| subject_class_links | subject_id (FK), class_node_id (FK) | Relation many-to-many matière ↔ classes liées |
| terms | id, country_id (FK), name (Trimestre 1/2/3), start_date, end_date, school_year | Découpage temporel, invisible côté élève |
| chapters | id, subject_id (FK), term_id (FK), title, introduction, display_order | Chapitre, rattaché à un trimestre |
| lessons | id, chapter_id (FK), title, content_json, display_order | Leçon avec contenu structuré |

### 36.3 Contenu pédagogique et exercices

| Table | Champs clés | Description |
|---|---|---|
| exercises | id, lesson_id (FK nullable), chapter_id (FK nullable), type (entraînement/évaluation), difficulty, format, min_subscription_tier | Trois niveaux de rattachement possibles |
| exercise_versions | id, exercise_id (FK), version_number, content_json, published_at | Historique de versioning du contenu |
| content_catalog | id, subject_id (FK), element_type (théorème/définition/exemple...) | Catalogue des éléments par matière |
| media_library | id, type, url, size, uploaded_by | Bibliothèque de médias centralisée |
| validation_queue | id, content_id, content_type, status, ai_report_json, reviewer_id, reviewed_at | Workflow de validation du contenu |

### 36.4 Abonnements, paliers et paiements

| Table | Champs clés | Description |
|---|---|---|
| subscription_tiers | id, name (gratuit/journalier/hebdo/mensuel/annuel), country_id, class_node_id, price | Grille tarifaire par classe et durée |
| access_matrix | id, tier_id (FK), feature_key, access_level (complet/limité/aucun) | Matrice de droits configurable |
| subscriptions | id, profile_id (FK), tier_id (FK), start_date, end_date, status (actif/expiré/essai) | Abonnement actif d'un profil |
| monthly_spend_counter | profile_id (FK), month, cumulative_amount | Compteur de cumul mensuel pour requalification |
| transactions | id, profile_id (FK), amount, operator (Orange/MTN), status, aggregator_ref, created_at | Transactions de paiement (montants visibles Super-admin uniquement) |
| payment_reconciliation | id, transaction_id (FK), issue_type, resolved_by, resolved_at | File de réconciliation manuelle |
| refund_requests | id, profile_id (FK), reason_category, motive, status, decided_by, decision_reason | Demandes de remboursement avec les 3 cas d'éligibilité |
| referral_codes | id, profile_id (FK), code, uses_count | Parrainage |

### 36.5 Notifications (catalogue complet, cf. Partie 1 section 6.4)

| Table | Champs clés | Description |
|---|---|---|
| notification_templates | id, event_key, channel (push/email/sms/in-app), title_template, body_template | Modèles configurables côté admin |
| notification_log | id, profile_id (FK), template_id (FK), sent_at, opened_at | Historique d'envoi et de lecture |
| scheduled_reminders | id, profile_id (FK), reminder_type, trigger_date, sent | Rappels programmés (J-3, J-1, J-60, etc.) |

### 36.6 Examens, établissements, événements

| Table | Champs clés | Description |
|---|---|---|
| official_exams | id, country_id, class_node_id, name (BEPC/Probatoire/Bac), exam_date | Calendrier des examens officiels |
| exam_papers | id, exam_id (FK), subject_id (FK), year, document_url, correction_url | Sujets et corrections nationaux |
| establishments | id, country_id, name, city | Établissements (créés par admin uniquement) |
| establishment_papers | id, establishment_id (FK), class_node_id (FK), subject_id (FK), year, document_url | Épreuves d'établissement |
| events | id, type (examen_blanc/olympiade), country_id, dates, pricing_mode | Examens blancs et olympiades |
| event_results | id, event_id (FK), profile_id (FK), score, rank, percentile | Résultats et classements |
| grade_disputes | id, event_result_id (FK), reason, status, resolution | Contestations de note |

### 36.7 Communauté et support

| Table | Champs clés | Description |
|---|---|---|
| forum_threads / forum_posts | id, class_node_id (FK), subject_id (FK nullable), author_id, content, flagged | Forum cloisonné par classe |
| whatsapp_communities | id, class_node_id (FK), invite_link, member_count_estimate | Communautés WhatsApp officielles |
| support_tickets | id, account_id (FK), category, status, requester_type (élève/parent) | Tickets de support |

### 36.8 Administration, rôles et audit

| Table | Champs clés | Description |
|---|---|---|
| admin_users | id, email, role (super_admin/admin_pays/admin_contenu/enseignant/modérateur/support), scope_json | Comptes administrateurs |
| admin_permissions | admin_user_id (FK), permission_key, granted | Permissions nommées, ajustables individuellement |
| audit_log | id, admin_user_id (FK), action_type, entity_type, entity_id, before_json, after_json, created_at | Traçabilité totale, y compris toute suppression |
| teacher_establishments | teacher_id (FK), establishment_id (FK), subjects_scope, classes_scope | Enseignant multi-établissements |

### 36.9 Intelligence artificielle

| Table | Champs clés | Description |
|---|---|---|
| ai_agent_calls | id, agent_type, provider (claude/gemini), tokens_used, cost_estimate, created_at | Suivi des coûts d'utilisation des agents |
| ai_content_review | id, content_id, ai_findings_json, accepted, reviewed_by | Rapport de pré-analyse IA |

## 37. Relations transversales clés

- `profiles.class_node_id → academic_nodes.id` : cloisonnement strict, point d'ancrage de toutes les règles d'accès
- `subscriptions.tier_id` + `access_matrix` : détermine dynamiquement ce qu'un profil peut voir à un instant donné
- `terms` (trimestres) croisé avec la date du jour : détermine le déblocage progressif du contenu, sans jamais exposer cette table côté API élève
- `audit_log` : alimentée par triggers PostgreSQL sur toute opération de suppression/modification sensible, garantissant qu'aucune action admin n'échappe à la traçabilité exigée par le Super-admin

---

# PARTIE 5 — LOGIQUE DÉTAILLÉE ET EXEMPLES CHIFFRÉS

Cette partie déroule, avec des données concrètes, les règles métier les plus complexes du cahier des charges. L'objectif est de lever toute ambiguïté d'implémentation en montrant, cas par cas, ce que le système doit faire.

**Diagramme de séquence — Inscription et premier paiement** : Élève saisit identité + choisit classe → App Élève crée compte + profil (statut = essai) en base → confirmation → Élève choisit abonnement Mensuel 3e → App Élève appelle `initierPaiement(profil, montant)` sur Edge Function → Edge Function fait une requête de paiement (API REST) à l'Agrégateur → Agrégateur envoie code USSD de validation à l'élève → élève valide le code USSD sur son téléphone → Agrégateur envoie Webhook (paiement confirmé + signature) à l'Edge Function → Edge Function vérifie la signature cryptographique → met à jour `subscriptions.status = actif` en base → recalcule `monthly_spend_counter` → notifie déblocage du contenu à l'App Élève → notification à l'élève : paiement confirmé, accès débloqué.

## 38. Exemple complet — Cumul mensuel et requalification automatique

### 38.1 Données de départ

| Paramètre | Valeur |
|---|---|
| Classe du profil | 3e |
| Prix abonnement Journalier (3e) | 150 FCFA |
| Prix abonnement Hebdomadaire (3e) | 800 FCFA |
| Prix abonnement Mensuel (3e) | 2 500 FCFA |
| Élève | Profil « Junior, 3e », mois d'octobre 2026 |

### 38.2 Déroulé jour par jour

| Date | Action de l'élève | Montant | Cumul du mois | Palier actif après l'action |
|---|---|---|---|---|
| 1er octobre | Paiement Journalier | 150 FCFA | 150 FCFA | Journalier (1 jour) |
| 3 octobre | Paiement Journalier | 150 FCFA | 300 FCFA | Journalier (1 jour) |
| 7 octobre | Paiement Hebdomadaire | 800 FCFA | 1 100 FCFA | Hebdomadaire (7 jours) |
| 14 octobre | Paiement Hebdomadaire | 800 FCFA | 1 900 FCFA | Hebdomadaire (7 jours) |
| 20 octobre | Paiement Journalier | 150 FCFA | 2 050 FCFA | Journalier (1 jour) |
| 25 octobre | Paiement Journalier | 150 FCFA | 2 200 FCFA | Journalier (1 jour) |
| 28 octobre | Paiement Journalier | 150 FCFA | 2 350 FCFA | Journalier (1 jour) |
| 29 octobre | Paiement Journalier | 200 FCFA (tarif ajusté) | **2 550 FCFA** | **Requalification automatique → Mensuel** |

### 38.3 Ce qui se passe précisément le 29 octobre

- Le paiement de 200 FCFA est enregistré normalement dans `transactions`
- Le trigger de mise à jour de `monthly_spend_counter` recalcule le cumul : 2 550 FCFA
- Le système compare ce cumul au prix du palier Mensuel pour cette classe (2 500 FCFA) : 2 550 ≥ 2 500 → condition remplie
- Le profil est requalifié automatiquement : `profiles.subscription_tier = 'mensuel'`, avec une date de fin fixée au dernier jour du mois calendaire en cours (31 octobre), et non au-delà
- Une notification est envoyée immédiatement : « Bonne nouvelle ! Vous avez cumulé assez de paiements ce mois-ci pour débloquer l'accès Mensuel jusqu'au 31 octobre. »
- Le contenu réservé au palier Mensuel (examens blancs inclus, etc.) devient immédiatement accessible, sans action supplémentaire de l'élève

### 38.4 Ce qui se passe le 1er novembre (mois suivant)

- Le compteur `monthly_spend_counter` est remis à zéro pour le nouveau mois
- Le profil retombe à son dernier palier réellement souscrit et non expiré (ici, aucun abonnement Mensuel n'a été payé directement → retour au palier Gratuit, sauf nouveau paiement)
- Le cumul ne se reporte jamais d'un mois sur l'autre — c'est une règle stricte pour éviter les effets de bord comptables

### 38.5 Cas limite à gérer : et si l'élève paie un Mensuel directement le 15 du mois ?

Dans ce cas, la logique de cumul ne s'applique pas (elle ne sert qu'à additionner des paiements courts) : l'abonnement Mensuel payé directement suit sa propre règle de durée — il couvre 30 jours glissants à partir du paiement, pas jusqu'à la fin du mois calendaire. Seule la requalification *par cumul* est calée sur le mois calendaire, car elle part de paiements déjà répartis dans le mois en cours.

## 39. Exemple complet — Matrice de droits et affichage flouté

### 39.1 Configuration de la matrice (exemple réaliste pour la classe de 3e)

| Fonctionnalité | Gratuit | Journalier | Hebdomadaire | Mensuel | Annuel |
|---|---|---|---|---|---|
| Cours (lecture) | Limité (2 chapitres/matière) | Complet | Complet | Complet | Complet |
| Exercices d'entraînement | Limité | Complet | Complet | Complet | Complet |
| Exercices d'évaluation | Aucun accès | Aucun accès | Complet | Complet | Complet |
| Examens officiels nationaux | Aucun accès | Aucun accès | Aucun accès | Complet | Complet |
| Épreuves d'établissement | Aucun accès | Aucun accès | Limité (1/jour) | Complet | Complet |
| Assistant IA | Aucun accès | 3 questions/jour | 10 questions/jour | Illimité | Illimité |
| Téléchargement hors-ligne | Aucun accès | Aucun accès | Limité (1 chapitre) | Complet | Complet |
| Publicité affichée | Oui | Non | Non | Non | Non |

### 39.2 Scénario concret : Junior est au palier Gratuit et clique sur un exercice d'évaluation

- Junior navigue dans le chapitre « Théorème de Pythagore », déjà dans les 2 chapitres inclus au gratuit
- Il voit la liste des exercices : les exercices d'entraînement sont nets et cliquables ; les exercices d'évaluation apparaissent floutés avec un badge discret « + 8 exercices »
- Junior clique sur un exercice flouté
- Le système consulte la matrice : `access_matrix` pour (tier=gratuit, feature=exercices_evaluation) = aucun accès
- Le système détermine le palier minimum qui débloque cette fonctionnalité : **Hebdomadaire** (le plus proche/moins cher parmi ceux qui donnent accès)
- Affichage : « Cet exercice fait partie de l'abonnement Hebdomadaire (800 FCFA) — débloquez-le maintenant » avec bouton de paiement direct pré-rempli sur ce palier
- Si Junior ferme la fenêtre sans payer, il retourne à la liste normalement — aucun blocage de navigation

### 39.3 Requête technique simplifiée (pseudo-code)

```
FONCTION peut_acceder(profil, feature_key):
    tier_actif = profil.subscription_tier
    droit = access_matrix.chercher(tier=tier_actif, feature=feature_key)
    SI droit == "complet": RETOURNER (accès=oui)
    SI droit == "limité": RETOURNER (accès=partiel, limite=droit.parametre)
    SI droit == "aucun":
        palier_min = access_matrix.trouver_palier_minimum_pour(feature_key)
        RETOURNER (accès=non, palier_suggere=palier_min, prix=tarif(palier_min, profil.classe))
```

**Diagramme de séquence — Expiration d'un abonnement** : Tâche planifiée (cron quotidien) cherche les abonnements avec fin = J+3 → pour chaque profil concerné, Service Notification envoie Push + in-app : rappel J-3 à l'élève → cron cherche les abonnements avec fin = J+1 → Push + bannière persistante : rappel J-1 → cron cherche les abonnements avec fin = aujourd'hui → `UPDATE profiles SET tier = 'gratuit'` → notification : passage au palier gratuit + récap accès perdus → cron planifie relance J+1 / J+7 / J+30.

## 40. Exemple complet — Session unique et détection de partage de compte

### 40.1 Scénario

Junior se connecte sur son téléphone Android le matin (session A créée). L'après-midi, son cousin utilise les identifiants de Junior pour se connecter depuis un autre téléphone (session B).

### 40.2 Déroulé technique

- Connexion cousin → le serveur authentifie les identifiants avec succès
- Avant de créer la session B, le système vérifie `sessions` : une session A existe déjà, `is_active = true`
- Le système : (a) marque la session A comme `is_active = false`, (b) crée la session B comme active, (c) envoie un signal de déconnexion en temps réel au téléphone de Junior (via WebSocket ou notification push silencieuse)
- Sur le téléphone de Junior, la prochaine action déclenche une vérification de validité de session → refusée → écran : « Compte utilisé sur un autre appareil — reconnectez-vous pour reprendre l'accès »
- Si ce type d'événement (bascule de session) se répète plus de N fois par semaine (seuil configurable, ex. 5), une entrée est ajoutée à une file de surveillance côté administration : « Compte potentiellement partagé — à vérifier » (pas de sanction automatique, juste un signalement pour revue humaine)

### 40.3 Ce que cette règle empêche, et ce qu'elle n'empêche pas

- **Empêche** : deux personnes différentes d'utiliser simultanément le même abonnement payé une fois
- **N'empêche pas** : Junior d'utiliser légitimement son compte sur son téléphone le matin puis sur l'ordinateur familial le soir — dans ce cas, une seule bascule de session par jour ne déclenche aucune alerte, c'est un usage normal

**Diagramme de séquence — Upload et validation d'un cours** : Enseignant upload cours (PDF/photo/texte) → App Admin traite (fichier, matière) → Agent IA (pipeline) fait l'OCR si nécessaire (image/scan) → prompt structuration + catalogue matière envoyé à l'API Claude → contenu structuré (JSON par éléments) renvoyé → sauvegarde version + statut = en_attente en base → rapport de pré-analyse (orthographe, manques) renvoyé à l'App Admin → notifie l'Admin pays : nouveau contenu à valider → Admin pays consulte contenu + rapport IA → décision : Approuve → `UPDATE statut = publié` en base → notification à l'enseignant : contenu publié.

## 41. Exemple complet — Déblocage progressif par trimestre

### 41.1 Configuration

| Trimestre | Dates (année scolaire 2026-2027, Cameroun) |
|---|---|
| Trimestre 1 | 1er septembre 2026 → 20 décembre 2026 |
| Trimestre 2 | 5 janvier 2027 → 28 mars 2027 |
| Trimestre 3 | 12 avril 2027 → 30 juin 2027 |

Le chapitre « Les fractions » (mathématiques, 6e) est rattaché au Trimestre 1. Le chapitre « Théorème de Thalès » est rattaché au Trimestre 2.

### 41.2 Ce que voit un élève selon la date

| Date de consultation | Chapitre « Les fractions » | Chapitre « Théorème de Thalès » |
|---|---|---|
| 15 octobre 2026 (en T1) | Visible et accessible | Invisible (T2 non commencé) |
| 20 décembre 2026 (fin T1) | Visible et accessible | Invisible |
| 10 janvier 2027 (en T2) | **Toujours visible et accessible** (cumulatif) | Visible et accessible (T2 démarré) |
| 15 mars 2027 (en T2) | Visible et accessible | Visible et accessible |

Le principe cumulatif est ce qui distingue ce système d'un simple déverrouillage séquentiel : rien ne se ferme jamais, seul le contenu strictement futur reste masqué.

### 41.3 Cas d'exception : déblocage anticipé décidé par un établissement

Si un établissement a pris de l'avance sur le programme et que l'admin pays force un déblocage anticipé pour ce cas précis, la règle devient : le chapitre du T2 devient visible avant la date normale, **uniquement pour les profils explicitement inclus dans cette dérogation** (pas pour tous les élèves du pays).

**Diagramme de séquence — Campagne de passage de classe** : Admin pays lance la campagne de passage (date de fin d'année) → App Admin récupère tous les profils actifs concernés → notification à l'Élève/Parent : confirmer le passage en classe supérieure → **Cas A** : confirme + choisit nouvelle série → App Admin crée nouveau profil + nouvel abonnement requis en base → archive ancien profil (lecture seule) → **Cas B** : ne confirme pas (délai dépassé) → App Admin conserve le profil sur la même classe → reset progression + exige nouvel abonnement → notification de confirmation du nouvel état à l'Élève/Parent.

**Diagramme de séquence — Traitement d'une demande de remboursement** : Élève ouvre un ticket catégorie « paiement » → App Élève crée `refund_request` (motif = erreur technique) → Réconciliation automatique vérifie l'écart transaction vs relevé agrégateur → confirme : paiement débité, accès jamais accordé → notifie l'Administrateur mandaté : remboursement éligible, en attente de décision → décision : ACCEPTÉE (motif documenté) → Ticket support exécute le remboursement via canal de paiement initial → notification à l'élève : remboursement effectué sous 48h.

## 42. Exemple complet — Cycle de vie d'un remboursement

### 42.1 Cas concret : erreur technique

- Le 3 juin, Junior paie 2 500 FCFA pour un abonnement Mensuel
- Le paiement est débité côté Orange Money, mais suite à une panne de webhook, le statut reste « en attente » côté application pendant 48h et l'accès n'est jamais débloqué
- Junior ouvre un ticket de catégorie « paiement »
- Le système de réconciliation (section 21, Partie 2) détecte l'écart en croisant le relevé de l'agrégateur avec la table `transactions`
- Motif « erreur technique prouvée » confirmé → remboursement quasi automatique déclenché par un administrateur mandaté, sans attendre le Super-admin (montant sous le seuil délégué)
- Junior est remboursé sur son compte Orange Money sous 48h, avec notification à chaque étape (ticket pris en compte → remboursement en cours → remboursement effectué)

### 42.2 Cas concret : insatisfaction simple, hors délai

- Junior paie un abonnement Annuel le 1er septembre
- Il change d'avis et demande un remboursement le 20 septembre (19 jours après paiement)
- Le délai de recevabilité pour l'insatisfaction simple est de 48h → la demande est automatiquement marquée hors délai
- Décision affichée : refusée, motif « délai dépassé » — Junior peut toujours faire appel via un nouveau ticket s'il estime avoir une raison exceptionnelle, revu manuellement par le Super-admin

**Diagramme de séquence — Contestation de note** : Élève consulte sa note d'examen blanc (12/20) → clique « Contester cette note » + motif → App Élève crée `grade_disputes` (statut=ouvert, délai vérifié) → Base de données vérifie que le délai de recevabilité n'est pas dépassé → assigne à un second correcteur → Correcteur (2e correcteur) consulte la copie + la première correction → décision : note révisée à 15/20, motif fourni → `UPDATE grade_disputes` (statut=résolu, nouvelle note=15) → notification à l'élève : note révisée de 12 à 15, motif communiqué.

## 43. Exemple complet — Contestation de note (point 27, Application Administration)

### 43.1 Scénario concret

Junior compose l'examen blanc de mathématiques de novembre et obtient 12/20. Il est convaincu que sa réponse à la question 3 (5 points) a été mal comptée — il avait posé le bon raisonnement mais avec une erreur d'arrondi mineure, et pense mériter au moins 3 points sur 5 au lieu de 1.

### 43.2 Déroulé pas à pas

- Junior consulte sa copie corrigée depuis « Mes résultats » et voit le détail question par question
- Il clique sur « Contester cette note », sélectionne la question 3, et rédige un motif : « Le raisonnement est correct, seule l'unité finale est fausse — je pense mériter plus que 1/5 sur cette question »
- Le système crée une entrée dans `grade_disputes` avec le statut ouvert, et vérifie immédiatement que la demande est dans le délai de recevabilité configuré (ex : 7 jours après publication des résultats) — ici, Junior conteste 2 jours après, donc la demande est recevable
- Le dossier est assigné à un second correcteur, **différent** de celui qui a noté la copie initialement (règle d'impartialité)
- Le second correcteur consulte la copie scannée, la grille de correction officielle, et la première note attribuée
- Décision : le second correcteur estime que 3/5 est justifié sur cette question (raisonnement juste, erreur mineure) → nouvelle note globale : 14/20
- Le système met à jour `grade_disputes.status = résolu` et `event_results.score = 14`
- Junior reçoit une notification : « Votre contestation a été étudiée. Note révisée : 14/20 (question 3 : 3/5 au lieu de 1/5). Motif : raisonnement correct malgré une erreur d'arrondi. »

### 43.3 Cas où la contestation est rejetée

Si le second correcteur confirme la note initiale (aucune erreur de correction constatée), le statut passe à résolu avec `nouvelle_note = note_initiale`, et la notification précise explicitement le motif du maintien : « Après relecture, la note de 1/5 sur la question 3 est maintenue : le résultat final étant faux, le barème officiel ne permet pas d'attribuer plus de points même avec un raisonnement partiellement correct. » — Junior ne peut pas recontester une seconde fois la même question sur le même examen (une seule contestation par question, pour éviter les allers-retours sans fin).

### 43.4 Ce que cette règle empêche

Sans second correcteur obligatoire, le correcteur initial pourrait être tenté de maintenir sa note par simple confort plutôt que par relecture objective — l'impartialité du second regard est ce qui rend la contestation crédible aux yeux de l'élève et du parent.

**Diagramme de séquence — Réconciliation d'un paiement ambigu** : Agrégateur envoie webhook reçu mais signature invalide/incomplète → Edge Function (webhook) tente une nouvelle vérification (retry x3) → marque la transaction : statut = ambigu en base → ajoute à la file de réconciliation manuelle → notifie l'Admin pays : transaction à vérifier manuellement → Admin pays compare relevé agrégateur vs table transactions → décision : paiement confirmé manuellement → `UPDATE transactions.status = confirmé` → débloque l'abonnement correspondant.

## 44. Exemple complet — Réconciliation d'un paiement Mobile Money ambigu

### 44.1 Scénario concret

Le 5 novembre à 14h32, Junior initie un paiement de 2 500 FCFA (abonnement Mensuel) via MTN MoMo. Il reçoit la demande de confirmation USSD sur son téléphone et valide. Cependant, à cause d'une coupure réseau côté opérateur, le Webhook de confirmation n'arrive jamais à l'application.

### 44.2 Déroulé pas à pas

- `transactions` enregistre la tentative avec statut `en_attente` dès l'initiation
- Après un délai de 15 minutes sans confirmation Webhook, une tâche planifiée interroge directement l'API de l'agrégateur pour vérifier le statut réel de la transaction (mécanisme de rattrapage actif, pas seulement passif)
- L'agrégateur répond : transaction marquée « réussie » de son côté — écart détecté entre ce que dit l'agrégateur et ce que sait l'application
- La transaction passe automatiquement en statut `ambigu` et rejoint la file de réconciliation manuelle
- Un admin pays consulte la file le lendemain matin, voit l'écart, et vérifie le relevé de transactions de l'agrégateur pour confirmer le montant, la date et le numéro de téléphone
- Confirmation manuelle : l'admin marque la transaction comme confirmée avec une note « Vérifié sur relevé agrégateur du 05/11, réf. TX-88213 »
- Le système débloque immédiatement l'abonnement Mensuel de Junior, **avec effet rétroactif à la date réelle du paiement** (5 novembre), pas à la date de résolution (6 novembre) — pour ne pas pénaliser Junior d'un délai qui n'est pas de son fait
- Notification à Junior : « Votre paiement du 5 novembre a bien été confirmé, votre accès est débloqué. »

### 44.3 Pourquoi la vérification active (étape 2) est nécessaire, pas seulement le Webhook

Un Webhook seul est un mécanisme passif : si l'agrégateur ne parvient jamais à le déclencher (panne réseau, erreur de configuration), l'application n'a aucun moyen de savoir qu'un paiement a eu lieu sans une vérification active complémentaire. C'est cette double sécurité — Webhook en temps réel **et** vérification périodique de rattrapage — qui évite que des élèves ayant réellement payé restent bloqués indéfiniment.

**Diagramme de séquence — Signalement et modération d'un message** : Élève A (auteur) publie un message dans le forum (classe 3e) → App Élève envoie à l'Agent IA (détection) pour analyse automatique à la publication → score de risque faible → publication autorisée → Élève B (signale) clique « Signaler » sur le message → App Élève envoie à l'Agent IA pour réanalyse approfondie du message signalé → score de risque élevé → ajout à la file de modération → notifie le Modérateur : nouveau signalement à traiter → Modérateur consulte le message en contexte → décision : avertissement à l'auteur + suppression → notification à Élève A : message supprimé, avertissement reçu.

## 45. Exemple complet — Modération d'un message de forum

### 45.1 Scénario concret

Dans le forum de la classe de 3e (matière : mathématiques), un élève publie un message qui contient une insulte déguisée par un contournement orthographique volontaire (lettres remplacées par des chiffres pour éviter un filtre simple de mots-clés).

### 45.2 Déroulé pas à pas

- Le message est publié ; l'analyse automatique de premier niveau (filtrage par mots-clés) ne détecte rien d'anormal — le contournement orthographique passe à travers ce filtre basique
- Un camarade de classe clique sur « Signaler » et sélectionne le motif « propos insultants »
- Le signalement déclenche une seconde analyse, plus fine, confiée à l'agent IA de modération (modèle économique à haut volume, cf. Partie 3, stratégie de routage) : celui-ci est spécifiquement entraîné à repérer les contournements orthographiques et sous-entendus, pas seulement une liste de mots interdits
- Le score de risque retourné est élevé → le message est automatiquement masqué en attendant une revue humaine (précaution, pas suppression définitive automatique)
- Le modérateur reçoit une notification prioritaire, consulte le message signalé avec son contexte (les messages précédents et suivants dans le fil), et confirme l'infraction
- Décision : suppression du message + avertissement formel envoyé à l'auteur, avec motif précis cité
- L'auteur reçoit une notification : « Votre message dans le forum de mathématiques 3e a été supprimé pour propos insultants. C'est votre 1er avertissement. »
- Le système enregistre cet avertissement dans l'historique de l'auteur : un système de paliers (configurable côté admin, ex. 3 avertissements = suspension temporaire du forum) permet une gradation plutôt qu'une sanction binaire

### 45.3 Pourquoi le message est masqué avant la revue humaine, pas après

Sur un forum destiné à des mineurs, laisser un contenu potentiellement insultant visible en attendant qu'un modérateur humain le traite (ce qui peut prendre plusieurs heures) expose davantage d'élèves au contenu problématique. Le masquage immédiat dès qu'un score de risque élevé est détecté, réversible si le modérateur juge finalement le signalement infondé, est le compromis qui protège le plus efficacement sans reposer uniquement sur la rapidité humaine.
