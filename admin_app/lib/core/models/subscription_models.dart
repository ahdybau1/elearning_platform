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
