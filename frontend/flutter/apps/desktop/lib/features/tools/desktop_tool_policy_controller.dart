import 'dart:async';

import 'package:companion_api/companion_api.dart';
import 'package:flutter/foundation.dart';

/// Manages D9 deterministic tool policy, global Kill Switch, Web info config,
/// and redacted tool audit logs for the desktop application.
class DesktopToolPolicyController extends ChangeNotifier {
  DesktopToolPolicyController({
    required CompanionClient Function() clientProvider,
  }) : _clientProvider = clientProvider;

  final CompanionClient Function() _clientProvider;

  ToolCatalogOut? _catalog;
  ToolPolicyOut? _policy;
  KillSwitchStateOut? _killSwitch;
  List<ToolAuditLogOut> _auditLogs = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasHostAdmin = false;
  String? _error;
  String? _statusMessage;
  bool _isDisposed = false;

  ToolCatalogOut? get catalog => _catalog;
  ToolPolicyOut? get policy => _policy;
  KillSwitchStateOut? get killSwitch => _killSwitch;
  List<ToolAuditLogOut> get auditLogs => List.unmodifiable(_auditLogs);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasHostAdmin => _hasHostAdmin;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  bool get isDisposed => _isDisposed;

  bool get globalKillSwitch =>
      _killSwitch?.globalKillSwitch ?? _policy?.globalKillSwitch ?? false;

  CompanionClient get client => _clientProvider();

  /// Checks safely whether local native Host Admin authority is available.
  Future<bool> hasHostAdminAuthority() async {
    try {
      final token = await client.hostAdminStore?.readToken();
      final available = token != null && token.trim().isNotEmpty;
      if (_hasHostAdmin != available && !_isDisposed) {
        _hasHostAdmin = available;
        notifyListeners();
      } else {
        _hasHostAdmin = available;
      }
      return available;
    } catch (_) {
      _hasHostAdmin = false;
      return false;
    }
  }

  /// Clears profile-scoped policy/audit cache when switching or signing out of a profile.
  void resetForProfileChange() {
    if (_isDisposed) return;
    _policy = null;
    _auditLogs = const [];
    _error = null;
    _statusMessage = null;
    notifyListeners();
  }

  /// Refreshes tool catalog, profile D9 policy, global Kill Switch, and audit logs.
  Future<void> refreshAll() async {
    if (_isDisposed) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await hasHostAdminAuthority();
      final c = client;
      final sessionToken = await c.sessionStore.readToken();
      if (sessionToken != null && sessionToken.isNotEmpty) {
        final results = await Future.wait<dynamic>([
          c.getToolCatalog(),
          c.getToolPolicy(),
          c.getKillSwitch(),
          c.listToolAuditLogs(limit: 40),
        ]);
        if (_isDisposed) return;
        _catalog = results[0] as ToolCatalogOut;
        _policy = results[1] as ToolPolicyOut;
        _killSwitch = results[2] as KillSwitchStateOut;
        _auditLogs = (results[3] as ToolAuditLogListOut).items;
      } else if (_hasHostAdmin) {
        _killSwitch = await c.getKillSwitch(useHostAdmin: true);
      }
    } on CompanionApiException catch (e) {
      if (_isDisposed) return;
      _error = e.message;
    } catch (e) {
      if (_isDisposed) return;
      _error = e.toString();
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Refreshes only the persistent Kill Switch state (profile or Host Admin).
  Future<void> refreshKillSwitch() async {
    if (_isDisposed) return;
    try {
      final hasAdmin = await hasHostAdminAuthority();
      final sessionToken = await client.sessionStore.readToken();
      final useAdmin = (sessionToken == null || sessionToken.isEmpty) && hasAdmin;
      if ((sessionToken == null || sessionToken.isEmpty) && !hasAdmin) return;
      _killSwitch = await client.getKillSwitch(useHostAdmin: useAdmin);
      if (!_isDisposed) notifyListeners();
    } catch (_) {}
  }

  /// Updates profile-scoped D9 risk tier policies.
  Future<bool> updatePolicy(ToolPolicyUpdate payload) async {
    if (_isDisposed) return false;
    _isSaving = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      _policy = await client.updateToolPolicy(payload);
      _statusMessage = 'Action policy updated.';
      return true;
    } on CompanionApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      if (!_isDisposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Engages emergency Kill Switch (any active session) or disengages it (Host Admin required).
  Future<bool> toggleKillSwitch({required bool enabled, String? reason}) async {
    if (_isDisposed) return false;
    _isSaving = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      if (!enabled) {
        final adminOk = await hasHostAdminAuthority();
        if (!adminOk) {
          _error =
              'Host Admin authority unavailable. Run on native host to disengage Kill Switch.';
          return false;
        }
      }
      final updated = await client.setKillSwitch(
        KillSwitchRequest(enabled: enabled, reason: reason),
        useHostAdmin: !enabled,
      );
      _killSwitch = updated;
      if (_policy != null) {
        final p = _policy!;
        _policy = ToolPolicyOut(
          profileId: p.profileId,
          globalKillSwitch: updated.globalKillSwitch,
          killSwitchUpdatedAt: updated.killSwitchUpdatedAt,
          killSwitchReason: updated.killSwitchReason,
          risk0Policy: p.risk0Policy,
          risk1ExplicitPolicy: p.risk1ExplicitPolicy,
          risk1SuggestedPolicy: p.risk1SuggestedPolicy,
          risk2Policy: p.risk2Policy,
          weatherProvider: p.weatherProvider,
          webSearchProvider: p.webSearchProvider,
          searxngBaseUrl: p.searxngBaseUrl,
          searchApiKeyConfigured: p.searchApiKeyConfigured,
          updatedAt: p.updatedAt,
        );
      }
      _statusMessage = enabled
          ? 'Global Tool Kill Switch engaged.'
          : 'Global Tool Kill Switch disengaged by Host Admin.';
      unawaited(refreshAuditLogs());
      return true;
    } on CompanionApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      if (!_isDisposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Updates device-level Web Info providers / ACL-protected Search API key (Host Admin only).
  Future<bool> updateWebConfig(WebConfigUpdateRequest payload) async {
    if (_isDisposed) return false;
    _isSaving = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final adminOk = await hasHostAdminAuthority();
      if (!adminOk) {
        _error = 'Host Admin authority unavailable to update Web configuration.';
        return false;
      }
      final updated = await client.updateWebConfig(payload);
      if (_policy != null) {
        final p = _policy!;
        _policy = ToolPolicyOut(
          profileId: p.profileId,
          globalKillSwitch: p.globalKillSwitch,
          killSwitchUpdatedAt: p.killSwitchUpdatedAt,
          killSwitchReason: p.killSwitchReason,
          risk0Policy: p.risk0Policy,
          risk1ExplicitPolicy: p.risk1ExplicitPolicy,
          risk1SuggestedPolicy: p.risk1SuggestedPolicy,
          risk2Policy: p.risk2Policy,
          weatherProvider: updated.weatherProvider,
          webSearchProvider: updated.webSearchProvider,
          searxngBaseUrl: updated.searxngBaseUrl,
          searchApiKeyConfigured: updated.searchApiKeyConfigured,
          updatedAt: p.updatedAt,
        );
      }
      _statusMessage = 'Web retrieval settings saved.';
      return true;
    } on CompanionApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      if (!_isDisposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Deletes local ACL-protected Web Search API key (Host Admin only).
  Future<bool> clearWebApiKey() async {
    if (_isDisposed) return false;
    _isSaving = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final adminOk = await hasHostAdminAuthority();
      if (!adminOk) {
        _error = 'Host Admin authority unavailable to clear Web Search API key.';
        return false;
      }
      final res = await client.clearWebApiKey();
      if (_policy != null) {
        final p = _policy!;
        _policy = ToolPolicyOut(
          profileId: p.profileId,
          globalKillSwitch: p.globalKillSwitch,
          killSwitchUpdatedAt: p.killSwitchUpdatedAt,
          killSwitchReason: p.killSwitchReason,
          risk0Policy: p.risk0Policy,
          risk1ExplicitPolicy: p.risk1ExplicitPolicy,
          risk1SuggestedPolicy: p.risk1SuggestedPolicy,
          risk2Policy: p.risk2Policy,
          weatherProvider: p.weatherProvider,
          webSearchProvider: p.webSearchProvider,
          searxngBaseUrl: p.searxngBaseUrl,
          searchApiKeyConfigured: res.searchApiKeyConfigured,
          updatedAt: p.updatedAt,
        );
      }
      _statusMessage = 'Stored Web Search API key cleared.';
      return true;
    } on CompanionApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      if (!_isDisposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Refreshes only redacted audit ledger records.
  Future<void> refreshAuditLogs() async {
    if (_isDisposed) return;
    try {
      final res = await client.listToolAuditLogs(limit: 40);
      if (!_isDisposed) {
        _auditLogs = res.items;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
