import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../diagnostics/windows_storage_diagnostic_reader.dart';
import '../features/settings/settings_section.dart';

/// Navigation destinations available within the desktop navigation rail.
enum DesktopNavDestination {
  chat(label: 'Chat', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded),
  voice(label: 'Voice', icon: Icons.mic_none_rounded, activeIcon: Icons.mic_rounded, badge: 'M4'),
  schedule(label: 'Schedule', icon: Icons.calendar_today_rounded, activeIcon: Icons.calendar_month_rounded),
  memory(label: 'Memory', icon: Icons.psychology_outlined, activeIcon: Icons.psychology_rounded),
  studio(label: 'Studio', icon: Icons.palette_outlined, activeIcon: Icons.palette_rounded, badge: 'M3'),
  settings(label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded);

  const DesktopNavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String? badge;

  bool get isPlanned => badge != null;
}

/// Controller managing UI preferences, current navigation, and diagnostic state.
class DesktopSettingsController extends ChangeNotifier {
  DesktopSettingsController({
    ThemeMode initialThemeMode = ThemeMode.system,
    AccentPreset initialAccentPreset = AccentPreset.oceanSky,
    bool initialRailCollapsed = false,
    DesktopNavDestination initialDestination = DesktopNavDestination.chat,
    SettingsSectionId initialSettingsSection = SettingsSectionId.appearance,
    bool initialScrollToDiagnostics = false,
    StorageDiagnosticReader? diagnosticReader,
    RuntimeProcessState? initialRuntimeProcessState,
    RuntimeLockfileData? initialRuntimeLockfileData,
  })  : _themeMode = initialThemeMode,
        _accentPreset = initialAccentPreset,
        _isRailCollapsed = initialRailCollapsed,
        _currentDestination = initialDestination,
        _selectedSettingsSection = initialScrollToDiagnostics
            ? SettingsSectionId.storage
            : initialSettingsSection,
        _scrollToDiagnostics = initialScrollToDiagnostics,
        _diagnosticReader = diagnosticReader ?? WindowsStorageDiagnosticReader(),
        _runtimeProcessState = initialRuntimeProcessState,
        _runtimeLockfileData = initialRuntimeLockfileData;

  ThemeMode _themeMode;
  AccentPreset _accentPreset;
  bool _isRailCollapsed;
  DesktopNavDestination _currentDestination;
  SettingsSectionId _selectedSettingsSection;
  bool _scrollToDiagnostics;
  final StorageDiagnosticReader _diagnosticReader;
  RuntimeProcessState? _runtimeProcessState;
  RuntimeLockfileData? _runtimeLockfileData;

  ThemeMode get themeMode => _themeMode;
  AccentPreset get accentPreset => _accentPreset;
  bool get isRailCollapsed => _isRailCollapsed;
  DesktopNavDestination get currentDestination => _currentDestination;
  SettingsSectionId get selectedSettingsSection => _selectedSettingsSection;
  bool get scrollToDiagnostics => _scrollToDiagnostics;
  StorageDiagnosticReader get diagnosticReader => _diagnosticReader;
  RuntimeProcessState? get runtimeProcessState => _runtimeProcessState;
  RuntimeLockfileData? get runtimeLockfileData => _runtimeLockfileData;

  void updateRuntimeState(RuntimeProcessState state, [RuntimeLockfileData? lockfileData]) {
    _runtimeProcessState = state;
    if (state.supervisionMode == SupervisionMode.remoteHost) {
      _runtimeLockfileData = null;
    } else if (lockfileData != null) {
      _runtimeLockfileData = lockfileData;
    }
    notifyListeners();
  }


  void setScrollToDiagnostics(bool scroll) {
    final sectionChanged =
        scroll && _selectedSettingsSection != SettingsSectionId.storage;
    if (sectionChanged) {
      _selectedSettingsSection = SettingsSectionId.storage;
    }
    if (_scrollToDiagnostics != scroll || sectionChanged) {
      _scrollToDiagnostics = scroll;
      notifyListeners();
    }
  }

  /// Selects an active category tab inside [SettingsScreen].
  void setSettingsSection(SettingsSectionId section) {
    if (_selectedSettingsSection != section) {
      _selectedSettingsSection = section;
      notifyListeners();
    }
  }

  /// Switches to [DesktopNavDestination.settings] and focuses [section].
  void openSettingsSection(SettingsSectionId section) {
    final destChanged = _currentDestination != DesktopNavDestination.settings;
    final sectionChanged = _selectedSettingsSection != section;
    if (!destChanged && !sectionChanged) return;
    _currentDestination = DesktopNavDestination.settings;
    _selectedSettingsSection = section;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void setAccentPreset(AccentPreset preset) {
    if (_accentPreset != preset) {
      _accentPreset = preset;
      notifyListeners();
    }
  }

  void toggleRailCollapsed() {
    _isRailCollapsed = !_isRailCollapsed;
    notifyListeners();
  }

  void setRailCollapsed(bool collapsed) {
    if (_isRailCollapsed != collapsed) {
      _isRailCollapsed = collapsed;
      notifyListeners();
    }
  }

  Future<bool> Function(DesktopNavDestination from, DesktopNavDestination to)? navigationGuard;

  Future<bool> requestDestination(DesktopNavDestination destination) async {
    if (_currentDestination == destination) return true;
    if (navigationGuard != null) {
      final allowed = await navigationGuard!(_currentDestination, destination);
      if (!allowed) return false;
    }
    setDestination(destination);
    return true;
  }

  void setDestination(DesktopNavDestination destination) {
    if (_currentDestination != destination) {
      _currentDestination = destination;
      notifyListeners();
    }
  }
}
