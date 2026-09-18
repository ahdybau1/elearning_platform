import '../models/enums.dart';

class AcademicNode {
  final String id;
  final String? parentId;
  final NodeType nodeType;
  final String name;
  final String? code;
  final String? countryId;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AcademicNode> children;
  /// 'ok' | 'ambiguous' | 'incomplete' — « À vérifier » quand différent de 'ok' (migration 83).
  final String verificationStatus;
  final bool fromImport;

  AcademicNode({
    required this.id,
    this.parentId,
    required this.nodeType,
    required this.name,
    this.code,
    this.countryId,
    this.displayOrder = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AcademicNode>? children,
    this.verificationStatus = 'ok',
    this.fromImport = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        children = children ?? [];

  factory AcademicNode.fromJson(Map<String, dynamic> json) {
    final childrenData = json['children'];
    final List<AcademicNode> parsedChildren;
    if (childrenData != null && childrenData is List) {
      parsedChildren = childrenData
          .map((c) => AcademicNode.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    } else {
      parsedChildren = [];
    }

    return AcademicNode(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      nodeType: _parseNodeType(json['node_type'] as String),
      name: json['name'] as String,
      code: json['code'] as String?,
      countryId: json['country_id'] as String?,
      displayOrder: (json['display_order'] as int?) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      children: parsedChildren,
      verificationStatus: json['verification_status'] as String? ?? 'ok',
      fromImport: json['curriculum_import_id'] != null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parent_id': parentId,
        'node_type': nodeType.toString().split('.').last,
        'name': name,
        'code': code,
        'country_id': countryId,
        'display_order': displayOrder,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static NodeType _parseNodeType(String raw) {
    switch (raw) {
      case 'country':
        return NodeType.country;
      case 'section':
        return NodeType.section;
      case 'education_type':
        return NodeType.educationType;
      case 'cycle':
        return NodeType.cycle;
      case 'class':
        return NodeType.classType;
      case 'family':
        return NodeType.family;
      case 'series':
        return NodeType.series;
      case 'specialty':
        return NodeType.specialty;
      default:
        return NodeType.country;
    }
  }
}

/// Fusionne classes et séries en une liste d'options pour tout sélecteur qui rattache du contenu
/// (leçon/exercice/examen/annonce/abonnement/groupe WhatsApp...) à une classe. Une classe qui a des
/// séries n'est plus listée elle-même — son programme diffère par série — seules ses séries
/// apparaissent, avec un libellé qui reprend le nom de la classe ("2nde A" plutôt que "Série A"
/// isolée de son contexte, retour utilisateur explicite : la série doit toujours être citée avec sa
/// classe). Triée par ordre d'affichage réel (classe puis série), jamais par ordre alphabétique
/// brut des noms bruts (qui mélangeait "Classe de 2nde" et "Série A" sans lien visible entre eux).
List<AcademicNode> mergeClassOptions(
  List<AcademicNode> classes,
  List<AcademicNode> series,
) {
  final seriesByParent = <String, List<AcademicNode>>{};
  for (final s in series) {
    final parentId = s.parentId;
    if (parentId == null) continue;
    seriesByParent.putIfAbsent(parentId, () => []).add(s);
  }
  for (final group in seriesByParent.values) {
    group.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  final sortedClasses = [...classes]
    ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  final options = <AcademicNode>[];
  for (final classNode in sortedClasses) {
    final childSeries = seriesByParent[classNode.id];
    if (childSeries == null || childSeries.isEmpty) {
      options.add(classNode);
    } else {
      options.addAll(
        childSeries.map((s) => combineClassWithLeafLabel(classNode, s)),
      );
    }
  }
  return options;
}

/// Reconstruit un nœud (id/type/parent réels inchangés, seul `.name` devient le libellé combiné
/// "{classe} {feuille}") pour un affichage qui cite toujours la classe avec sa série/spécialité.
/// Utilisé par [mergeClassOptions] et par tout code qui parcourt un arbre déjà imbriqué (où classes
/// et séries arrivent comme `node.children`, pas comme deux listes plates séparées).
AcademicNode combineClassWithLeafLabel(AcademicNode classNode, AcademicNode leaf) {
  final label =
      '${shortNodeName(classNode.name)} ${shortNodeName(leaf.name)}';
  return AcademicNode(
    id: leaf.id,
    parentId: leaf.parentId,
    nodeType: leaf.nodeType,
    name: label,
    code: leaf.code,
    countryId: leaf.countryId,
    displayOrder: leaf.displayOrder,
    isActive: leaf.isActive,
    createdAt: leaf.createdAt,
    updatedAt: leaf.updatedAt,
    children: leaf.children,
    verificationStatus: leaf.verificationStatus,
    fromImport: leaf.fromImport,
  );
}

/// Retire les préfixes administratifs ("Classe de ", "Série ") pour composer un libellé court et
/// naturel ("2nde", "A") avant de les recombiner ("2nde A").
String shortNodeName(String name) => name
    .replaceFirst(RegExp(r'^Classe de\s+', caseSensitive: false), '')
    .replaceFirst(RegExp(r'^Série\s+', caseSensitive: false), '')
    .trim();

/// Une classe/série membre d'un groupe de classes jumelées (class_twin_group_members).
class TwinGroupMember {
  final String classNodeId;
  final String className;

  TwinGroupMember({required this.classNodeId, required this.className});
}

/// Groupe de classes/séries jumelées — relation réelle et persistée (migrations 19-20), distincte
/// de la fusion destructive : aucune classe n'est désactivée, seulement déclarée "même programme
/// pour cette matière précise" — une classe peut appartenir à plusieurs groupes (un par matière).
class TwinGroup {
  final String id;
  final String? label;
  final String? subjectId;
  final String? subjectName;
  final List<TwinGroupMember> members;

  TwinGroup({
    required this.id,
    this.label,
    this.subjectId,
    this.subjectName,
    required this.members,
  });
}

/// Une ligne d'aperçu d'impact avant une fusion de classes (get_class_node_merge_impact).
class MergeImpactRow {
  final String entityKey;
  final String entityLabel;
  final int rowCount;

  MergeImpactRow({required this.entityKey, required this.entityLabel, required this.rowCount});
}

/// Aperçu du nombre de leçons/exercices qui seraient dupliqués depuis un chapitre.
class ChapterDuplicationImpact {
  final int lessonCount;
  final int exerciseCount;

  ChapterDuplicationImpact({required this.lessonCount, required this.exerciseCount});
}
