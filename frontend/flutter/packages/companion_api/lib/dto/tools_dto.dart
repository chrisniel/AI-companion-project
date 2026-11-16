import 'package:meta/meta.dart';

/// Normalized source attribution link for read-only external retrieval.
@immutable
class WebSourceRefOut {
  final String title;
  final String url;
  final String domain;
  final String? snippet;

  const WebSourceRefOut({
    required this.title,
    required this.url,
    required this.domain,
    this.snippet,
  });

  factory WebSourceRefOut.fromJson(Map<String, dynamic> json) {
    return WebSourceRefOut(
      title: json['title'] as String,
      url: json['url'] as String,
      domain: json['domain'] as String,
      snippet: json['snippet'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'domain': domain,
        if (snippet != null) 'snippet': snippet,
      };
}

/// Committed action receipt persisted on assistant turns (D-SHARED-CONV-03A).
@immutable
class ToolReceiptOut {
  final String toolName;
  final int riskTier;
  final String provenance;
  final String decision;
  final String outcomeStatus;
  final String summary;
  final int? durationMs;

  const ToolReceiptOut({
    required this.toolName,
    required this.riskTier,
    required this.provenance,
    required this.decision,
    required this.outcomeStatus,
    required this.summary,
    this.durationMs,
  });

  factory ToolReceiptOut.fromJson(Map<String, dynamic> json) {
    return ToolReceiptOut(
      toolName: json['tool_name'] as String,
      riskTier: json['risk_tier'] as int,
      provenance: json['provenance'] as String,
      decision: json['decision'] as String,
      outcomeStatus: json['outcome_status'] as String,
      summary: json['summary'] as String,
      durationMs: json['duration_ms'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'tool_name': toolName,
        'risk_tier': riskTier,
        'provenance': provenance,
        'decision': decision,
        'outcome_status': outcomeStatus,
        'summary': summary,
        if (durationMs != null) 'duration_ms': durationMs,
      };
}

/// Read-only descriptor of one registered D9 typed tool.
@immutable
class ToolCatalogItemOut {
  final String name;
  final String description;
  final int riskTier;
  final String domain;
  final bool reversible;

  const ToolCatalogItemOut({
    required this.name,
    required this.description,
    required this.riskTier,
    required this.domain,
    required this.reversible,
  });

  factory ToolCatalogItemOut.fromJson(Map<String, dynamic> json) {
    return ToolCatalogItemOut(
      name: json['name'] as String,
      description: json['description'] as String,
      riskTier: json['risk_tier'] as int,
      domain: json['domain'] as String,
      reversible: json['reversible'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'risk_tier': riskTier,
        'domain': domain,
        'reversible': reversible,
      };
}

/// Catalog of registered D9 tools plus permanently rejected Risk 3 classes.
@immutable
class ToolCatalogOut {
  final List<ToolCatalogItemOut> items;
  final List<String> prohibitedCapabilities;

  const ToolCatalogOut({
    this.items = const [],
    this.prohibitedCapabilities = const [],
  });

  factory ToolCatalogOut.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final rawProhibited = json['prohibited_capabilities'] as List? ?? const [];
    return ToolCatalogOut(
      items: rawItems
          .map((e) => ToolCatalogItemOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      prohibitedCapabilities: rawProhibited.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'prohibited_capabilities': prohibitedCapabilities,
      };
}

/// Combined profile D9 policy settings, global Kill Switch, and non-secret Web config.
@immutable
class ToolPolicyOut {
  final String profileId;
  final bool globalKillSwitch;
  final String? killSwitchUpdatedAt;
  final String? killSwitchReason;
  final String risk0Policy;
  final String risk1ExplicitPolicy;
  final String risk1SuggestedPolicy;
  final String risk2Policy;
  final String weatherProvider;
  final String webSearchProvider;
  final String? searxngBaseUrl;
  final bool searchApiKeyConfigured;
  final String updatedAt;

  const ToolPolicyOut({
    required this.profileId,
    required this.globalKillSwitch,
    this.killSwitchUpdatedAt,
    this.killSwitchReason,
    required this.risk0Policy,
    required this.risk1ExplicitPolicy,
    required this.risk1SuggestedPolicy,
    required this.risk2Policy,
    required this.weatherProvider,
    required this.webSearchProvider,
    this.searxngBaseUrl,
    this.searchApiKeyConfigured = false,
    required this.updatedAt,
  });

  factory ToolPolicyOut.fromJson(Map<String, dynamic> json) {
    return ToolPolicyOut(
      profileId: json['profile_id'] as String,
      globalKillSwitch: json['global_kill_switch'] as bool,
      killSwitchUpdatedAt: json['kill_switch_updated_at'] as String?,
      killSwitchReason: json['kill_switch_reason'] as String?,
      risk0Policy: json['risk0_policy'] as String,
      risk1ExplicitPolicy: json['risk1_explicit_policy'] as String,
      risk1SuggestedPolicy: json['risk1_suggested_policy'] as String,
      risk2Policy: json['risk2_policy'] as String,
      weatherProvider: json['weather_provider'] as String,
      webSearchProvider: json['web_search_provider'] as String,
      searxngBaseUrl: json['searxng_base_url'] as String?,
      searchApiKeyConfigured: json['search_api_key_configured'] as bool? ?? false,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'global_kill_switch': globalKillSwitch,
        if (killSwitchUpdatedAt != null) 'kill_switch_updated_at': killSwitchUpdatedAt,
        if (killSwitchReason != null) 'kill_switch_reason': killSwitchReason,
        'risk0_policy': risk0Policy,
        'risk1_explicit_policy': risk1ExplicitPolicy,
        'risk1_suggested_policy': risk1SuggestedPolicy,
        'risk2_policy': risk2Policy,
        'weather_provider': weatherProvider,
        'web_search_provider': webSearchProvider,
        if (searxngBaseUrl != null) 'searxng_base_url': searxngBaseUrl,
        'search_api_key_configured': searchApiKeyConfigured,
        'updated_at': updatedAt,
      };
}

/// Profile-scoped risk policy mutation payload.
@immutable
class ToolPolicyUpdate {
  final String? risk0Policy;
  final String? risk1ExplicitPolicy;
  final String? risk1SuggestedPolicy;
  final String? risk2Policy;

  const ToolPolicyUpdate({
    this.risk0Policy,
    this.risk1ExplicitPolicy,
    this.risk1SuggestedPolicy,
    this.risk2Policy,
  });

  factory ToolPolicyUpdate.fromJson(Map<String, dynamic> json) {
    return ToolPolicyUpdate(
      risk0Policy: json['risk0_policy'] as String?,
      risk1ExplicitPolicy: json['risk1_explicit_policy'] as String?,
      risk1SuggestedPolicy: json['risk1_suggested_policy'] as String?,
      risk2Policy: json['risk2_policy'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (risk0Policy != null) 'risk0_policy': risk0Policy,
        if (risk1ExplicitPolicy != null) 'risk1_explicit_policy': risk1ExplicitPolicy,
        if (risk1SuggestedPolicy != null) 'risk1_suggested_policy': risk1SuggestedPolicy,
        if (risk2Policy != null) 'risk2_policy': risk2Policy,
      };
}

/// Persistent Global Tool Kill Switch status.
@immutable
class KillSwitchStateOut {
  final bool globalKillSwitch;
  final String? killSwitchUpdatedAt;
  final String? killSwitchReason;

  const KillSwitchStateOut({
    required this.globalKillSwitch,
    this.killSwitchUpdatedAt,
    this.killSwitchReason,
  });

  factory KillSwitchStateOut.fromJson(Map<String, dynamic> json) {
    return KillSwitchStateOut(
      globalKillSwitch: json['global_kill_switch'] as bool,
      killSwitchUpdatedAt: json['kill_switch_updated_at'] as String?,
      killSwitchReason: json['kill_switch_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'global_kill_switch': globalKillSwitch,
        if (killSwitchUpdatedAt != null) 'kill_switch_updated_at': killSwitchUpdatedAt,
        if (killSwitchReason != null) 'kill_switch_reason': killSwitchReason,
      };
}

/// Toggle Global Tool Kill Switch request.
@immutable
class KillSwitchRequest {
  final bool enabled;
  final String? reason;

  const KillSwitchRequest({
    required this.enabled,
    this.reason,
  });

  factory KillSwitchRequest.fromJson(Map<String, dynamic> json) {
    return KillSwitchRequest(
      enabled: json['enabled'] as bool,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (reason != null) 'reason': reason,
      };
}

/// Host-Admin-only Web retrieval provider configuration update.
@immutable
class WebConfigUpdateRequest {
  final String? weatherProvider;
  final String? webSearchProvider;
  final String? searxngBaseUrl;
  final String? searchApiKey;

  const WebConfigUpdateRequest({
    this.weatherProvider,
    this.webSearchProvider,
    this.searxngBaseUrl,
    this.searchApiKey,
  });

  factory WebConfigUpdateRequest.fromJson(Map<String, dynamic> json) {
    return WebConfigUpdateRequest(
      weatherProvider: json['weather_provider'] as String?,
      webSearchProvider: json['web_search_provider'] as String?,
      searxngBaseUrl: json['searxng_base_url'] as String?,
      searchApiKey: json['search_api_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (weatherProvider != null) 'weather_provider': weatherProvider,
        if (webSearchProvider != null) 'web_search_provider': webSearchProvider,
        if (searxngBaseUrl != null) 'searxng_base_url': searxngBaseUrl,
        if (searchApiKey != null) 'search_api_key': searchApiKey,
      };
}

/// Non-secret Web retrieval provider configuration status.
@immutable
class WebConfigOut {
  final String weatherProvider;
  final String webSearchProvider;
  final String? searxngBaseUrl;
  final bool searchApiKeyConfigured;

  const WebConfigOut({
    required this.weatherProvider,
    required this.webSearchProvider,
    this.searxngBaseUrl,
    this.searchApiKeyConfigured = false,
  });

  factory WebConfigOut.fromJson(Map<String, dynamic> json) {
    return WebConfigOut(
      weatherProvider: json['weather_provider'] as String,
      webSearchProvider: json['web_search_provider'] as String,
      searxngBaseUrl: json['searxng_base_url'] as String?,
      searchApiKeyConfigured: json['search_api_key_configured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'weather_provider': weatherProvider,
        'web_search_provider': webSearchProvider,
        if (searxngBaseUrl != null) 'searxng_base_url': searxngBaseUrl,
        'search_api_key_configured': searchApiKeyConfigured,
      };
}

/// Result of clearing the device-local Web Search API key.
@immutable
class WebApiKeyClearOut {
  final bool cleared;
  final bool searchApiKeyConfigured;

  const WebApiKeyClearOut({
    required this.cleared,
    required this.searchApiKeyConfigured,
  });

  factory WebApiKeyClearOut.fromJson(Map<String, dynamic> json) {
    return WebApiKeyClearOut(
      cleared: json['cleared'] as bool,
      searchApiKeyConfigured: json['search_api_key_configured'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'cleared': cleared,
        'search_api_key_configured': searchApiKeyConfigured,
      };
}

/// Pending or resolved fingerprint-bound tool confirmation card.
@immutable
class ToolConfirmationOut {
  final String id;
  final String conversationId;
  final String toolName;
  final int riskTier;
  final String provenance;
  final String targetSummary;
  final String argumentsPreview;
  final String fingerprint;
  final String status;
  final String expiresAt;
  final String createdAt;
  final String? resolvedAt;

  const ToolConfirmationOut({
    required this.id,
    required this.conversationId,
    required this.toolName,
    required this.riskTier,
    required this.provenance,
    required this.targetSummary,
    required this.argumentsPreview,
    required this.fingerprint,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.resolvedAt,
  });

  factory ToolConfirmationOut.fromJson(Map<String, dynamic> json) {
    return ToolConfirmationOut(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      toolName: json['tool_name'] as String,
      riskTier: json['risk_tier'] as int,
      provenance: json['provenance'] as String,
      targetSummary: json['target_summary'] as String,
      argumentsPreview: json['arguments_preview'] as String,
      fingerprint: json['fingerprint'] as String,
      status: json['status'] as String,
      expiresAt: json['expires_at'] as String,
      createdAt: json['created_at'] as String,
      resolvedAt: json['resolved_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'tool_name': toolName,
        'risk_tier': riskTier,
        'provenance': provenance,
        'target_summary': targetSummary,
        'arguments_preview': argumentsPreview,
        'fingerprint': fingerprint,
        'status': status,
        'expires_at': expiresAt,
        'created_at': createdAt,
        if (resolvedAt != null) 'resolved_at': resolvedAt,
      };
}

/// List of tool confirmations for the active profile.
@immutable
class ToolConfirmationListOut {
  final List<ToolConfirmationOut> items;
  final int total;

  const ToolConfirmationListOut({
    this.items = const [],
    required this.total,
  });

  factory ToolConfirmationListOut.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? const [];
    return ToolConfirmationListOut(
      items: raw
          .map((e) => ToolConfirmationOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: json['total'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };
}

/// Explicit user resolution for a pending confirmation.
@immutable
class ToolConfirmationResolveRequest {
  final String decision;

  const ToolConfirmationResolveRequest({required this.decision});

  factory ToolConfirmationResolveRequest.fromJson(Map<String, dynamic> json) {
    return ToolConfirmationResolveRequest(decision: json['decision'] as String);
  }

  Map<String, dynamic> toJson() => {'decision': decision};
}

/// Result of atomically resolving a pending confirmation.
@immutable
class ToolConfirmationResolveResponse {
  final ToolConfirmationOut confirmation;
  final bool executed;
  final String outcomeStatus;
  final String summary;
  final List<WebSourceRefOut> sources;

  const ToolConfirmationResolveResponse({
    required this.confirmation,
    required this.executed,
    required this.outcomeStatus,
    required this.summary,
    this.sources = const [],
  });

  factory ToolConfirmationResolveResponse.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as List? ?? const [];
    return ToolConfirmationResolveResponse(
      confirmation: ToolConfirmationOut.fromJson(
        Map<String, dynamic>.from(json['confirmation'] as Map),
      ),
      executed: json['executed'] as bool,
      outcomeStatus: json['outcome_status'] as String,
      summary: json['summary'] as String,
      sources: rawSources
          .map((e) => WebSourceRefOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'confirmation': confirmation.toJson(),
        'executed': executed,
        'outcome_status': outcomeStatus,
        'summary': summary,
        'sources': sources.map((e) => e.toJson()).toList(),
      };
}

/// Redacted tool audit record (zero prompts, secrets, or personal bodies).
@immutable
class ToolAuditLogOut {
  final String id;
  final String? profileId;
  final String? conversationId;
  final String toolName;
  final int riskTier;
  final String provenance;
  final String decision;
  final String outcomeStatus;
  final int? durationMs;
  final List<String> sourceDomains;
  final String? errorCode;
  final String createdAt;

  const ToolAuditLogOut({
    required this.id,
    this.profileId,
    this.conversationId,
    required this.toolName,
    required this.riskTier,
    required this.provenance,
    required this.decision,
    required this.outcomeStatus,
    this.durationMs,
    this.sourceDomains = const [],
    this.errorCode,
    required this.createdAt,
  });

  factory ToolAuditLogOut.fromJson(Map<String, dynamic> json) {
    final rawDomains = json['source_domains'] as List? ?? const [];
    return ToolAuditLogOut(
      id: json['id'] as String,
      profileId: json['profile_id'] as String?,
      conversationId: json['conversation_id'] as String?,
      toolName: json['tool_name'] as String,
      riskTier: json['risk_tier'] as int,
      provenance: json['provenance'] as String,
      decision: json['decision'] as String,
      outcomeStatus: json['outcome_status'] as String,
      durationMs: json['duration_ms'] as int?,
      sourceDomains: rawDomains.map((e) => e.toString()).toList(),
      errorCode: json['error_code'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (profileId != null) 'profile_id': profileId,
        if (conversationId != null) 'conversation_id': conversationId,
        'tool_name': toolName,
        'risk_tier': riskTier,
        'provenance': provenance,
        'decision': decision,
        'outcome_status': outcomeStatus,
        if (durationMs != null) 'duration_ms': durationMs,
        'source_domains': sourceDomains,
        if (errorCode != null) 'error_code': errorCode,
        'created_at': createdAt,
      };
}

/// Paginated redacted tool audit ledger response.
@immutable
class ToolAuditLogListOut {
  final List<ToolAuditLogOut> items;
  final int total;

  const ToolAuditLogListOut({
    this.items = const [],
    required this.total,
  });

  factory ToolAuditLogListOut.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return ToolAuditLogListOut(
      items: rawItems
          .map((e) => ToolAuditLogOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: json['total'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };
}
