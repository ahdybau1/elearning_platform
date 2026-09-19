class CapabilitySummary {
  const CapabilitySummary({
    required this.id,
    required this.label,
    required this.inputModalities,
    required this.outputModalities,
    required this.degradedStrategy,
    required this.allowedRoles,
    required this.pipelineStages,
    required this.providerCount,
    required this.approvedProviderCount,
  });

  factory CapabilitySummary.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const []).cast<String>();
    return CapabilitySummary(
      id: json['id'] as String,
      label: json['label'] as String,
      inputModalities: strings('input_modalities'),
      outputModalities: strings('output_modalities'),
      degradedStrategy: strings('degraded_strategy'),
      allowedRoles: strings('allowed_roles'),
      pipelineStages: strings('pipeline_stages'),
      providerCount: json['provider_count'] as int? ?? 0,
      approvedProviderCount: json['approved_provider_count'] as int? ?? 0,
    );
  }

  final String id;
  final String label;
  final List<String> inputModalities;
  final List<String> outputModalities;
  final List<String> degradedStrategy;
  final List<String> allowedRoles;
  final List<String> pipelineStages;
  final int providerCount;
  final int approvedProviderCount;
}

class CapabilityPlanRequest {
  const CapabilityPlanRequest({
    required this.capabilityId,
    required this.availableTargets,
    this.deviceTier = 'L0',
    this.online = true,
    this.commercialUse = true,
    this.allowConditionalLicenses = false,
    this.allowGpu = false,
  });

  final String capabilityId;
  final List<String> availableTargets;
  final String deviceTier;
  final bool online;
  final bool commercialUse;
  final bool allowConditionalLicenses;
  final bool allowGpu;

  Map<String, dynamic> toJson() => {
        'capability_id': capabilityId,
        'available_targets': availableTargets,
        'device_tier': deviceTier,
        'online': online,
        'commercial_use': commercialUse,
        'allow_conditional_licenses': allowConditionalLicenses,
        'allow_gpu': allowGpu,
      };
}

class ProviderDecision {
  const ProviderDecision({
    required this.providerId,
    required this.name,
    required this.eligible,
    required this.reasons,
    required this.adapter,
    required this.executionTargets,
    required this.stages,
  });

  factory ProviderDecision.fromJson(Map<String, dynamic> json) => ProviderDecision(
        providerId: json['provider_id'] as String,
        name: json['name'] as String,
        eligible: json['eligible'] as bool,
        reasons: (json['reasons'] as List<dynamic>? ?? const []).cast<String>(),
        adapter: json['adapter'] as String,
        executionTargets:
            (json['execution_targets'] as List<dynamic>? ?? const []).cast<String>(),
        stages: (json['stages'] as List<dynamic>? ?? const []).cast<String>(),
      );

  final String providerId;
  final String name;
  final bool eligible;
  final List<String> reasons;
  final String adapter;
  final List<String> executionTargets;
  final List<String> stages;
}

class CapabilityPlan {
  const CapabilityPlan({
    required this.capabilityId,
    required this.eligible,
    required this.rejected,
    required this.degradedStrategy,
    required this.uncoveredStages,
    required this.zeroCostEnforced,
  });

  factory CapabilityPlan.fromJson(Map<String, dynamic> json) {
    List<ProviderDecision> decisions(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ProviderDecision.fromJson)
            .toList(growable: false);
    return CapabilityPlan(
      capabilityId: json['capability_id'] as String,
      eligible: decisions('eligible'),
      rejected: decisions('rejected'),
      degradedStrategy:
          (json['degraded_strategy'] as List<dynamic>? ?? const []).cast<String>(),
      uncoveredStages:
          (json['uncovered_stages'] as List<dynamic>? ?? const []).cast<String>(),
      zeroCostEnforced: json['zero_cost_enforced'] as bool? ?? false,
    );
  }

  final String capabilityId;
  final List<ProviderDecision> eligible;
  final List<ProviderDecision> rejected;
  final List<String> degradedStrategy;
  final List<String> uncoveredStages;
  final bool zeroCostEnforced;
}
