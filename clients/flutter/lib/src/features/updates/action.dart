import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'controller.dart';
import 'evaluator.dart';
import 'model.dart';

Future<void> performUpdateAction(
  BuildContext context,
  UpdateController updates, {
  required bool appBusy,
}) async {
  try {
    await updates.check();
  } catch (_) {
    return;
  }
  final policy = updates.policy;
  final target = policy?.target;
  if (target == null ||
      evaluateUpdate(
            updates.identity.local,
            policy!,
            updates.identity.environment,
          ) !=
          UpdateResult.updateAvailable)
    return;
  final desktop = updates.desktop;
  if (desktop != null && target.installArtifact != null) {
    await desktop.prepare(target);
    return;
  }
  if (appBusy && context.mounted) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Открыть обновление?'),
        content: const Text(
          'Сейчас активно голосовое подключение или демонстрация. Приложение не завершит их автоматически.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
    if (proceed != true) return;
  }
  final raw = target.actionUrl;
  if (raw == null) return;
  final base = Uri.parse(updates.api.baseUrl());
  final uri = base.resolve(raw);
  final trusted = uri.origin == base.origin || uri.host == 'github.com';
  if (uri.scheme != 'https' ||
      !trusted ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw StateError('Не удалось открыть страницу обновления.');
  }
}
