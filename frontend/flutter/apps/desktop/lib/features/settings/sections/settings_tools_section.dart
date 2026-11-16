import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../../tools/desktop_tool_policy_controller.dart';

/// Settings -> Tools & Safety: D9 policy tiers, Kill Switch, Web provider config, and redacted audit ledger.
class SettingsToolsSection extends StatefulWidget {
  const SettingsToolsSection({
    super.key,
    this.toolPolicyController,
  });

  final DesktopToolPolicyController? toolPolicyController;

  @override
  State<SettingsToolsSection> createState() => _SettingsToolsSectionState();
}

class _SettingsToolsSectionState extends State<SettingsToolsSection> {
  final TextEditingController _searxngUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  String? _draftWeatherProvider;
  String? _draftWebSearchProvider;
  String? _syncedUpdatedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.toolPolicyController?.refreshAll();
    });
  }

  @override
  void dispose() {
    _searxngUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _syncDrafts(ToolPolicyOut? policy) {
    if (policy == null) return;
    final stamp = '${policy.profileId}:${policy.updatedAt}:${policy.webSearchProvider}:${policy.weatherProvider}';
    if (_syncedUpdatedAt == stamp) return;
    _syncedUpdatedAt = stamp;
    _draftWeatherProvider = policy.weatherProvider;
    _draftWebSearchProvider = policy.webSearchProvider;
    _searxngUrlController.text = policy.searxngBaseUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final ctrl = widget.toolPolicyController;

    if (ctrl == null) {
      return SoftGlassPanel(
        padding: const EdgeInsets.all(CompanionSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tools & Safety Controls',
              style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
            ),
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              'Connect to the Local AI Runtime to configure D9 deterministic action permissions, read-only web retrieval providers, and the emergency tool kill switch.',
              style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final policy = ctrl.policy;
        _syncDrafts(policy);
        final killed = ctrl.globalKillSwitch;
        final searchProvider = _draftWebSearchProvider ?? policy?.webSearchProvider ?? 'public_search';
        final weatherProvider = _draftWeatherProvider ?? policy?.weatherProvider ?? 'open_meteo';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ctrl.error != null) ...[
              Container(
                padding: const EdgeInsets.all(CompanionSpacing.md),
                decoration: BoxDecoration(
                  color: (ext?.danger ?? CompanionColors.danger).withValues(alpha: 0.12),
                  borderRadius: CompanionRadius.borderSm,
                  border: Border.all(
                    color: (ext?.danger ?? CompanionColors.danger).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  ctrl.error!,
                  style: CompanionTypography.bodySmall.copyWith(
                    color: ext?.danger ?? CompanionColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: CompanionSpacing.md),
            ],
            if (ctrl.statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(CompanionSpacing.md),
                decoration: BoxDecoration(
                  color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.12),
                  borderRadius: CompanionRadius.borderSm,
                ),
                child: Text(
                  ctrl.statusMessage!,
                  style: CompanionTypography.bodySmall.copyWith(color: ext?.accent),
                ),
              ),
              const SizedBox(height: CompanionSpacing.md),
            ],

            // 1. Emergency Global Tool Kill Switch
            SoftGlassPanel(
              padding: const EdgeInsets.all(CompanionSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        killed ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
                        color: killed
                            ? (ext?.danger ?? CompanionColors.danger)
                            : (ext?.accent ?? CompanionColors.lightAccent),
                      ),
                      const SizedBox(width: CompanionSpacing.sm),
                      Expanded(
                        child: Text(
                          'Emergency Global Tool Kill Switch',
                          style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
                        ),
                      ),
                      FilledButton.tonal(
                        key: const Key('tools_kill_switch_toggle_button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: killed
                              ? (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.15)
                              : (ext?.danger ?? CompanionColors.danger).withValues(alpha: 0.15),
                          foregroundColor: killed
                              ? (ext?.accent ?? CompanionColors.lightAccent)
                              : (ext?.danger ?? CompanionColors.danger),
                        ),
                        onPressed: ctrl.isSaving || (!killed && false)
                            ? null
                            : () async {
                                if (killed) {
                                  await ctrl.toggleKillSwitch(
                                    enabled: false,
                                    reason: 'host_admin_reset',
                                  );
                                } else {
                                  await ctrl.toggleKillSwitch(
                                    enabled: true,
                                    reason: 'user_settings_emergency_stop',
                                  );
                                }
                              },
                        child: Text(killed ? 'Disengage (Host Admin)' : 'Engage Kill Switch'),
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  Text(
                    killed
                        ? 'ACTIVE: All typed tool execution and pending confirmation execution are blocked.'
                        : 'Armed: D9 policy gates allow approved Risk 0/1/2 capabilities. Engaging halts all tools immediately; only local Host Admin can disengage.',
                    style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
                  ),
                  if (killed && !ctrl.hasHostAdmin) ...[
                    const SizedBox(height: CompanionSpacing.xs),
                    Text(
                      'Host Admin authority unavailable in this session.',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.warning ?? CompanionColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: CompanionSpacing.lg),

            // 2. Profile Risk Policy Matrix
            SoftGlassPanel(
              padding: const EdgeInsets.all(CompanionSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile D9 Action Policy',
                        style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
                      ),
                      IconButton(
                        key: const Key('tools_refresh_button'),
                        tooltip: 'Refresh policy and audit ledger',
                        onPressed: ctrl.isLoading ? null : () => ctrl.refreshAll(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  Text(
                    'External web content never has authorization authority, and Risk 2 always prevents silent auto-execution.',
                    style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  if (policy == null)
                    Text(
                      ctrl.isLoading
                          ? 'Loading profile D9 policy...'
                          : 'Sign in to an active profile to customize risk tier policies.',
                      style: CompanionTypography.bodySmall.copyWith(color: ext?.textMuted),
                    )
                  else ...[
                    _PolicyDropdownRow(
                      rowKey: const Key('policy_risk0_dropdown'),
                      title: 'Risk 0 (Read-Only & Public Weather/Search)',
                      subtitle: 'list_tasks, list_reminders, weather_lookup, web_search, web_fetch',
                      value: policy.risk0Policy,
                      options: const ['allow', 'confirm', 'deny'],
                      enabled: !ctrl.isSaving,
                      onChanged: (v) => ctrl.updatePolicy(ToolPolicyUpdate(risk0Policy: v)),
                    ),
                    const Divider(height: CompanionSpacing.lg),
                    _PolicyDropdownRow(
                      rowKey: const Key('policy_risk1_explicit_dropdown'),
                      title: 'Risk 1 — Explicit User Request',
                      subtitle: 'Reversible writes requested directly by you (e.g. create_task)',
                      value: policy.risk1ExplicitPolicy,
                      options: const ['allow', 'confirm', 'deny'],
                      enabled: !ctrl.isSaving,
                      onChanged: (v) => ctrl.updatePolicy(ToolPolicyUpdate(risk1ExplicitPolicy: v)),
                    ),
                    const Divider(height: CompanionSpacing.lg),
                    _PolicyDropdownRow(
                      rowKey: const Key('policy_risk1_suggested_dropdown'),
                      title: 'Risk 1 — Companion Suggested',
                      subtitle: 'Assistant-initiated suggestions require confirm or deny',
                      value: policy.risk1SuggestedPolicy,
                      options: const ['confirm', 'deny'],
                      enabled: !ctrl.isSaving,
                      onChanged: (v) => ctrl.updatePolicy(ToolPolicyUpdate(risk1SuggestedPolicy: v)),
                    ),
                    const Divider(height: CompanionSpacing.lg),
                    _PolicyDropdownRow(
                      rowKey: const Key('policy_risk2_dropdown'),
                      title: 'Risk 2 — Destructive / Soft-Delete Actions',
                      subtitle: 'delete_task, delete_reminder, delete_alarm (never allow-all)',
                      value: policy.risk2Policy,
                      options: const ['confirm', 'deny'],
                      enabled: !ctrl.isSaving,
                      onChanged: (v) => ctrl.updatePolicy(ToolPolicyUpdate(risk2Policy: v)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: CompanionSpacing.lg),

            // 3. Web Retrieval & Weather Configuration (Host Admin)
            SoftGlassPanel(
              padding: const EdgeInsets.all(CompanionSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Read-Only Web & Weather Providers',
                    style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  Text(
                    'Device-wide SSRF-guarded retrieval settings (Host Admin authority required to save changes or store keys).',
                    style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  _PolicyDropdownRow(
                    rowKey: const Key('web_weather_provider_dropdown'),
                    title: 'Weather Provider',
                    subtitle: 'Open-Meteo requires zero API keys',
                    value: weatherProvider,
                    options: const ['open_meteo', 'disabled'],
                    enabled: ctrl.hasHostAdmin && !ctrl.isSaving,
                    onChanged: (v) => setState(() => _draftWeatherProvider = v),
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  _PolicyDropdownRow(
                    rowKey: const Key('web_search_provider_dropdown'),
                    title: 'Web Search Provider',
                    subtitle: 'Default zero-key public search, local SearXNG, or optional API search',
                    value: searchProvider,
                    options: const ['public_search', 'searxng', 'tavily', 'brave', 'disabled'],
                    enabled: ctrl.hasHostAdmin && !ctrl.isSaving,
                    onChanged: (v) => setState(() => _draftWebSearchProvider = v),
                  ),
                  if (searchProvider == 'searxng') ...[
                    const SizedBox(height: CompanionSpacing.md),
                    TextField(
                      key: const Key('web_searxng_url_input'),
                      controller: _searxngUrlController,
                      enabled: ctrl.hasHostAdmin && !ctrl.isSaving,
                      decoration: const InputDecoration(
                        labelText: 'SearXNG Base URL',
                        hintText: 'http://127.0.0.1:8888',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (searchProvider == 'tavily' || searchProvider == 'brave') ...[
                    const SizedBox(height: CompanionSpacing.md),
                    TextField(
                      key: const Key('web_search_api_key_input'),
                      controller: _apiKeyController,
                      obscureText: true,
                      enabled: ctrl.hasHostAdmin && !ctrl.isSaving,
                      decoration: InputDecoration(
                        labelText: '${searchProvider.toUpperCase()} API Key (ACL-protected on host)',
                        hintText: (policy?.searchApiKeyConfigured ?? false)
                            ? '•••••••• (configured on device)'
                            : 'Enter optional search API key',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (policy?.searchApiKeyConfigured ?? false) ...[
                      const SizedBox(height: CompanionSpacing.sm),
                      TextButton.icon(
                        key: const Key('web_clear_api_key_button'),
                        onPressed: ctrl.hasHostAdmin && !ctrl.isSaving
                            ? () => ctrl.clearWebApiKey()
                            : null,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Clear Stored API Key'),
                      ),
                    ],
                  ],
                  const SizedBox(height: CompanionSpacing.md),
                  Row(
                    children: [
                      FilledButton(
                        key: const Key('web_save_config_button'),
                        onPressed: ctrl.hasHostAdmin && !ctrl.isSaving
                            ? () async {
                                final keyText = _apiKeyController.text.trim();
                                final ok = await ctrl.updateWebConfig(
                                  WebConfigUpdateRequest(
                                    weatherProvider: weatherProvider,
                                    webSearchProvider: searchProvider,
                                    searxngBaseUrl: searchProvider == 'searxng'
                                        ? _searxngUrlController.text.trim()
                                        : null,
                                    searchApiKey: keyText.isNotEmpty ? keyText : null,
                                  ),
                                );
                                if (ok && mounted) {
                                  _apiKeyController.clear();
                                }
                              }
                            : null,
                        child: const Text('Save Web Settings'),
                      ),
                      if (!ctrl.hasHostAdmin) ...[
                        const SizedBox(width: CompanionSpacing.md),
                        Expanded(
                          child: Text(
                            'Read-only: Host Admin authority unavailable.',
                            style: CompanionTypography.caption.copyWith(color: ext?.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: CompanionSpacing.lg),

            // 4. Risk 3 Permanently Rejected Classes + Redacted Audit Log
            SoftGlassPanel(
              padding: const EdgeInsets.all(CompanionSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catalog & Redacted Audit Ledger',
                    style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  Text(
                    'Blocked Risk 3 classes: ${(ctrl.catalog?.prohibitedCapabilities ?? const ['arbitrary_shell_execution', 'arbitrary_filesystem_write']).join(', ')}',
                    style: CompanionTypography.caption.copyWith(color: ext?.textMuted),
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  if (ctrl.auditLogs.isEmpty)
                    Text(
                      'No tool executions logged for this profile yet.',
                      style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
                    )
                  else
                    Column(
                      children: ctrl.auditLogs.take(15).map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: CompanionSpacing.sm),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (entry.outcomeStatus == 'killed' || entry.decision == 'DENY'
                                          ? (ext?.danger ?? CompanionColors.danger)
                                          : (ext?.accent ?? CompanionColors.lightAccent))
                                      .withValues(alpha: 0.14),
                                  borderRadius: CompanionRadius.borderFull,
                                ),
                                child: Text(
                                  'R${entry.riskTier} ${entry.outcomeStatus}',
                                  style: CompanionTypography.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: CompanionSpacing.sm),
                              Expanded(
                                child: Text(
                                  '${entry.toolName} (${entry.provenance})'
                                  '${entry.sourceDomains.isNotEmpty ? ' · ${entry.sourceDomains.join(', ')}' : ''}',
                                  style: CompanionTypography.bodySmall.copyWith(color: ext?.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PolicyDropdownRow extends StatelessWidget {
  const _PolicyDropdownRow({
    required this.rowKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final Key rowKey;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final effectiveValue = options.contains(value) ? value : options.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CompanionTypography.bodyMedium.copyWith(color: ext?.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: CompanionTypography.caption.copyWith(color: ext?.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: CompanionSpacing.md),
        DropdownButton<String>(
          key: rowKey,
          value: effectiveValue,
          onChanged: enabled
              ? (next) {
                  if (next != null) onChanged(next);
                }
              : null,
          items: options
              .map(
                (opt) => DropdownMenuItem<String>(
                  value: opt,
                  child: Text(opt),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
