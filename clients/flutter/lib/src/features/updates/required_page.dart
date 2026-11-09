import 'package:flutter/material.dart';

import 'action.dart';
import 'controller.dart';
import 'desktop/coordinator.dart';
import 'desktop/panel.dart';

class RequiredUpdatePage extends StatefulWidget {
  const RequiredUpdatePage({
    super.key,
    required this.updates,
    required this.appBusy,
  });
  final UpdateController updates;
  final bool appBusy;

  @override
  State<RequiredUpdatePage> createState() => _RequiredUpdatePageState();
}

class _RequiredUpdatePageState extends State<RequiredUpdatePage> {
  String? actionError;

  Future<void> openUpdate() async {
    setState(() => actionError = null);
    try {
      await performUpdateAction(
        context,
        widget.updates,
        appBusy: widget.appBusy,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => actionError =
              'Не удалось открыть страницу обновления. Попробуйте ещё раз.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final updates = widget.updates;
    final appBusy = widget.appBusy;
    final desktop = updates.desktop;
    return Material(
      key: const ValueKey('required-update-gate'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Semantics(
                scopesRoute: true,
                explicitChildNodes: true,
                namesRoute: true,
                label: 'Требуется обновление',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Требуется обновление',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Эта версия приложения больше не поддерживается. Обновите BOOHTACORD, чтобы продолжить.',
                    ),
                    if (updates.policy?.target?.summary
                        case final String summary) ...[
                      const SizedBox(height: 12),
                      Text(summary),
                    ],
                    if (updates.error case final String error) ...[
                      const SizedBox(height: 12),
                      Text(error, semanticsLabel: error),
                    ],
                    if (actionError case final String error) ...[
                      const SizedBox(height: 12),
                      Text(error, semanticsLabel: error),
                    ],
                    const SizedBox(height: 20),
                    if (desktop != null &&
                        desktop.phase != DesktopUpdatePhase.idle)
                      DesktopUpdatePanel(updates: updates, appBusy: appBusy)
                    else
                      FilledButton(
                        onPressed: openUpdate,
                        child: const Text('Обновить'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
