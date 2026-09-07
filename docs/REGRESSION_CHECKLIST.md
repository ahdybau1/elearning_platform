# Checklist de Non-Régression Obligatoire (REGRESSION_CHECKLIST)

**Application :** EDLEARN Student Application (`student_app`)  
**Protocole :** À exécuter et valider avant tout merge, commit majeur ou fin de vague d'implémentation.  
**Règle absolue :** Tout test en échec bloque immédiatement le déploiement (`STOP + RAPPORT`).

---

## 1. Authentification, Sessions & Accès Sécurisé

- [ ] **Connexion Email / Mot de passe :**
  - [ ] La connexion avec des identifiants valides authentifie l'élève et charge son compte `accounts`.
  - [ ] Un mot de passe erroné affiche un message d'erreur clair sans planter l'application.
  - [ ] Les sessions actives se restaurent sans perte d'état.
- [ ] **Détection d'appareil & Multi-Comptes :**
  - [ ] `DeviceAccountsService` liste les comptes connus sur l'appareil.
  - [ ] Le déverrouillage par code PIN personnel fonctionne pour le compte sélectionné.
  - [ ] Le code PIN d'un compte A ne permet pas d'accéder au compte B.
- [ ] **Session Unique Stricte (Anti-partage) :**
  - [ ] Une nouvelle connexion sur un autre appareil déconnecte l'ancienne session avec un message explicite.
- [ ] **Déconnexion :**
  - [ ] Le bouton "Se déconnecter" purge la session active et redirige vers `StudentAuthGate`.

---

## 2. Profils & Cloisonnement Académique

- [ ] **Sélecteur de profil ("Qui apprend ?") :**
  - [ ] Si le compte possède plusieurs classes, le sélecteur s'affiche obligatoirement au démarrage.
  - [ ] Si le compte n'a qu'une seule classe, l'accès au tableau de bord est immédiat sans écran redondant.
  - [ ] "Changer de profil" réinitialise le choix et permet de basculer vers une autre classe du compte.
- [ ] **Cloisonnement strict par classe :**
  - [ ] L'élève ne voit QUE les matières rattachées à sa classe (`subject_class_links`).
  - [ ] Aucun cours d'une autre classe n'apparaît dans la liste ou la recherche.
  - [ ] Les examens officiels affichés correspondent strictement au niveau du profil (ex: BEPC pour la 3e, Probatoire pour la 1ère, Bac pour la Terminale).
  - [ ] Pour un niveau sans examen national (ex: 4e, 2nde), l'onglet examen officiel est automatiquement masqué.

---

## 3. Déblocage Temporel & Trimestres

- [ ] **Découpage invisible par trimestre :**
  - [ ] Les chapitres du trimestre en cours et des trimestres passés sont accessibles ("Disponible").
  - [ ] Les chapitres des trimestres futurs sont visibles mais verrouillés avec leur mention de date/trimestre.
  - [ ] Le clic sur un chapitre futur affiche un message informatif courtois sans erreur 500 ni crash.
  - [ ] Le mot "Trimestre" n'apparaît jamais comme un niveau hiérarchique de navigation.

---

## 4. Parcours de Cours, Chapitres & Leçons

- [ ] **Liste des chapitres :**
  - [ ] Affiche le nombre réel de leçons et d'exercices calculé depuis le backend.
  - [ ] L'introduction pédagogique du chapitre est lisible.
- [ ] **Lecteur de leçons multi-leçons :**
  - [ ] Toutes les leçons du chapitre sont accessibles (pas seulement la première `lessons.first`).
  - [ ] La navigation vers la leçon suivante et précédente fonctionne sans perte d'état.
  - [ ] Les blocs pédagogiques (`ContentBlock`) s'affichent avec leur renderer respectif :
    - [ ] Définition (icône livre, bordure indigo)
    - [ ] Théorème (icône certifié, bordure cyan)
    - [ ] Formule (fond contrasté, scroll horizontal si long)
    - [ ] Méthode (icône ampoule, étapes numérotées)
    - [ ] Exemple (icône étoiles, bordure violette)
    - [ ] Piège d'examen (icône attention, fond rosé)
    - [ ] Conseil d'examen (icône astuce, bordure cyan)
    - [ ] Paragraphe standard de repli sécurisé en cas de type non reconnu.
- [ ] **Protection documentaire (DRM) :**
  - [ ] Le filigrane de sécurité discret avec les coordonnées du compte s'affiche en overlay.

---

## 5. Exercices, Quiz & Moteur d'Entraînement

- [ ] **Support des 5 formats d'exercices :**
  - [ ] QCM : sélection d'une option unique, changement d'avis possible avant validation.
  - [ ] Réponse courte : champ texte actif, soumission correcte.
  - [ ] Rédaction : zone multiligne fluide.
  - [ ] Flashcard : tap pour retourner la carte recto/verso.
  - [ ] Manuscrit scanné : affichage de l'énoncé et du corrigé type.
- [ ] **Indices progressifs :**
  - [ ] "Voir un indice" révèle les indices un par un de façon maïeutique.
  - [ ] Aucun indice n'est révélé par défaut avant que l'élève ne le demande.
- [ ] **Persistance des tentatives (IA-007) :**
  - [ ] `recordExerciseAttempt` est appelé et enregistre la tentative dans la table Supabase `exercise_attempts`.
  - [ ] Aucune tentative fictive ou simulée silencieusement.
- [ ] **Corrigé & Pédagogie de l'erreur :**
  - [ ] Après validation, le corrigé s'affiche avec la justification.
  - [ ] L'option correcte est mise en valeur en vert, l'erreur en rose/rouge.
  - [ ] Le score d'XP est crédité et affiché fidèlement.

---

## 6. Abonnements, Paliers & Paywall

- [ ] **Matrice de droits :**
  - [ ] Les cours gratuits sont lisibles par un profil au palier gratuit.
  - [ ] Les cours réservés aux abonnés affichent le flou protecteur et le déclencheur de paywall.
- [ ] **Paywall Modal :**
  - [ ] Les 3 formules (Découverte, Mensuel, Annuel) affichent leurs tarifs réels en FCFA.
  - [ ] Le clic sur "Payer" affiche l'information honnête de configuration passerelle en attente (aucun faux prélèvement simulé).
  - [ ] Aucun abonnement payant n'est débloqué frauduleusement sans validation serveur.

---

## 7. Tuteur Numérique IA (Zéro Coût Obligatoire)

- [ ] **Appel au tuteur :**
  - [ ] L'Edge Function `ai-tutor-chat` répond aux questions de l'élève.
  - [ ] En l'absence de clé API commerciale payante, le système fonctionne via modèle gratuit/local ou mode dégradé gracieux (pas de plantage de l'écran).
  - [ ] Le tuteur respecte la consigne de maïeutique : il aide sans donner directement la solution entière d'un exercice.

---

## 8. Espace Parent (Isolation Stricte)

- [ ] **Comptes parents séparés :**
  - [ ] `parent_accounts` reste totalement indépendant des comptes élèves `accounts`.
  - [ ] La connexion parent bascule sur `ParentDashboardScreen` via `parentAuthProvider`.
  - [ ] Aucun écran parent ne vient polluer la navigation mobile de l'élève.
  - [ ] Les codes de liaison parent-enfant générés restent fonctionnels dans les deux sens.

---

## 9. Intégrité des Données & Hors-Ligne

- [ ] **Intégrité Backend :**
  - [ ] Aucune migration destructive n'est appliquée sans analyse d'impact.
  - [ ] Les identifiants UUID et clés étrangères (`subject_id`, `chapter_id`, `class_node_id`) sont préservés.
- [ ] **Transparence Hors-Ligne :**
  - [ ] Les fonctionnalités non encore synchronisées en local indiquent leur statut réel sans faux succès.
  - [ ] La perte de connexion réseau affiche un message compréhensible avec bouton de réessai.

---

## 10. Accessibilité, Thème & Responsive

- [ ] **Thèmes & Contrastes :**
  - [ ] Mode Sombre, Mode Clair et Mode Système basculent instantanément sans redémarrage.
  - [ ] Le mode Contraste Élevé applique les bordures accentuées et les fonds saturés.
  - [ ] L'échelle de police (`fontScale`) agrandit les textes sans casser les boutons ni provoquer d'overflows.
- [ ] **Validation Multi-Résolutions :**
  - [ ] Testé sans overflow sur 320 px (petit Android).
  - [ ] Testé sans overflow sur 390 px (standard).
  - [ ] Testé sans overflow sur 412 px (grand smartphone).
  - [ ] Testé avec contrainte lisible sur tablette et desktop.
