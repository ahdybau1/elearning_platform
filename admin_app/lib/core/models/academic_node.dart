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
      case 'class':
        return NodeType.classType;
      case 'series':
        return NodeType.series;
      default:
        return NodeType.country;
    }
  }
}

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
