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
