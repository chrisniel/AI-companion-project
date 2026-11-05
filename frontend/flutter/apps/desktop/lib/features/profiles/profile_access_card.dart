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
                  if (selected != null && selected['id'] != controller.activeProfileId)
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
