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

class SchoolYear {
  final String id;
  final String countryId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final bool promotionCampaignOpen;
  final bool isActive;
  final DateTime createdAt;

  SchoolYear({
    required this.id,
    required this.countryId,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isCurrent = true,
    this.promotionCampaignOpen = false,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SchoolYear.fromJson(Map<String, dynamic> json) {
    return SchoolYear(
      id: json['id'] as String,
      countryId: json['country_id'] as String,
      name: json['name'] as String,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : DateTime.now().add(const Duration(days: 300)),
      isCurrent: json['is_current'] as bool? ?? true,
      promotionCampaignOpen:
          json['promotion_campaign_open'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'country_id': countryId,
        'name': name,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'is_current': isCurrent,
        'promotion_campaign_open': promotionCampaignOpen,
        'created_at': createdAt.toIso8601String(),
      };
}

class PromotionRecord {
  final String id;
  final String profileId;
  final String fromClassNodeId;
  final String? toClassNodeId;
  final String schoolYear;
  final String status;
  final DateTime processedAt;

  PromotionRecord({
    required this.id,
    required this.profileId,
    required this.fromClassNodeId,
    this.toClassNodeId,
    required this.schoolYear,
    required this.status,
    DateTime? processedAt,
  }) : processedAt = processedAt ?? DateTime.now();

  factory PromotionRecord.fromJson(Map<String, dynamic> json) {
    return PromotionRecord(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      fromClassNodeId: json['from_class_node_id'] as String,
      toClassNodeId: json['to_class_node_id'] as String?,
      schoolYear: json['school_year'] as String,
      status: json['status'] as String,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : DateTime.now(),
    );
  }
}

class UserSession {
  final String id;
  final String accountId;
  final String deviceFingerprint;
  final String platform;
  final bool isActive;
  final DateTime lastActiveAt;
  final DateTime createdAt;

  UserSession({
    required this.id,
    required this.accountId,
    required this.deviceFingerprint,
    required this.platform,
    this.isActive = true,
    DateTime? lastActiveAt,
    DateTime? createdAt,
  })  : lastActiveAt = lastActiveAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      deviceFingerprint: json['device_fingerprint'] as String,
      platform: json['platform'] as String,
      isActive: json['is_active'] as bool? ?? true,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.parse(json['last_active_at'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class Account {
  final String id;
  final String email;
  final String? phone;
  final String firstName;
  final String lastName;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class ParentAccount {
  final String id;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final DateTime createdAt;

  ParentAccount({
    required this.id,
    required this.email,
    required this.phone,
    required this.firstName,
    required this.lastName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ParentAccount.fromJson(Map<String, dynamic> json) {
    return ParentAccount(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class StudentProfile {
  final String id;
  final String accountId;
  final String classNodeId;
  final String status;
  final String subscriptionTier;
  final String schoolYear;
  final DateTime createdAt;

  StudentProfile({
    required this.id,
    required this.accountId,
    required this.classNodeId,
    this.status = 'actif',
    this.subscriptionTier = 'gratuit',
    required this.schoolYear,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      classNodeId: json['class_node_id'] as String,
      status: json['status'] as String? ?? 'actif',
      subscriptionTier: json['subscription_tier'] as String? ?? 'gratuit',
      schoolYear: json['school_year'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
