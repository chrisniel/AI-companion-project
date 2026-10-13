import 'package:flutter/material.dart';
import 'desktop_profile_controller.dart';

class ProfileAccessCard extends StatelessWidget {
  const ProfileAccessCard({super.key, required this.controller});
  final DesktopProfileController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profile access',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text(
                          'Select an active Profile. PIN-protected Profiles require an unlock challenge and are unavailable here.'),
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
                                      '${p['name']}${p['pin_protected'] == true ? " (Locked)" : ""}')))
                              .toList(),
                          onChanged:
                              controller.busy ? null : controller.select),
                      Wrap(spacing: 12, children: [
                        FilledButton(
                            onPressed:
                                controller.busy || !controller.canUseSelected
                                    ? null
                                    : controller.useSelected,
                            child: const Text('Use Profile')),
                        TextButton(
                            onPressed:
                                controller.busy ? null : controller.refresh,
                            child: const Text('Refresh requests')),
                      ]),
                      if (controller.activeProfileId != null)
                        Text('Active Profile: ${controller.activeProfileId}'),
                      const Text(
                          'Browser requests — approve only the request and Origin you recognize.'),
                      for (final request in controller.requests)
                        ListTile(
                            title: Text('${request['origin']}'),
                            subtitle: Text(
                                '${request['request_id']} • expires ${request['expires_at']}'),
                            trailing: TextButton(
                                onPressed: controller.busy ||
                                        controller.activeProfileId == null ||
                                        controller.activeProfileId !=
                                            controller.selectedProfileId
                                    ? null
                                    : () => controller.approve(
                                        request['request_id'] as String),
                                child: const Text('Approve request'))),
                      if (controller.error != null)
                        Text(controller.error!,
                            semanticsLabel: controller.error),
                    ])),
          ));
}
