import 'package:flutter/material.dart';

/// Categorized settings sections mirrored across Web and Flutter Desktop.
enum SettingsSectionId {
  appearance,
  general,
  notifications,
  profiles,
  runtime,
  storage,
  voice,
  tools,
  health,
  network,
}

/// Truthful availability status for a settings section.
enum SettingsSectionStatus {
  available,
  planned,
}

/// Metadata describing one categorized settings section.
@immutable
class SettingsSectionMeta {
  const SettingsSectionMeta({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.status,
    this.milestoneHint,
    this.plannedSummary,
    this.keywords = const <String>[],
  });

  final SettingsSectionId id;
  final String label;
  final String description;
  final IconData icon;
  final SettingsSectionStatus status;
  final String? milestoneHint;
  final String? plannedSummary;
  final List<String> keywords;
}

/// Ordered catalog of Desktop settings sections (active first, then planned).
const List<SettingsSectionMeta> kSettingsSections = <SettingsSectionMeta>[
  SettingsSectionMeta(
    id: SettingsSectionId.appearance,
    label: 'Appearance',
    description: 'Theme mode & accent palette',
    icon: Icons.palette_outlined,
    status: SettingsSectionStatus.available,
    keywords: <String>['theme', 'dark', 'light', 'system', 'accent', 'color'],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.general,
    label: 'General & Lifecycle',
    description: 'Window bounds, tray & startup',
    icon: Icons.tune_rounded,
    status: SettingsSectionStatus.available,
    keywords: <String>['window', 'tray', 'close', 'exit', 'startup', 'lifecycle'],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.notifications,
    label: 'Notifications & Quiet Hours',
    description: 'Alert sound & DND schedule',
    icon: Icons.notifications_active_outlined,
    status: SettingsSectionStatus.available,
    keywords: <String>['quiet', 'dnd', 'sound', 'chime', 'alarm', 'reminder'],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.profiles,
    label: 'Profiles & Privacy',
    description: 'Profile access & device lock',
    icon: Icons.shield_outlined,
    status: SettingsSectionStatus.available,
    keywords: <String>['profile', 'pin', 'lock', 'privacy', 'access', 'pairing'],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.runtime,
    label: 'AI Runtime & Models',
    description: 'Local host, catalog & pairing',
    icon: Icons.memory_rounded,
    status: SettingsSectionStatus.available,
    keywords: <String>['model', 'llm', 'vram', 'dpapi', 'token', 'url', 'pid', 'server'],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.storage,
    label: 'Storage & Diagnostics',
    description: 'Paths, roots & fail-closed checks',
    icon: Icons.folder_special_outlined,
    status: SettingsSectionStatus.available,
    keywords: <String>['storage', 'diagnostics', 'bootstrap', 'cache', 'logs', 'paths'],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.voice,
    label: 'Voice & Audio',
    description: 'STT/TTS, mic, shortcuts & barge-in',
    icon: Icons.mic_none_rounded,
    status: SettingsSectionStatus.available,
    keywords: <String>['voice', 'mic', 'audio', 'stt', 'tts', 'barge-in', 'whisper', 'shortcut'],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.tools,
    label: 'Tools & Safety',
    description: 'Permissions, D9 policy & kill switch',
    icon: Icons.security_rounded,
    status: SettingsSectionStatus.available,
    keywords: <String>['tools', 'd9', 'safety', 'kill switch', 'web', 'permissions'],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.health,
    label: 'Performance & Gaming',
    description: 'Low-impact mode, game list & capacity',
    icon: Icons.speed_rounded,
    status: SettingsSectionStatus.available,
    keywords: <String>[
      'performance',
      'gaming',
      'low-impact',
      'eco',
      'vram',
      'ram',
      'cooldown',
      'health',
      'resources',
    ],
  ),
  SettingsSectionMeta(
    id: SettingsSectionId.network,
    label: 'Network & Mesh',
    description: 'Trusted LAN & remote runtime',
    icon: Icons.hub_outlined,
    status: SettingsSectionStatus.planned,
    milestoneHint: 'M5+',
    plannedSummary:
        'Trusted Tailscale mesh peer management, satellite mobile enrollment, and encrypted remote runtime discovery will live here.',
    keywords: <String>['network', 'mesh', 'tailscale', 'lan', 'remote', 'mobile'],
  ),
];

/// Returns canonical metadata for a given [SettingsSectionId].
SettingsSectionMeta settingsSectionMetaFor(SettingsSectionId id) {
  return kSettingsSections.firstWhere((meta) => meta.id == id);
}

/// Filters settings sections by [query] across label, description, milestone, and keywords.
List<SettingsSectionMeta> filterSettingsSections(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return kSettingsSections;
  }
  return kSettingsSections.where((section) {
    if (section.label.toLowerCase().contains(normalized)) return true;
    if (section.description.toLowerCase().contains(normalized)) return true;
    if (section.milestoneHint != null &&
        section.milestoneHint!.toLowerCase().contains(normalized)) {
      return true;
    }
    return section.keywords.any((kw) => kw.toLowerCase().contains(normalized));
  }).toList(growable: false);
}
