import 'package:flutter/material.dart';
import 'desktop_profile_controller.dart';
import 'profile_dialogs.dart';

class ProfileAccessCard extends StatelessWidget {
  const ProfileAccessCard({super.key, required this.controller});
  final DesktopProfileController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = controller.activeProfile;
        final isDefault = active?['is_default'] == true;
        final selected = controller.profiles.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p?['id'] == controller.selectedProfileId,
              orElse: () => null,
            );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Profile access',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => showCreateProfileDialog(context, controller),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Create Profile'),
                          ),
                          if (controller.activeProfileId != null) ...[
                            OutlinedButton.icon(
                              onPressed: controller.busy
                                  ? null
                                  : () => showRenameProfileDialog(
                                        context,
                                        controller,
                                        profileId: controller.activeProfileId!,
                                        currentName: controller.activeProfileName ?? '',
                                        isDefault: isDefault,
                                      ),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Rename Profile'),
                            ),
                            if (!isDefault)
                              OutlinedButton.icon(
                                onPressed: controller.busy
                                    ? null
                                    : () => showMoveToRecentlyDeletedDialog(
                                          context,
                                          controller,
                                          profileId: controller.activeProfileId!,
                                          profileName: controller.activeProfileName ?? '',
                                        ),
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                label: const Text('Delete Profile'),
                              ),
                            TextButton.icon(
                              onPressed: controller.busy
                                  ? null
                                  : () => controller.lockActiveProfile(),
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text('Sign out'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select an active Profile. PIN-protected Profiles require an unlock challenge and are unavailable here.',
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: controller.selectedProfileId,
                  isExpanded: true,
                  hint: const Text('Select Profile'),
                  items: controller.profiles
                      .map((p) => DropdownMenuItem<String>(
                            value: p['id'] as String,
                            enabled: p['status'] == 'active' &&
                                p['pin_protected'] != true,
                            child: Text(
                              '${p['name']}${p['is_default'] == true ? " (Personal / Default)" : ""}${p['pin_protected'] == true ? " (Locked)" : ""}',
                            ),
                          ))
                      .toList(),
                  onChanged: controller.busy ? null : controller.select,
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 12, children: [
                  FilledButton(
                    onPressed: controller.busy || !controller.canUseSelected
                        ? null
                        : controller.useSelected,
                    child: const Text('Use Profile'),
                  ),
                  TextButton(
                    onPressed: controller.busy ? null : controller.refresh,
                    child: const Text('Refresh requests'),
                  ),
                  if (selected != null && selected['id'] != controller.activeProfileId) ...[
                    OutlinedButton(
                      onPressed: controller.busy
                          ? null
                          : () => showRenameProfileDialog(
                                context,
                                controller,
                                profileId: selected['id'] as String,
                                currentName: selected['name'] as String,
                                isDefault: selected['is_default'] == true,
                              ),
                      child: const Text('Rename Selected'),
                    ),
                    if (selected['is_default'] != true)
                      OutlinedButton(
                        onPressed: controller.busy
                            ? null
                            : () => showMoveToRecentlyDeletedDialog(
                                  context,
                                  controller,
                                  profileId: selected['id'] as String,
                                  profileName: selected['name'] as String,
                                ),
                        child: const Text('Delete Selected'),
                      ),
                  ],
                ]),
                const SizedBox(height: 12),
                if (controller.activeProfileId != null) ...[
                  Row(
                    children: [
                      Text('Active Profile: ${controller.activeProfileId}'),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Personal / Default',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (controller.deletedProfiles.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Recently Deleted (${controller.deletedProfiles.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Profiles remain recoverable for 30 days before permanent purge.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  for (final dp in controller.deletedProfiles)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dp['name']?.toString() ?? 'Profile',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    DesktopProfileController.formatRemainingRecovery(dp['purge_after']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => controller.restoreProfile(dp['id'] as String),
                            icon: const Icon(Icons.restore_rounded, size: 16),
                            label: const Text('Restore'),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => showPermanentDeleteProfileDialog(
                                      context,
                                      controller,
                                      profileId: dp['id'] as String,
                                      profileName: dp['name'] as String,
                                    ),
                            icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                            label: const Text('Permanently Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                ],
                const Text(
                  'Browser requests — approve only the request and Origin you recognize.',
                ),
                for (final request in controller.requests)
                  ListTile(
                    title: Text('${request['origin']}'),
                    subtitle: Text(
                      '${request['request_id']} • expires ${request['expires_at']}',
                    ),
                    trailing: TextButton(
                      onPressed: controller.busy ||
                              controller.activeProfileId == null ||
                              controller.activeProfileId != controller.selectedProfileId
                          ? null
                          : () => controller.approve(request['request_id'] as String),
                      child: const Text('Approve request'),
                    ),
                  ),
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      controller.error!,
                      semanticsLabel: controller.error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        );
      });
}
