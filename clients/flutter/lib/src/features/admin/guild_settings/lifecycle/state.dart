import 'package:flutter/material.dart';

import '../../../../models.dart';
import '../panel.dart';
import '../controller.dart';
import '../presentation/view.dart';

class AdminGuildSettingsState extends State<AdminGuildSettings> {
  late final state = GuildSettingsController(
    widget.api.readGuildSettings,
    widget.api.updateGuildSettings,
  );
  final name = TextEditingController();
  @override
  void initState() {
    super.initState();
    state.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await state.load();
    if (mounted) name.text = state.name;
  }

  Future<void> _save() async {
    state.name = name.text;
    await state.save(_channels.map((channel) => channel.id).toList());
    if (mounted && state.saved) {
      name.text = state.name;
      await widget.onSaved();
    }
  }

  void _cancel() {
    state.cancel();
    name.text = state.name;
  }

  List<GuildChannel> get _channels => widget.channels
      .where(
        (channel) =>
            channel.kind == ChannelKind.text && !channel.admissionClosed,
      )
      .toList();
  @override
  void dispose() {
    state.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GuildSettingsPresentation(
    state: state,
    name: name,
    channels: _channels,
    onSave: _save,
    onLoad: _load,
    onCancel: _cancel,
    onNameChanged: (value) => state.name = value,
    onWelcomeChanged: (value) => state.welcome = value,
  );
}
