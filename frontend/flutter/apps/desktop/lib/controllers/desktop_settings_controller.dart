import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../diagnostics/windows_storage_diagnostic_reader.dart';

/// Navigation destinations available within the desktop navigation rail.
enum DesktopNavDestination {
  chat(label: 'Chat', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded),
  voice(label: 'Voice', icon: Icons.mic_none_rounded, activeIcon: Icons.mic_rounded, badge: 'M4'),
  schedule(label: 'Schedule', icon: Icons.calendar_today_rounded, activeIcon: Icons.calendar_month_rounded, badge: 'M3'),
  memory(label: 'Memory', icon: Icons.psychology_outlined, activeIcon: Icons.psychology_rounded, badge: 'M3'),
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
    bool initialScrollToDiagnostics = false,
    StorageDiagnosticReader? diagnosticReader,
    RuntimeProcessState? initialRuntimeProcessState,
    RuntimeLockfileData? initialRuntimeLockfileData,
  })  : _themeMode = initialThemeMode,
        _accentPreset = initialAccentPreset,
        _isRailCollapsed = initialRailCollapsed,
        _currentDestination = initialDestination,
        _scrollToDiagnostics = initialScrollToDiagnostics,
        _diagnosticReader = diagnosticReader ?? WindowsStorageDiagnosticReader(),
        _runtimeProcessState = initialRuntimeProcessState,
        _runtimeLockfileData = initialRuntimeLockfileData;

  ThemeMode _themeMode;
  AccentPreset _accentPreset;
  bool _isRailCollapsed;
  DesktopNavDestination _currentDestination;
  bool _scrollToDiagnostics;
  final StorageDiagnosticReader _diagnosticReader;
  RuntimeProcessState? _runtimeProcessState;
  RuntimeLockfileData? _runtimeLockfileData;

  ThemeMode get themeMode => _themeMode;
  AccentPreset get accentPreset => _accentPreset;
  bool get isRailCollapsed => _isRailCollapsed;
  DesktopNavDestination get currentDestination => _currentDestination;
  bool get scrollToDiagnostics => _scrollToDiagnostics;
  StorageDiagnosticReader get diagnosticReader => _diagnosticReader;
  RuntimeProcessState? get runtimeProcessState => _runtimeProcessState;
  RuntimeLockfileData? get runtimeLockfileData => _runtimeLockfileData;

  void updateRuntimeState(RuntimeProcessState state, [RuntimeLockfileData? lockfileData]) {
    _runtimeProcessState = state;
    if (lockfileData != null) {
      _runtimeLockfileData = lockfileData;
    }
    notifyListeners();
  }


  void setScrollToDiagnostics(bool scroll) {
    if (_scrollToDiagnostics != scroll) {
      _scrollToDiagnostics = scroll;
      notifyListeners();
    }
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

  void setDestination(DesktopNavDestination destination) {
    if (_currentDestination != destination) {
      _currentDestination = destination;
      notifyListeners();
    }
  }
}
