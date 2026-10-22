import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import 'controller.dart';
import 'model.dart';

class AdminTelemetryPanel extends StatefulWidget {
  const AdminTelemetryPanel({super.key, required this.api});
  final ApiClient api;
  @override
  State<AdminTelemetryPanel> createState() => _AdminTelemetryPanelState();
}

class _AdminTelemetryPanelState extends State<AdminTelemetryPanel> {
  late TelemetrySettingsController state;
  final endpoint = TextEditingController();
  bool consent = false;
  void _bind() {
    final ticket = widget.api.transport.session.scope.capture();
    final server = widget.api.transport.session.serverRevision;
    state = TelemetrySettingsController(
      widget.api.readTelemetrySettings,
      widget.api.updateTelemetrySettings,
      isCurrent: () =>
          ticket.isActive &&
          server == widget.api.transport.session.serverRevision,
    )..addListener(_changed);
    unawaited(state.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant AdminTelemetryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api) || !state.active) {
      state.dispose();
      consent = false;
      endpoint.clear();
      _bind();
    }
  }

  Future<void> _update(String mode) async {
    await state.update(mode, endpoint: endpoint.text, confirmed: consent);
    if (mounted && state.active && state.error == null)
      setState(() => consent = false);
  }

  @override
  void dispose() {
    state.dispose();
    endpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = state.active ? state.value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        const Text(
          'Диагностика установки',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text(
          'По умолчанию диагностика остаётся на вашем сервере. Подключение центра добровольное; чат и голос работают независимо от его доступности.',
        ),
        if (value != null) ...[
          const SizedBox(height: 16),
          Text(
            'ID установки: ${value.installationId.isEmpty ? 'Недоступен' : value.installationId}',
          ),
          Text(
            'Режим: ${value.mode == 'central' ? 'Метрики и очищенные traces' : 'Только локально'}',
          ),
          Text(
            'Регистрация: ${value.registered ? 'Подключена' : 'Не подключена'}',
          ),
          Semantics(
            liveRegion: true,
            child: Text('Доставка: ${telemetryStateLabels[value.state]}'),
          ),
          Text(
            'Последнее подтверждение приёма: ${value.lastAcceptedAt ?? 'Ещё не получено'}',
          ),
          const Text(
            'Подтверждение приёма не гарантирует длительное хранение. Отсутствие данных не означает, что сервер выключен.',
          ),
          const SizedBox(height: 12),
          if (value.mode == 'central')
            OutlinedButton(
              onPressed: state.busy ? null : () => _update('local_only'),
              child: const Text('Выключить отправку'),
            )
          else ...[
            TextField(
              controller: endpoint,
              enabled: !state.busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'HTTPS-адрес центра',
                hintText: 'https://telemetry.example.org',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: consent,
              onChanged: state.busy
                  ? null
                  : (v) => setState(() => consent = v ?? false),
              title: const Text(
                'Разрешаю отправлять агрегированные метрики и очищенные traces со стабильными псевдонимами пользователей. Содержимое переписки, вложения, звук и экран не отправляются.',
              ),
            ),
            FilledButton(
              onPressed:
                  !state.busy &&
                      consent &&
                      validTelemetryEndpoint(endpoint.text) &&
                      value.state != 'unavailable'
                  ? () => _update('central')
                  : null,
              child: const Text('Подключить центр'),
            ),
          ],
        ],
        if (state.error != null)
          Semantics(liveRegion: true, child: Text(state.error!)),
        TextButton(
          onPressed: state.busy || !state.active ? null : state.load,
          child: Text(state.busy ? 'Проверяем…' : 'Обновить состояние'),
        ),
      ],
    );
  }
}
