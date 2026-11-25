import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/desktop_settings_controller.dart';
import '../coordinator/desktop_runtime_coordinator.dart';
import '../features/chat/desktop_chat_controller.dart';
import '../features/profiles/desktop_profile_controller.dart';
import '../features/schedule/desktop_schedule_controller.dart';
import '../features/settings/sections/settings_appearance_section.dart';
import '../features/settings/sections/settings_general_section.dart';
import '../features/settings/sections/settings_notifications_section.dart';
import '../features/settings/sections/settings_performance_section.dart';
import '../features/settings/sections/settings_planned_section.dart';
import '../features/settings/sections/settings_profiles_section.dart';
import '../features/settings/sections/settings_runtime_section.dart';
import '../features/settings/sections/settings_storage_section.dart';
import '../features/settings/sections/settings_tools_section.dart';
import '../features/settings/sections/settings_voice_section.dart';
import '../features/settings/settings_section.dart';
import '../features/settings/settings_sidebar.dart';
import '../features/tools/desktop_tool_policy_controller.dart';
import '../features/voice/desktop_voice_controller.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';
import '../platform/desktop_client_settings.dart';
import '../platform/windows_shell_adapter.dart';

/// Responsive two-column Settings workspace aligned with the Web UI
/// categorized sidebar and truthful Planned vs. Available capability tabs.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.coordinator,
    this.chatController,
    this.profileController,
    this.runtimeCoordinator,
    this.clientSettings,
    this.credentialStore,
    this.client,
    this.scheduleController,
    this.toolPolicyController,
    this.voiceController,
    this.shellAdapter,
    this.resourceStatusListenable,
    this.onResourcePolicyChanged,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;
  final DesktopChatController? chatController;
  final DesktopProfileController? profileController;
  final DesktopRuntimeCoordinator? runtimeCoordinator;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;
  final CompanionClient? client;
  final DesktopScheduleController? scheduleController;
  final DesktopToolPolicyController? toolPolicyController;
  final DesktopVoiceController? voiceController;
  final DesktopShellAdapter? shellAdapter;
  final ValueListenable<ResourcePolicyStatusOut?>? resourceStatusListenable;
  final ValueChanged<ResourcePolicyStatusOut>? onResourcePolicyChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const double _wideBreakpoint = 720.0;

  late final TextEditingController _searchController;
  final GlobalKey _runtimeSectionKey = GlobalKey();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _handleClearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selectedSection = widget.controller.selectedSettingsSection;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            CompanionSpacing.xl,
            CompanionSpacing.lg,
            CompanionSpacing.xl,
            CompanionSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Settings',
                style: CompanionTypography.titleLarge
                    .copyWith(color: ext?.textPrimary),
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                'Desktop preferences, runtime configuration, and capability roadmap',
                style: CompanionTypography.bodySmall
                    .copyWith(color: ext?.textSecondary),
              ),
              const SizedBox(height: CompanionSpacing.lg),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= _wideBreakpoint;
                    final contentPane = _buildSectionStack(selectedSection);

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 280,
                            child: SettingsSidebar(
                              selectedSection: selectedSection,
                              searchController: _searchController,
                              searchQuery: _searchQuery,
                              onSearchChanged: _handleSearchChanged,
                              onClearSearch: _handleClearSearch,
                              onSectionSelected:
                                  widget.controller.setSettingsSection,
                            ),
                          ),
                          const SizedBox(width: CompanionSpacing.lg),
                          Expanded(child: contentPane),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsSidebar(
                          compact: true,
                          selectedSection: selectedSection,
                          searchController: _searchController,
                          searchQuery: _searchQuery,
                          onSearchChanged: _handleSearchChanged,
                          onClearSearch: _handleClearSearch,
                          onSectionSelected:
                              widget.controller.setSettingsSection,
                        ),
                        const SizedBox(height: CompanionSpacing.md),
                        Expanded(child: contentPane),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ValueListenable<bool>? _resolveWindowFocusedListenable() {
    try {
      return widget.coordinator?.isWindowFocusedListenable;
    } on UnimplementedError {
      return null;
    }
  }

  Widget _buildSectionStack(SettingsSectionId selectedSection) {
    final activeIndex = kSettingsSections.indexWhere(
      (meta) => meta.id == selectedSection,
    );

    return IndexedStack(
      index: activeIndex < 0 ? 0 : activeIndex,
      sizing: StackFit.expand,
      children: kSettingsSections
          .map((meta) => _buildSectionPane(meta, selectedSection))
          .toList(growable: false),
    );
  }

  Widget _buildSectionPane(
    SettingsSectionMeta meta,
    SettingsSectionId selectedSection,
  ) {
    final Widget sectionBody = switch (meta.id) {
      SettingsSectionId.appearance => SettingsAppearanceSection(
          controller: widget.controller,
        ),
      SettingsSectionId.general => SettingsGeneralSection(
          coordinator: widget.coordinator,
          clientSettings: widget.clientSettings,
          credentialStore: widget.credentialStore,
          client: widget.client,
        ),
      SettingsSectionId.notifications => SettingsNotificationsSection(
          scheduleController: widget.scheduleController,
        ),
      SettingsSectionId.profiles => SettingsProfilesSection(
          profileController: widget.profileController,
        ),
      SettingsSectionId.runtime => SettingsRuntimeSection(
          key: _runtimeSectionKey,
          controller: widget.controller,
          chatController: widget.chatController,
          runtimeCoordinator: widget.runtimeCoordinator,
          clientSettings: widget.clientSettings,
          credentialStore: widget.credentialStore,
          client: widget.client,
          shellAdapter: widget.shellAdapter,
        ),
      SettingsSectionId.storage => SettingsStorageSection(
          diagnosticReader: widget.controller.diagnosticReader,
          controller: widget.controller,
          clientSettings: widget.clientSettings,
          credentialStore: widget.credentialStore,
          client: widget.client,
          shellAdapter: widget.shellAdapter,
        ),
      SettingsSectionId.tools => SettingsToolsSection(
          toolPolicyController: widget.toolPolicyController,
        ),
      SettingsSectionId.voice => SettingsVoiceSection(
          voiceController: widget.voiceController,
        ),
      SettingsSectionId.health => SettingsPerformanceSection(
          client: widget.client,
          clientSettings: widget.clientSettings,
          credentialStore: widget.credentialStore,
          shellAdapter: widget.shellAdapter,
          externalStatus: widget.resourceStatusListenable,
          onResourcePolicyChanged: widget.onResourcePolicyChanged,
          isActiveTab: selectedSection == SettingsSectionId.health,
          windowFocusedListenable: _resolveWindowFocusedListenable(),
        ),
      SettingsSectionId.network =>
        SettingsPlannedSection(section: meta),
    };

    return SingleChildScrollView(
      key: Key('settings_pane_${meta.id.name}'),
      padding: const EdgeInsets.only(bottom: CompanionSpacing.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: sectionBody,
        ),
      ),
    );
  }
}
