import 'package:flutter/material.dart';

enum NodeType { country, section, educationType, classType, series }

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
  NodeType.classType: const Color(0xFFF59E0B),
  NodeType.series: const Color(0xFF06B6D4),
};

final Map<NodeType, IconData> nodeTypeIcons = {
  NodeType.country: Icons.flag_rounded,
  NodeType.section: Icons.domain_rounded,
  NodeType.educationType: Icons.school_rounded,
  NodeType.classType: Icons.class_rounded,
  NodeType.series: Icons.view_module_rounded,
};

final Map<NodeType, String> nodeTypeLabels = {
  NodeType.country: 'Pays',
  NodeType.section: 'Section',
  NodeType.educationType: "Type d'Enseignement",
  NodeType.classType: 'Classe',
  NodeType.series: 'Série',
};

final Map<NodeType, NodeType?> childNodeTypes = {
  NodeType.country: NodeType.section,
  NodeType.section: NodeType.educationType,
  NodeType.educationType: NodeType.classType,
  NodeType.classType: NodeType.series,
  NodeType.series: null,
};

final Map<NodeType, String> childNodeLabels = {
  NodeType.country: 'une Section',
  NodeType.section: "un Type d'Enseignement",
  NodeType.educationType: 'une Classe',
  NodeType.classType: 'une Série',
  NodeType.series: 'un Sous-nœud',
};

String formatNodeTypeString(String raw) {
  switch (raw) {
    case 'country':
      return 'Pays';
    case 'section':
      return 'Section';
    case 'education_type':
      return 'Type d\'Enseignement';
    case 'class':
      return 'Classe';
    case 'series':
      return 'Série';
    default:
      return raw;
  }
}
