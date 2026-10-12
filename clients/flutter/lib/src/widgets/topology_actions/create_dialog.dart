import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app_state.dart';
import '../../core/http/api_failure.dart';
import '../../features/authorization/permissions/model.dart';
import '../../models.dart';

Future<void> showTopologyCreateDialog(
  BuildContext context,
  AppState state, {
  ChannelCategory? category,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TopologyCreateDialog(state: state, category: category),
  );
}

class _TopologyCreateDialog extends StatefulWidget {
  const _TopologyCreateDialog({required this.state, this.category});
  final AppState state;
  final ChannelCategory? category;
  @override
  State<_TopologyCreateDialog> createState() => _TopologyCreateDialogState();
}

class _TopologyCreateDialogState extends State<_TopologyCreateDialog> {
  final name = TextEditingController();
  String requestId = const Uuid().v4();
  bool busy = false;
  String? error;
  String? nameError;
  late String kind;
  late String? categoryId;
  late String? _accountIdWhenOpened;
  bool get categoryAllowed =>
      widget.state.permissions.allows(GuildPermission.categoryCreate);
  bool get textAllowed =>
      widget.state.permissions.allows(GuildPermission.textCreate);
  bool get voiceAllowed =>
      widget.state.permissions.allows(GuildPermission.voiceCreate);
  @override
  void initState() {
    super.initState();
    _accountIdWhenOpened = widget.state.session.user?.accountId;
    widget.state.addListener(_closeWhenAccountChanges);
    kind = widget.category == null && categoryAllowed
        ? 'CATEGORY'
        : textAllowed
        ? 'TEXT'
        : 'VOICE';
    categoryId =
        widget.category?.id ??
        widget.state.topology?.categories.firstOrNull?.id;
  }

  @override
  void dispose() {
    widget.state.removeListener(_closeWhenAccountChanges);
    name.dispose();
    super.dispose();
  }

  void _closeWhenAccountChanges() {
    if (!mounted ||
        widget.state.session.user?.accountId == _accountIdWhenOpened)
      return;
    Navigator.of(context).maybePop();
  }

  void changed() => setState(() {
    requestId = const Uuid().v4();
    error = null;
    nameError = null;
  });
  Future<void> submit() async {
    if (busy) return;
    if (_accountIdWhenOpened == null ||
        widget.state.session.user?.accountId != _accountIdWhenOpened) {
      Navigator.of(context).maybePop();
      return;
    }
    if (name.text.trim().isEmpty || name.text.runes.length > 80) {
      setState(() => nameError = 'Введите имя до 80 символов.');
      return;
    }
    if (kind != 'CATEGORY' && categoryId == null) {
      setState(() => error = 'Сначала создайте раздел.');
      return;
    }
    if (kind != 'CATEGORY' &&
        !(widget.state.topology?.categories.any(
              (item) => item.id == categoryId,
            ) ??
            false)) {
      setState(
        () => error = 'Выбранный раздел уже недоступен. Обновите список и выберите другой раздел.',
      );
      await widget.state.refreshTopology();
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (kind == 'CATEGORY')
        await widget.state.api.createMemberCategory(name.text, requestId);
      else
        await widget.state.api.createMemberChannel(
          categoryId!,
          name.text,
          kind == 'TEXT' ? ChannelKind.text : ChannelKind.voice,
          requestId,
        );
      await widget.state.refreshTopology();
      if (mounted) Navigator.pop(context);
    } catch (cause) {
      if (cause is ApiFailure && cause.status == 403)
        await widget.state.permissions.refresh();
      if (cause is ApiFailure && cause.status == 409)
        await widget.state.refreshTopology();
      if (mounted) setState(() => error = cause.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinds = [
      if (categoryAllowed && widget.category == null) 'CATEGORY',
      if (textAllowed) 'TEXT',
      if (voiceAllowed) 'VOICE',
    ];
    return AlertDialog(
      title: const Text('Создать'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: [
                for (final value in kinds)
                  DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value == 'CATEGORY'
                          ? 'Раздел'
                          : value == 'TEXT'
                          ? 'Текстовый канал'
                          : 'Голосовой канал',
                    ),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      kind = value!;
                      changed();
                    },
            ),
            if (kind != 'CATEGORY')
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Раздел'),
                items: [
                  for (final item
                      in widget.state.topology?.categories ??
                          const <ChannelCategory>[])
                    DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        categoryId = value;
                        changed();
                      },
              ),
            TextField(
              controller: name,
              autofocus: true,
              maxLength: 80,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: 'Имя',
                errorText: nameError,
                errorMaxLines: 12,
              ),
              onChanged: (_) => changed(),
              onSubmitted: (_) => submit(),
            ),
            if (kind != 'CATEGORY' && categoryId == null)
              const Text('Сначала создайте раздел.'),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: busy || kinds.isEmpty ? null : submit,
          child: Text(busy ? 'Создаём…' : 'Создать'),
        ),
      ],
    );
  }
}
