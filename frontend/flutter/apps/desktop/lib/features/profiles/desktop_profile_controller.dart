import 'package:companion_api/companion_api.dart';
import 'package:flutter/foundation.dart';
import '../../platform/desktop_client_settings.dart';
import '../chat/desktop_chat_controller.dart';

/// Controller managing local Profile catalog, persistent selection, switching, creation, and renaming.
class DesktopProfileController extends ChangeNotifier {
  DesktopProfileController({required this.chat, this.clientSettings}) {
    _chatEpoch = chat.profileEpoch;
    chat.addListener(_onChatChanged);
  }

  final DesktopChatController chat;
  final DesktopClientSettings? clientSettings;

  List<Map<String, dynamic>> profiles = [];
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> deletedProfiles = [];
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

  Map<String, dynamic>? get activeProfile =>
      profiles.cast<Map<String, dynamic>?>().firstWhere(
            (p) => p?['id'] == activeProfileId,
            orElse: () => null,
          );

  String? get activeProfileName =>
      activeProfile?['name'] as String? ?? chat.authenticatedProfileName;

  bool get canUseSelected => profiles.any((p) =>
      p['id'] == selectedProfileId &&
      p['status'] == 'active' &&
      p['pin_protected'] != true);

  String formatProfileDisplayName(Map<String, dynamic> profile) {
    final name = profile['name']?.toString() ?? 'Profile';
    final isDefault = profile['is_default'] == true;
    if (isDefault) return '$name (Personal / Default)';
    return name;
  }

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
      final persistedProfileId = await clientSettings?.readSelectedProfileId();
      final persistedExpiry = await clientSettings?.readSelectedProfileSessionExpiry();
      final explicitlyLocked = await clientSettings?.readProfileExplicitlyLocked() ?? false;

      final nowUtc = DateTime.now().toUtc();
      final isNaturalExpiry = persistedExpiry != null && persistedExpiry.isBefore(nowUtc);
      bool shouldAttemptNaturalExpiryBootstrap = false;

      if (explicitlyLocked) {
        // Case 1: Explicitly signed out / locked
        activeProfileId = null;
        if (persistedProfileId != null) {
          selectedProfileId = persistedProfileId;
        }
      } else if (savedToken != null) {
        // Case 2: Saved bearer token exists
        _allowDefaultBootstrap = false;
        if (initializeDefault) {
          await chat.checkConnection(preserveSavedSessionOnFailure: true);
          final restoredProfileId = chat.authenticatedProfileId;
          if (restoredProfileId != null) {
            activeProfileId = restoredProfileId;
            selectedProfileId = restoredProfileId;
            await clientSettings?.writeSelectedProfileId(restoredProfileId);
            await clientSettings?.writeSelectedProfileSessionExpiry(chat.authenticatedSessionExpiry);
            await clientSettings?.writeProfileExplicitlyLocked(false);
          } else {
            // Check if natural 12-hour expiry occurred
            if (isNaturalExpiry && persistedProfileId != null) {
              shouldAttemptNaturalExpiryBootstrap = true;
            } else {
              // Pre-expiry rejection: fail closed without silent default fallback
              activeProfileId = null;
              selectedProfileId = null;
              error =
                  'Saved Profile access could not be restored. Select a Profile to authorize access.';
            }
          }
        }
      }

      // Catalog refresh occurs next (must not block already-restored valid session if it fails)
      profiles = await chat.client.listProfiles();
      requests = await chat.client.pendingBrowserRequests();
      try {
        deletedProfiles = await chat.client.listDeletedProfiles();
      } catch (e) {
        debugPrint('DesktopProfileController.refresh deletedProfiles failed: ');
      }

      if (explicitlyLocked) {
        if (persistedProfileId != null && profiles.any((p) => p['id'] == persistedProfileId)) {
          selectedProfileId = persistedProfileId;
        }
        return;
      }

      if (shouldAttemptNaturalExpiryBootstrap && persistedProfileId != null) {
        // Bounded one-shot Host Admin re-authorization for remembered profile
        final eligible = profiles.firstWhere(
          (p) =>
              p['id'] == persistedProfileId &&
              p['status'] == 'active' &&
              p['pin_protected'] != true,
          orElse: () => <String, dynamic>{},
        );
        if (eligible.isNotEmpty) {
          await chat.selectProfile(persistedProfileId);
          final reauthorizedId = chat.authenticatedProfileId;
          if (reauthorizedId != null) {
            activeProfileId = reauthorizedId;
            selectedProfileId = reauthorizedId;
            await clientSettings?.writeSelectedProfileId(reauthorizedId);
            await clientSettings?.writeSelectedProfileSessionExpiry(chat.authenticatedSessionExpiry);
            await clientSettings?.writeProfileExplicitlyLocked(false);
          } else {
            activeProfileId = null;
            selectedProfileId = persistedProfileId;
            error = 'Profile unavailable or locked. Select a Profile to authorize access.';
          }
        } else {
          activeProfileId = null;
          selectedProfileId = persistedProfileId;
          error = 'Profile unavailable or locked. Select a Profile to authorize access.';
        }
        return;
      }

      if (savedToken == null && activeProfileId == null) {
        if (initializeDefault) {
          if (persistedProfileId != null && (isNaturalExpiry || _allowDefaultBootstrap)) {
            // Case 4A: Remembered Profile
            final eligible = profiles.firstWhere(
              (p) =>
                  p['id'] == persistedProfileId &&
                  p['status'] == 'active' &&
                  p['pin_protected'] != true,
              orElse: () => <String, dynamic>{},
            );
            if (eligible.isNotEmpty) {
              _allowDefaultBootstrap = false;
              await chat.selectProfile(persistedProfileId);
              final reauthorizedId = chat.authenticatedProfileId;
              if (reauthorizedId != null) {
                activeProfileId = reauthorizedId;
                selectedProfileId = reauthorizedId;
                await clientSettings?.writeSelectedProfileId(reauthorizedId);
                await clientSettings?.writeSelectedProfileSessionExpiry(chat.authenticatedSessionExpiry);
                await clientSettings?.writeProfileExplicitlyLocked(false);
              } else {
                activeProfileId = null;
                selectedProfileId = persistedProfileId;
                error = 'Profile unavailable or locked. Select a Profile to authorize access.';
              }
            } else {
              activeProfileId = null;
              selectedProfileId = persistedProfileId;
              error = 'Profile unavailable or locked. Select a Profile to authorize access.';
            }
          } else if (persistedProfileId == null) {
            // Case 4B: Genuine first launch on installation
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
            if (_allowDefaultBootstrap &&
                activeProfileId == null &&
                canUseSelected &&
                profiles.any((p) => p['id'] == selectedProfileId && p['is_default'] == true)) {
              _allowDefaultBootstrap = false;
              await chat.selectProfile(selectedProfileId!);
              final authedId = chat.authenticatedProfileId;
              if (authedId != null) {
                activeProfileId = authedId;
                await clientSettings?.writeSelectedProfileId(authedId);
                await clientSettings?.writeSelectedProfileSessionExpiry(chat.authenticatedSessionExpiry);
                await clientSettings?.writeProfileExplicitlyLocked(false);
              }
            }
          }
        } else {
          // initializeDefault == false
          if (persistedProfileId != null && profiles.any((p) => p['id'] == persistedProfileId)) {
            selectedProfileId = persistedProfileId;
          } else if (_allowDefaultBootstrap &&
              activeProfileId == null &&
              !profiles.any((p) => p['id'] == selectedProfileId)) {
            final eligible = profiles.where((p) =>
                p['is_default'] == true &&
                p['status'] == 'active' &&
                p['pin_protected'] != true);
            selectedProfileId =
                eligible.isEmpty ? null : eligible.first['id'] as String;
          }
        }
      }
    } catch (e) {
      debugPrint('DesktopProfileController.refresh failed: $e');
      error =
          'Local Profile authority is unavailable. Check the trusted Windows host runtime.';
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Switches active Profile to [profileId] using acquire-before-teardown semantics.
  Future<bool> switchToProfile(String profileId) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await chat.selectProfile(profileId);
      final newId = chat.authenticatedProfileId;
      if (newId != null) {
        activeProfileId = newId;
        selectedProfileId = newId;
        await clientSettings?.writeSelectedProfileId(newId);
        await clientSettings?.writeSelectedProfileSessionExpiry(chat.authenticatedSessionExpiry);
        await clientSettings?.writeProfileExplicitlyLocked(false);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('DesktopProfileController.switchToProfile failed: $e');
      error =
          'Could not switch Profile. Protected Profiles require an authorized unlock challenge.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> useSelected() async {
    if (busy || !canUseSelected || selectedProfileId == null) return;
    await switchToProfile(selectedProfileId!);
  }

  Future<ProfileMetadata?> createProfile({
    required String name,
    bool switchImmediately = true,
  }) async {
    if (busy) return null;
    busy = true;
    error = null;
    _notify();
    try {
      final created = await chat.client.createProfile(ProfileCreateRequest(name: name));
      profiles = await chat.client.listProfiles();
      if (switchImmediately) {
        busy = false;
        await switchToProfile(created.id);
      }
      return created;
    } catch (e) {
      debugPrint('DesktopProfileController.createProfile failed: $e');
      if (e is CompanionApiException && e.statusCode == 409) {
        error = 'A Profile with this name already exists.';
      } else if (e is CompanionApiException && e.statusCode == 422) {
        error = e.message;
      } else {
        error = 'Failed to create Profile. Ensure the local runtime is reachable.';
      }
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<ProfileMetadata?> renameProfile({
    required String profileId,
    required String newName,
  }) async {
    if (busy) return null;
    busy = true;
    error = null;
    _notify();
    try {
      final updated = await chat.client.renameProfile(
        profileId,
        ProfileUpdateRequest(name: newName),
      );
      profiles = await chat.client.listProfiles();
      if (activeProfileId == profileId) {
        chat.updateAuthenticatedProfileName(updated.name);
      }
      return updated;
    } catch (e) {
      debugPrint('DesktopProfileController.renameProfile failed: $e');
      if (e is CompanionApiException && e.statusCode == 409) {
        error = 'A Profile with this name already exists.';
      } else if (e is CompanionApiException && e.statusCode == 422) {
        error = e.message;
      } else {
        error = 'Failed to rename Profile. Ensure the local runtime is reachable.';
      }
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> lockActiveProfile() async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await clientSettings?.writeProfileExplicitlyLocked(true);
      if (await chat.client.sessionStore.readToken() != null) {
        try {
          await chat.client.revokeProfileSession();
        } catch (_) {}
      }
      await chat.invalidateProfileSession(clearStoredToken: true);
      activeProfileId = null;
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
      try {
        deletedProfiles = await chat.client.listDeletedProfiles();
      } catch (e) {
        debugPrint('DesktopProfileController.refresh deletedProfiles failed: ');
      }
    } catch (_) {
      error =
          'Approval failed or request expired. Refresh requests and review again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<ProfileMetadata?> deleteProfile(String profileId) async {
    if (busy) return null;
    busy = true;
    error = null;
    _notify();
    try {
      final wasActive = activeProfileId == profileId;
      final deleted = await chat.client.deleteProfile(profileId);
      profiles = await chat.client.listProfiles();
      try {
        deletedProfiles = await chat.client.listDeletedProfiles();
      } catch (_) {}

      if (wasActive) {
        activeProfileId = null;
        await chat.invalidateProfileSession(clearStoredToken: true);
        await clientSettings?.writeSelectedProfileId(null);
        await clientSettings?.writeSelectedProfileSessionExpiry(null);

        final defaultProfile = profiles.cast<Map<String, dynamic>?>().firstWhere(
              (p) =>
                  p?['is_default'] == true &&
                  p?['status'] == 'active' &&
                  p?['pin_protected'] != true,
              orElse: () => null,
            );
        if (defaultProfile != null) {
          busy = false;
          await switchToProfile(defaultProfile['id'] as String);
        } else {
          selectedProfileId = profiles.isNotEmpty ? profiles.first['id'] as String : null;
        }
      } else if (selectedProfileId == profileId) {
        selectedProfileId = profiles.isNotEmpty ? profiles.first['id'] as String : null;
      }
      return deleted;
    } catch (e) {
      debugPrint('DesktopProfileController.deleteProfile failed: ');
      if (e is CompanionApiException && e.statusCode == 400) {
        error = e.message;
      } else if (e is CompanionApiException && e.statusCode == 404) {
        error = 'Profile not found.';
      } else {
        error = 'Failed to delete Profile. Ensure the local runtime is reachable.';
      }
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<ProfileMetadata?> restoreProfile(String profileId) async {
    if (busy) return null;
    busy = true;
    error = null;
    _notify();
    try {
      final restored = await chat.client.restoreProfile(profileId);
      profiles = await chat.client.listProfiles();
      try {
        deletedProfiles = await chat.client.listDeletedProfiles();
      } catch (_) {}
      selectedProfileId = restored.id;
      return restored;
    } catch (e) {
      debugPrint('DesktopProfileController.restoreProfile failed: ');
      if (e is CompanionApiException && e.statusCode == 404) {
        error = 'Profile not found or recovery window expired.';
      } else if (e is CompanionApiException && e.statusCode == 409) {
        error = 'A Profile with this name already exists. Rename or remove the conflicting Profile.';
      } else {
        error = 'Failed to restore Profile.';
      }
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> purgeProfileImmediately(String profileId) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await chat.client.purgeProfile(profileId);
      profiles = await chat.client.listProfiles();
      try {
        deletedProfiles = await chat.client.listDeletedProfiles();
      } catch (_) {}
      if (selectedProfileId == profileId) {
        selectedProfileId = profiles.isNotEmpty ? profiles.first['id'] as String : null;
      }
      return true;
    } catch (e) {
      debugPrint('DesktopProfileController.purgeProfileImmediately failed: ');
      if (e is CompanionApiException && e.statusCode == 404) {
        error = 'Profile not found.';
      } else {
        error = 'Failed to permanently purge Profile.';
      }
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  static String formatRemainingRecovery(dynamic purgeAfterVal) {
    if (purgeAfterVal == null) return '30 days remaining';
    try {
      final purgeAfter = DateTime.parse(purgeAfterVal.toString()).toUtc();
      final remaining = purgeAfter.difference(DateTime.now().toUtc());
      if (remaining.isNegative) return 'Expiring soon';
      final days = (remaining.inHours / 24).ceil();
      if (days >= 1) return '$days days remaining';
      final hours = remaining.inHours;
      if (hours >= 1) return '$hours hours remaining';
      return '< 1 hour remaining';
    } catch (_) {
      return '30 days remaining';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    chat.removeListener(_onChatChanged);
    super.dispose();
  }
}
