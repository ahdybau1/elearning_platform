class SubscriptionTier {
  final String id;
  final String name;
  final String countryId;
  final String classNodeId;
  final double price;
  final int durationDays;
  final DateTime createdAt;

  SubscriptionTier({
    required this.id,
    required this.name,
    required this.countryId,
    required this.classNodeId,
    required this.price,
    required this.durationDays,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SubscriptionTier.fromJson(Map<String, dynamic> json) {
    return SubscriptionTier(
      id: json['id'] as String,
      name: json['name'] as String,
      countryId: json['country_id'] as String,
      classNodeId: json['class_node_id'] as String,
      price: double.parse((json['price'] as num?)?.toString() ?? '0'),
      durationDays: (json['duration_days'] as int?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country_id': countryId,
        'class_node_id': classNodeId,
        'price': price,
        'duration_days': durationDays,
        'created_at': createdAt.toIso8601String(),
      };
}

class AccessMatrixEntry {
  final String id;
  final String tierId;
  final String featureKey;
  final String accessLevel;
  final Map<String, dynamic> limitParameter;
  final DateTime createdAt;

  AccessMatrixEntry({
    required this.id,
    required this.tierId,
    required this.featureKey,
    required this.accessLevel,
    Map<String, dynamic>? limitParameter,
    DateTime? createdAt,
  })  : limitParameter = limitParameter ?? {},
        createdAt = createdAt ?? DateTime.now();

  factory AccessMatrixEntry.fromJson(Map<String, dynamic> json) {
    return AccessMatrixEntry(
      id: json['id'] as String,
      tierId: json['tier_id'] as String,
      featureKey: json['feature_key'] as String,
      accessLevel: json['access_level'] as String,
      limitParameter: Map<String, dynamic>.from(json['limit_parameter'] ?? {}),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tier_id': tierId,
        'feature_key': featureKey,
        'access_level': accessLevel,
        'limit_parameter': limitParameter,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Catalogue des fonctionnalités affichées dans la Matrice de Droits (migration 28) — géré par
/// l'admin lui-même via la table `matrix_features`, plus la liste codée en dur côté Dart.
class MatrixFeature {
  final String id;
  final String featureKey;
  final String label;
  final String iconName;
  final bool isEnforced;
  final int displayOrder;

  MatrixFeature({
    required this.id,
    required this.featureKey,
    required this.label,
    this.iconName = 'lock',
    this.isEnforced = false,
    this.displayOrder = 0,
  });

  factory MatrixFeature.fromJson(Map<String, dynamic> json) {
    return MatrixFeature(
      id: json['id'] as String,
      featureKey: json['feature_key'] as String,
      label: json['label'] as String,
      iconName: json['icon_name'] as String? ?? 'lock',
      isEnforced: json['is_enforced'] as bool? ?? false,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }
}

class Transaction {
  final String id;
  final String profileId;
  final double amount;
  final String operator;
  final String status;
  final String? aggregatorRef;
  final String? phoneNumber;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.profileId,
    required this.amount,
    required this.operator,
    required this.status,
    this.aggregatorRef,
    this.phoneNumber,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      amount: double.parse((json['amount'] as num?)?.toString() ?? '0'),
      operator: json['operator'] as String,
      status: json['status'] as String,
      aggregatorRef: json['aggregator_ref'] as String?,
      phoneNumber: json['phone_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'amount': amount,
        'operator': operator,
        'status': status,
        'aggregator_ref': aggregatorRef,
        'phone_number': phoneNumber,
        'created_at': createdAt.toIso8601String(),
      };
}

class RefundRequest {
  final String id;
  final String profileId;
  final String? transactionId;
  final String reasonCategory;
  final String motive;
  final String status;
  final String? decidedBy;
  final String? decisionReason;
  final DateTime? decidedAt;
  final DateTime createdAt;
  final Transaction? transaction;

  RefundRequest({
    required this.id,
    required this.profileId,
    this.transactionId,
    required this.reasonCategory,
    required this.motive,
    required this.status,
    this.decidedBy,
    this.decisionReason,
    this.decidedAt,
    DateTime? createdAt,
    this.transaction,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    return RefundRequest(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      transactionId: json['transaction_id'] as String?,
      reasonCategory: json['reason_category'] as String,
      motive: json['motive'] as String,
      status: json['status'] as String,
      decidedBy: json['decided_by'] as String?,
      decisionReason: json['decision_reason'] as String?,
      decidedAt: json['decided_at'] != null
          ? DateTime.parse(json['decided_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      // Sans cette jointure, le montant du remboursement était TOUJOURS affiché comme "••••" côté
      // UI, y compris pour un Super-Admin habilité à le voir — fetchRefundRequests() ne demandait
      // jamais la transaction liée. Voir supabase_service.dart.
      transaction: json['transaction'] != null
          ? Transaction.fromJson(Map<String, dynamic>.from(json['transaction'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'transaction_id': transactionId,
        'reason_category': reasonCategory,
        'motive': motive,
        'status': status,
        'decided_by': decidedBy,
        'decision_reason': decisionReason,
        'decided_at': decidedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

class PaymentReconciliation {
  final String id;
  final String transactionId;
  final String issueType;
  final String? notes;
  final String? resolvedBy;
  final String status;
  final DateTime createdAt;
  final Transaction? transaction;

  PaymentReconciliation({
    required this.id,
    required this.transactionId,
    required this.issueType,
    this.notes,
    this.resolvedBy,
    required this.status,
    DateTime? createdAt,
    this.transaction,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PaymentReconciliation.fromJson(Map<String, dynamic> json) {
    return PaymentReconciliation(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      issueType: json['issue_type'] as String,
      notes: json['notes'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class ShopDocument {
  final String id;
  final String classNodeId;
  final String? subjectId;
  final String title;
  final String? description;
  final double price;
  final String documentUrl;
  final String? previewUrl;
  final int downloadsCount;
  final bool isActive;
  final DateTime createdAt;

  ShopDocument({
    required this.id,
    required this.classNodeId,
    this.subjectId,
    required this.title,
    this.description,
    required this.price,
    required this.documentUrl,
    this.previewUrl,
    this.downloadsCount = 0,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ShopDocument.fromJson(Map<String, dynamic> json) {
    return ShopDocument(
      id: json['id'] as String,
      classNodeId: json['class_node_id'] as String,
      subjectId: json['subject_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: double.parse((json['price'] as num?)?.toString() ?? '500'),
      documentUrl: json['document_url'] as String? ?? '',
      previewUrl: json['preview_url'] as String?,
      downloadsCount: (json['downloads_count'] as int?) ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'class_node_id': classNodeId,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'price': price,
        'document_url': documentUrl,
        'preview_url': previewUrl,
        'downloads_count': downloadsCount,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}

class CharityCampaign {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final double collectedAmount;
  final String? imageUrl;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  CharityCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    this.collectedAmount = 0.0,
    this.imageUrl,
    this.isActive = true,
    required this.startDate,
    this.endDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CharityCampaign.fromJson(Map<String, dynamic> json) {
    return CharityCampaign(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      targetAmount:
          double.parse((json['target_amount'] as num?)?.toString() ?? '0'),
      collectedAmount:
          double.parse((json['collected_amount'] as num?)?.toString() ?? '0'),
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'target_amount': targetAmount,
        'collected_amount': collectedAmount,
        'image_url': imageUrl,
        'is_active': isActive,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

class Donation {
  final String id;
  final String donorName;
  final String? donorEmail;
  final String? donorPhone;
  final double amount;
  final String currency;
  final String operator;
  final String? charityCampaignId;
  final String? receiptUrl;
  final DateTime createdAt;

  Donation({
    required this.id,
    required this.donorName,
    this.donorEmail,
    this.donorPhone,
    required this.amount,
    this.currency = 'XAF',
    this.operator = 'Mobile Money',
    this.charityCampaignId,
    this.receiptUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'] as String,
      donorName: json['donor_name'] as String,
      donorEmail: json['donor_email'] as String?,
      donorPhone: json['donor_phone'] as String?,
      amount: double.parse((json['amount'] as num?)?.toString() ?? '0'),
      currency: json['currency'] as String? ?? 'XAF',
      operator: json['operator'] as String? ?? 'Mobile Money',
      charityCampaignId: json['charity_campaign_id'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'donor_name': donorName,
        'donor_email': donorEmail,
        'donor_phone': donorPhone,
        'amount': amount,
        'currency': currency,
        'operator': operator,
        'charity_campaign_id': charityCampaignId,
        'receipt_url': receiptUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
