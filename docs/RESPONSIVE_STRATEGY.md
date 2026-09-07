# Stratégie Responsive Mobile-First & Multi-Écrans (RESPONSIVE_STRATEGY)

**Date :** 2026-09-05  
**Projet :** EDLEARN Student Application (Flutter)  
**Objectif :** Garantir une expérience impeccable du plus petit smartphone Android (320 px) jusqu'à l'écran d'ordinateur (desktop/PWA), avec priorité absolue au smartphone.

---

## 1. Philosophie & Règle Mobile-First

1. **Le téléphone n'est pas un desktop rétréci :** L'interface est conçue pour l'interaction à une main avec le pouce, les listes à défilement vertical naturel et une densité d'information maîtrisée.
2. **Le desktop n'est pas le modèle de référence :** Sur grand écran, le contenu n'est jamais bêtement étiré d'un bord à l'autre ; il est contraint dans une largeur de lecture optimale pour éviter la dispersion du regard.
3. **Zéro Overflow Garanti :** Aucun composant ne doit utiliser de largeurs fixes rigides supérieures à 280 px sans être encapsulé dans un `Flexible`, `Expanded` ou un défilement horizontal sécurisé.

---

## 2. Grille de Breakpoints Officiels

L'ancien breakpoint unique de 700 px est remplacé par une échelle à 4 paliers :

```
[320 px - 599 px]  --> Mobile Compact & Standard (Priorité Absolue)
[600 px - 899 px]  --> Grande Phablette & Tablette Portrait
[900 px - 1199 px] --> Tablette Paysage & Petit Ordinateur
[1200 px et +]     --> Desktop & Écran Large
```

| Breakpoint Token | Plage de Largeur | Cible Matérielle Type | Stratégie Layout | Navigation |
| :--- | :--- | :--- | :--- | :--- |
| **`mobileCompact`** | `320 px - 359 px` | Très anciens smartphones Android (ex: Tecno, Itel, Galaxy A01) | 1 colonne stricte, padding 12-14 px, ratio texte ajusté | `StudentBottomBar` compacte |
| **`mobileStandard`**| `360 px - 430 px` | Smartphones Android & iOS courants (Galaxy A12/A54, Redmi, iPhone 11-15) | 1 colonne, padding 16-20 px, grilles 2 colonnes adaptatives | `StudentBottomBar` 5 onglets |
| **`tabletPortrait`**| `600 px - 899 px` | Tablettes 7-10 pouces en portrait, pliables dépliés | 2 colonnes (cours + exercices), contrainte max-width 720 px | `StudentBottomBar` ou NavigationRail |
| **`tabletLandscape`**| `900 px - 1199 px`| Tablettes en paysage, ordinateurs portables compacts | Layout 2 à 3 volets, max-width 960 px centré | `NavigationRail` permanent à gauche (72 px) |
| **`desktop`** | `1200 px +` | Ordinateurs de bureau, écrans larges PWA | Layout centré contraint à 1140 px max, sidebar latérale 240 px | `Sidebar` étendue avec sous-menus |

---

## 3. Adaptation Précise par Format Mobile

### 3.1 Très Petits Smartphones (320 px à 359 px)
- **Contraintes :** Espace horizontal très restreint. Deux boutons de texte côte à côte risquent de déborder.
- **Règles appliquées :**
  - Marges latérales réduites de 20 px à **14 px**.
  - Remplacement des grilles de matières à 2 colonnes par une **liste enrichie à 1 colonne** pour éviter que les titres longs de matières ("Mathématiques Appliquées") ne soient tronqués à 4 lettres.
  - Les paires de boutons côte à côte passent en **pile verticale** (`Column`).
  - Textes d'en-tête plafonnés avec `TextOverflow.ellipsis` et `maxLines: 1`.

### 3.2 Smartphones Standards (360 px, 375 px, 390 px, 412 px)
- **Format de référence de conception.**
- Grilles de 2 colonnes avec ratio hauteur/largeur calibré à `childAspectRatio: 1.15` à `1.30`.
- Zone de défilement verticale fluide avec rebond doux.
- Barre d'action inférieure (`StudentBottomBar`) ancrée au bas avec `SafeArea`.

---

## 4. Stratégie Tablette & Ordinateur

### 4.1 Largeur Maximale Lisible (Max Content Width)
Un cours pédagogique dont les lignes font 1400 px de large est illisible pour un être humain (fatigue oculaire de balayage).
- **Leçons & Cours :** Largeur maximale de lecture plafonnée à **760 px** au centre de l'écran, bordée de marges latérales équilibrées.
- **Tableaux de bord & Grilles :** Largeur maximale plafonnée à **1080 px**, organisée en 2 ou 3 colonnes structurées.

### 4.2 Deuxième Volet Contextuel (Master-Detail) sur Tablette
- Sur écran $\ge 900$ px, l'écran des chapitres et des leçons adopte un agencement côte-à-côte :
  - **Volet gauche (320 px) :** Sommaire du cours, liste des leçons du chapitre, progression.
  - **Volet droit (espace restant) :** Lecteur de la leçon sélectionnée ou lanceur d'exercices.

---

## 5. Gestion des Modales et Boîtes de Dialogue

- **Sur Mobile (<600 px) :**
  - Utilisation systématique de **`ModalBottomSheet`** (feuille coulissant depuis le bas de l'écran).
  - Facile à fermer d'un glissement vers le bas, accessible au pouce.
- **Sur Tablette & Desktop ($\ge 600$ px) :**
  - Transformation automatique en **`Dialog` centré** avec largeur fixe (420 à 520 px), coins arrondis à 16 px et fond sombre estompé.

---

## 6. Accessibilité Clavier et Redimensionnement de Police

- **`TextScaler` Dynamique :** Tous les conteneurs sensibles utilisent des contraintes souples (`constraints: BoxConstraints(minHeight: 48)`) plutôt que des hauteurs rigides (`height: 48`), pour que le texte grossi par l'accessibilité élève (+30%) n'entraîne aucun overflow vertical.
- **Scroll Horizontal Sécurisé :** Les formules mathématiques longues, tableaux de données ou blocs de code informatique sont enveloppés dans un `SingleChildScrollView(scrollDirection: Axis.horizontal)` avec indicateur visuel de défilement pour ne jamais bloquer la largeur de la page.
