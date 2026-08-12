class AdminUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final Map<String, dynamic> scopeJson;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    Map<String, dynamic>? scopeJson,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : scopeJson = scopeJson ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      role: json['role'] as String,
      scopeJson: Map<String, dynamic>.from(json['scope_json'] ?? {}),
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'scope_json': scopeJson,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class AdminPermission {
  final String id;
  final String adminUserId;
  final String permissionKey;
  final bool granted;
  final DateTime createdAt;

  AdminPermission({
    required this.id,
    required this.adminUserId,
    required this.permissionKey,
    this.granted = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AdminPermission.fromJson(Map<String, dynamic> json) {
    return AdminPermission(
      id: json['id'] as String,
      adminUserId: json['admin_user_id'] as String,
      permissionKey: json['permission_key'] as String,
      granted: (json['granted'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class AuditLog {
  final String id;
  final String? adminUserId;
  final String actionType;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? beforeJson;
  final Map<String, dynamic>? afterJson;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    this.adminUserId,
    required this.actionType,
    required this.entityType,
    this.entityId,
    this.beforeJson,
    this.afterJson,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      adminUserId: json['admin_user_id'] as String?,
      actionType: json['action_type'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      beforeJson: json['before_json'] != null
          ? Map<String, dynamic>.from(json['before_json'])
          : null,
      afterJson: json['after_json'] != null
          ? Map<String, dynamic>.from(json['after_json'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
