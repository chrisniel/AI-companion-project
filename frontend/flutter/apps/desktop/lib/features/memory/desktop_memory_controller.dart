import 'dart:async';
import 'package:companion_api/companion_api.dart';
import 'package:flutter/foundation.dart';

/// State management controller for the Desktop Memory Control Center (PC-CLIENT-009).
class DesktopMemoryController extends ChangeNotifier {
  DesktopMemoryController({
    required CompanionClient client,
    String? profileId,
    String? activeCharacterInstanceId,
    bool initialExtractionEnabled = true,
  })  : _client = client,
        _profileId = profileId,
        _activeCharacterInstanceId = activeCharacterInstanceId,
        _memoryExtractionEnabled = initialExtractionEnabled;

  final CompanionClient _client;
  String? _profileId;
  String? _activeCharacterInstanceId;

  String? get profileId => _profileId;
  String? get activeCharacterInstanceId => _activeCharacterInstanceId;

  bool _isLoading = false;
  String? _errorMessage;
  bool _memoryExtractionEnabled = true;

  List<MemoryOut> _memories = [];
  List<MemoryOut> _activeConflicts = [];

  String _selectedTier = 'knowledge'; // 'knowledge', 'long_term', 'short_term'
  int _knowledgeCount = 0;
  int _longTermCount = 0;
  int _shortTermCount = 0;

  String _searchQuery = '';
  String _selectedScopeFilter = 'all'; // 'all', 'profile', 'character'
  String _selectedCategoryFilter = 'all'; // 'all', 'fact', 'preference', 'context'
  String _selectedStatusFilter = 'all'; // 'all', 'verified', 'pending', 'conflicts'

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get memoryExtractionEnabled => _memoryExtractionEnabled;

  List<MemoryOut> get memories => List.unmodifiable(_memories);
  List<MemoryOut> get activeConflicts => List.unmodifiable(_activeConflicts);

  String get selectedTier => _selectedTier;
  int get knowledgeCount => _knowledgeCount;
  int get longTermCount => _longTermCount;
  int get shortTermCount => _shortTermCount;

  String get searchQuery => _searchQuery;
  String get selectedScopeFilter => _selectedScopeFilter;
  String get selectedCategoryFilter => _selectedCategoryFilter;
  String get selectedStatusFilter => _selectedStatusFilter;

  void setTier(String tier) {
    if (_selectedTier != tier) {
      _selectedTier = tier;
      if (tier != 'short_term' && _selectedCategoryFilter == 'context') {
        _selectedCategoryFilter = 'all';
      } else if (tier == 'short_term' &&
          (_selectedCategoryFilter == 'fact' || _selectedCategoryFilter == 'preference')) {
        _selectedCategoryFilter = 'all';
      }
      notifyListeners();
      loadMemories();
    }
  }

  void updateProfileScope({
    required String? profileId,
    String? activeCharacterInstanceId,
    bool? memoryExtractionEnabled,
  }) {
    final changed = _profileId != profileId ||
        _activeCharacterInstanceId != activeCharacterInstanceId ||
        (memoryExtractionEnabled != null && _memoryExtractionEnabled != memoryExtractionEnabled);

    _profileId = profileId;
    _activeCharacterInstanceId = activeCharacterInstanceId;
    if (memoryExtractionEnabled != null) {
      _memoryExtractionEnabled = memoryExtractionEnabled;
    }
    if (changed) {
      notifyListeners();
      loadMemories();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
      loadMemories();
    }
  }

  void setScopeFilter(String scope) {
    if (_selectedScopeFilter != scope) {
      _selectedScopeFilter = scope;
      notifyListeners();
      loadMemories();
    }
  }

  void setCategoryFilter(String category) {
    if (_selectedCategoryFilter != category) {
      _selectedCategoryFilter = category;
      notifyListeners();
      loadMemories();
    }
  }

  void setStatusFilter(String status) {
    if (_selectedStatusFilter != status) {
      _selectedStatusFilter = status;
      notifyListeners();
      loadMemories();
    }
  }

  Future<void> loadMemories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch active unresolved conflicts (source_type == "conflict" & user_verified == false)
      try {
        final conflictsResult = await _client.listMemories(
          sourceType: 'conflict',
          userVerified: false,
          limit: 10,
        );
        _activeConflicts = conflictsResult.items;
      } catch (e) {
        _activeConflicts = [];
      }

      // 2. Fetch filtered memory items
      String? scope;
      String? charInstId;
      if (_selectedScopeFilter == 'profile') {
        scope = 'profile';
      } else if (_selectedScopeFilter == 'character') {
        scope = 'character';
        charInstId = _activeCharacterInstanceId;
      }

      String? category;
      if (_selectedCategoryFilter != 'all') {
        category = _selectedCategoryFilter;
      }

      bool? userVerified;
      String? sourceType;
      if (_selectedStatusFilter == 'verified') {
        userVerified = true;
      } else if (_selectedStatusFilter == 'pending') {
        userVerified = false;
      } else if (_selectedStatusFilter == 'conflicts') {
        sourceType = 'conflict';
      }

      final listResult = await _client.listMemories(
        q: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        scope: scope,
        characterInstanceId: charInstId,
        category: category,
        userVerified: userVerified,
        sourceType: sourceType,
        tier: _selectedTier,
        limit: 100,
      );

      _memories = listResult.items;
      _knowledgeCount = listResult.knowledgeCount;
      _longTermCount = listResult.longTermCount;
      _shortTermCount = listResult.shortTermCount;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approves an unverified candidate memory.
  Future<bool> approveMemory(String memoryId) async {
    try {
      await _client.updateMemory(
        memoryId,
        const MemoryUpdate(userVerified: true),
      );
      await loadMemories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Promotes a temporary short-term context memory into durable verified long-term memory.
  Future<bool> promoteMemory(MemoryOut memory) async {
    try {
      await _client.updateMemory(
        memory.id,
        MemoryUpdate(
          expiresAt: null,
          category: memory.category == 'context' ? 'fact' : memory.category,
          sourceType: 'user_explicit',
          userVerified: true,
        ),
      );
      await loadMemories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Updates an existing memory record.
  Future<bool> updateMemory(String memoryId, MemoryUpdate payload) async {
    try {
      await _client.updateMemory(memoryId, payload);
      await loadMemories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Soft-deletes a memory record.
  Future<bool> deleteMemory(String memoryId) async {
    try {
      await _client.deleteMemory(memoryId);
      await loadMemories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Inserts a new memory record manually.
  Future<bool> createMemory(MemoryCreate payload) async {
    try {
      await _client.createMemory(payload);
      await loadMemories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Conflict Resolution: Keep the new statement, mark it verified, delete the conflicting older memory.
  Future<bool> resolveConflictKeepNew({
    required MemoryOut conflictMemory,
    MemoryOut? oldMemory,
  }) async {
    try {
      await _client.updateMemory(
        conflictMemory.id,
        const MemoryUpdate(userVerified: true, sourceType: 'manual'),
      );
      if (oldMemory != null) {
        await _client.deleteMemory(oldMemory.id);
      }
      await loadMemories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Conflict Resolution: Discard the new statement and preserve the older established memory.
  Future<bool> resolveConflictKeepOld({
    required MemoryOut conflictMemory,
  }) async {
    try {
      await _client.deleteMemory(conflictMemory.id);
      await loadMemories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Conflict Resolution: Reconcile both into a single edited fact.
  Future<bool> resolveConflictMerge({
    required MemoryOut conflictMemory,
    MemoryOut? oldMemory,
    required String mergedContent,
  }) async {
    try {
      if (oldMemory != null) {
        await _client.updateMemory(
          oldMemory.id,
          MemoryUpdate(content: mergedContent, userVerified: true, sourceType: 'manual'),
        );
        await _client.deleteMemory(conflictMemory.id);
      } else {
        await _client.updateMemory(
          conflictMemory.id,
          MemoryUpdate(content: mergedContent, userVerified: true, sourceType: 'manual'),
        );
      }
      await loadMemories();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggles per-profile automatic memory extraction.
  Future<bool> toggleProfileExtraction(bool enabled) async {
    final currentProfId = _profileId;
    if (currentProfId == null) return false;

    try {
      final updated = await _client.renameProfile(
        currentProfId,
        ProfileUpdateRequest(memoryExtractionEnabled: enabled),
      );
      _memoryExtractionEnabled = updated.memoryExtractionEnabled;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
