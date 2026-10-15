import 'package:flutter/material.dart';

import '../../theme.dart';
import 'action.dart';
import 'controller.dart';
import 'desktop/panel.dart';
import 'desktop/coordinator.dart';

class ClientUpdateBanner extends StatelessWidget {
  const ClientUpdateBanner({
    super.key,
    required this.updates,
    required this.appBusy,
  });
  final UpdateController updates;
  final bool appBusy;

  void _details(BuildContext context) {
    final target = updates.policy?.target;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Что нового',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(target?.summary ?? 'Доступна новая версия BOOHTACORD.'),
              if (target?.version != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Версия ${target!.version}',
                  style: const TextStyle(color: GcColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = updates.desktop;
    if (desktop != null && ![DesktopUpdatePhase.idle].contains(desktop.phase)) {
      return DesktopUpdatePanel(updates: updates, appBusy: appBusy);
    }
    if (!updates.visible) return const SizedBox.shrink();
    final summary =
        updates.policy?.target?.summary ?? 'Доступно обновление BOOHTACORD.';
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        liveRegion: true,
        child: Container(
          key: const ValueKey('client-update-banner'),
          width: double.infinity,
          color: const Color(0xff173b63),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 340,
                child: Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () =>
                    performUpdateAction(context, updates, appBusy: appBusy),
                child: Text(
                  updates.policy?.target?.actionKind == 'open_store'
                      ? 'Открыть магазин'
                      : updates.desktop != null &&
                            updates.policy?.target?.installArtifact != null
                      ? 'Обновить'
                      : 'Скачать обновление',
                ),
              ),
              TextButton(
                onPressed: () => _details(context),
                child: const Text(
                  'Что нового',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              TextButton(
                onPressed: updates.later,
                child: const Text(
                  'Позже',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
