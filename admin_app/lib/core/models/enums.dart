import 'package:flutter/material.dart';

enum NodeType {
  country,
  section,
  educationType,
  cycle,
  classType,
  family,
  series,
  specialty,
}

enum AccessLevel { complete, limited, none }

enum PermissionKey {
  viewFinancials,
  manageAcademicTree,
  publishContent,
  moderateForum,
  reconcilePayments,
  viewAiCosts,
}

enum TransactionStatus { pending, success, failed, ambiguous }

enum RefundStatus { enAttente, accepte, refuse }

enum RefundReasonCategory { technique, insatisfaction, changementSituation }

enum SupportTicketStatus { ouvert, enCours, repondu, ferme }

enum SupportTicketCategory { paiement, technique, contenu, autre }

enum EventType { examenBlanc, olympiade }

enum PricingMode { inclus, payant }

enum NotificationChannel { push, email, sms, inApp }

enum NotificationUrgency { info, warning, urgent }

enum AnnouncementScope { all, country, classNode }

enum LogLevel { create, update, delete, publish, reconcile, refund }

enum ContentType { lesson, exercise }

enum ValidationStatus { brouillon, enAttente, approuve, rejete, aCorriger }

enum ContentStatus { published, pending, draft, archived }

enum ExerciseType { training, evaluation }

enum ExerciseFormat { qcm, reponseCourte, redaction, manuscritScan, flashcard }

enum ExerciseDifficulty { facile, intermediaire, approfondissement }

// Conversions vers/depuis les valeurs exactes des contraintes CHECK de la table `exercises`
// (voir supabase/reset_project_schema.sql). Ne jamais dériver ces chaînes de `enum.toString()` :
// les noms Dart (ex: "training", "intermediaire") ne correspondent pas aux valeurs DB françaises
// avec accents (ex: "entraînement", "intermédiaire").
String exerciseTypeToDb(ExerciseType t) =>
    t == ExerciseType.evaluation ? 'évaluation' : 'entraînement';

ExerciseType exerciseTypeFromDb(String? raw) =>
    raw == 'évaluation' ? ExerciseType.evaluation : ExerciseType.training;

String exerciseFormatToDb(ExerciseFormat f) {
  switch (f) {
    case ExerciseFormat.qcm:
      return 'qcm';
    case ExerciseFormat.reponseCourte:
      return 'reponse_courte';
    case ExerciseFormat.redaction:
      return 'redaction';
    case ExerciseFormat.manuscritScan:
      return 'manuscrit_scan';
    case ExerciseFormat.flashcard:
      return 'flashcard';
  }
}

ExerciseFormat exerciseFormatFromDb(String? raw) {
  switch (raw) {
    case 'reponse_courte':
      return ExerciseFormat.reponseCourte;
    case 'redaction':
      return ExerciseFormat.redaction;
    case 'manuscrit_scan':
      return ExerciseFormat.manuscritScan;
    case 'flashcard':
      return ExerciseFormat.flashcard;
    default:
      return ExerciseFormat.qcm;
  }
}

String exerciseDifficultyToDb(ExerciseDifficulty d) {
  switch (d) {
    case ExerciseDifficulty.facile:
      return 'facile';
    case ExerciseDifficulty.intermediaire:
      return 'intermédiaire';
    case ExerciseDifficulty.approfondissement:
      return 'approfondissement';
  }
}

ExerciseDifficulty exerciseDifficultyFromDb(String? raw) {
  switch (raw) {
    case 'intermédiaire':
      return ExerciseDifficulty.intermediaire;
    case 'approfondissement':
      return ExerciseDifficulty.approfondissement;
    default:
      return ExerciseDifficulty.facile;
  }
}

enum TierName { gratuit, journalier, hebdomadaire, mensuel, annuel }

final Map<TierName, String> tierNames = {
  TierName.gratuit: 'gratuit',
  TierName.journalier: 'journalier',
  TierName.hebdomadaire: 'hebdomadaire',
  TierName.mensuel: 'mensuel',
  TierName.annuel: 'annuel',
};

final Map<NodeType, Color> nodeTypeColors = {
  NodeType.country: const Color(0xFF10B981),
  NodeType.section: const Color(0xFF3B82F6),
  NodeType.educationType: const Color(0xFF6366F1),
  NodeType.cycle: const Color(0xFF8B5CF6),
  NodeType.classType: const Color(0xFFF59E0B),
  NodeType.family: const Color(0xFFEC4899),
  NodeType.series: const Color(0xFF06B6D4),
  NodeType.specialty: const Color(0xFFEF4444),
};

final Map<NodeType, IconData> nodeTypeIcons = {
  NodeType.country: Icons.flag_rounded,
  NodeType.section: Icons.domain_rounded,
  NodeType.educationType: Icons.school_rounded,
  NodeType.cycle: Icons.layers_rounded,
  NodeType.classType: Icons.class_rounded,
  NodeType.family: Icons.category_rounded,
  NodeType.series: Icons.view_module_rounded,
  NodeType.specialty: Icons.workspace_premium_rounded,
};

final Map<NodeType, String> nodeTypeLabels = {
  NodeType.country: 'Pays',
  NodeType.section: 'Section',
  NodeType.educationType: "Type d'Enseignement",
  NodeType.cycle: 'Cycle',
  NodeType.classType: 'Classe',
  NodeType.family: 'Famille',
  NodeType.series: 'Série',
  NodeType.specialty: 'Spécialité',
};

/// Types d'enfants AUTORISÉS sous chaque type de nœud (plusieurs possibles, pas un seul type
/// imposé) — permet de sauter des niveaux intermédiaires (ex: ajouter une Classe directement sous
/// un Pays sans devoir créer Section puis Type d'Enseignement). Reflète aussi l'arbre camerounais
/// réel (migration 88) : education_type -> cycle -> classe -> série|famille -> (sous-famille)*
/// -> spécialité ; certaines filières techniques anglophones rattachent un cycle directement sous
/// une famille (ex. Industrial -> First/Second Cycle). Spécialité et Série restent terminales : le
/// contenu pédagogique s'y rattache via class_node_id, pas via l'arbre.
final Map<NodeType, List<NodeType>> childNodeTypeOptions = {
  NodeType.country: [NodeType.section, NodeType.educationType, NodeType.classType],
  NodeType.section: [NodeType.educationType, NodeType.classType],
  NodeType.educationType: [NodeType.cycle, NodeType.classType, NodeType.family],
  NodeType.cycle: [NodeType.classType],
  NodeType.classType: [NodeType.series, NodeType.family],
  NodeType.family: [NodeType.cycle, NodeType.family, NodeType.specialty],
  NodeType.series: [],
  NodeType.specialty: [],
};


String nodeTypeToDb(NodeType type) {
  switch (type) {
    case NodeType.country:
      return 'country';
    case NodeType.section:
      return 'section';
    case NodeType.educationType:
      return 'education_type';
    case NodeType.cycle:
      return 'cycle';
    case NodeType.classType:
      return 'class';
    case NodeType.family:
      return 'family';
    case NodeType.series:
      return 'series';
    case NodeType.specialty:
      return 'specialty';
  }
}

String formatNodeTypeString(String raw) {
  switch (raw) {
    case 'country':
      return 'Pays';
    case 'section':
      return 'Section';
    case 'education_type':
      return 'Type d\'Enseignement';
    case 'cycle':
      return 'Cycle';
    case 'class':
      return 'Classe';
    case 'family':
      return 'Famille';
    case 'series':
      return 'Série';
    case 'specialty':
      return 'Spécialité';
    default:
      return raw;
  }
}
