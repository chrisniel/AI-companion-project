import 'package:flutter/foundation.dart';
import '../chat/desktop_chat_controller.dart';

/// Host-only catalog and explicit browser approval; no CRUD or PIN challenge.
class DesktopProfileController extends ChangeNotifier {
  DesktopProfileController({required this.chat}) {
    _chatEpoch = chat.profileEpoch;
    chat.addListener(_onChatChanged);
  }
  final DesktopChatController chat;
  List<Map<String, dynamic>> profiles = [];
  List<Map<String, dynamic>> requests = [];
  String? selectedProfileId;
  String? activeProfileId;
  String? error;
  bool busy = false;
  bool _disposed = false;
  bool _allowDefaultBootstrap = true;
  late int _chatEpoch;
  void _onChatChanged() {
    if (_chatEpoch != chat.profileEpoch) {
      _chatEpoch = chat.profileEpoch;
      activeProfileId = null;
      _notify();
    }
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool get canUseSelected => profiles.any((p) =>
      p['id'] == selectedProfileId &&
      p['status'] == 'active' &&
      p['pin_protected'] != true);

  void select(String? id) {
    selectedProfileId = id;
    _notify();
  }

  Future<void> refresh({bool initializeDefault = false}) async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      final savedToken = await chat.client.sessionStore.readToken();
      if (savedToken == null) {
        activeProfileId = null;
      } else {
        _allowDefaultBootstrap = false;
        if (initializeDefault) {
          await chat.checkConnection(preserveSavedSessionOnFailure: true);
          final restoredProfileId = chat.authenticatedProfileId;
          if (restoredProfileId == null) {
            activeProfileId = null;
            selectedProfileId = null;
            error =
                'Saved Profile access could not be restored. Select a Profile to authorize access.';
          } else {
            activeProfileId = restoredProfileId;
            selectedProfileId = restoredProfileId;
          }
        }
      }
      profiles = await chat.client.listProfiles();
      requests = await chat.client.pendingBrowserRequests();
      if (_allowDefaultBootstrap &&
          activeProfileId == null &&
          !profiles.any((p) => p['id'] == selectedProfileId)) {
        final eligible = profiles.where((p) =>
            p['is_default'] == true &&
            p['status'] == 'active' &&
            p['pin_protected'] != true);
        selectedProfileId =
            eligible.isEmpty ? null : eligible.first['id'] as String;
      }
      if (initializeDefault &&
          _allowDefaultBootstrap &&
          activeProfileId == null &&
          canUseSelected &&
          profiles.any((p) => p['id'] == selectedProfileId && p['is_default'] == true)) {
        _allowDefaultBootstrap = false;
        await chat.selectProfile(selectedProfileId!);
        activeProfileId = chat.authenticatedProfileId;
      }
    } catch (_) {
      error =
          'Local Profile authority is unavailable. Check the trusted Windows host runtime.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> useSelected() async {
    if (busy || !canUseSelected) return;
    busy = true;
    error = null;
    activeProfileId = null;
    _notify();
    try {
      await chat.selectProfile(selectedProfileId!);
      activeProfileId = chat.authenticatedProfileId;
    } catch (_) {
      error =
          'Could not establish Profile access. Protected Profiles require an authorized unlock challenge.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> approve(String requestId) async {
    if (busy ||
        activeProfileId == null ||
        activeProfileId != selectedProfileId ||
        !canUseSelected) {
      return;
    }
    busy = true;
    error = null;
    _notify();
    try {
      await chat.client.approveBrowserRequest(requestId, activeProfileId!);
      requests = await chat.client.pendingBrowserRequests();
    } catch (_) {
      error =
          'Approval failed or request expired. Refresh requests and review again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    chat.removeListener(_onChatChanged);
    super.dispose();
  }
}
