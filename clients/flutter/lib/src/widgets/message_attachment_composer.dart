import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../services/system_clipboard_paste.dart';

class MessageAttachmentComposer extends StatefulWidget {
  const MessageAttachmentComposer({
    super.key,
    required this.state,
    required this.attachments,
    required this.onChanged,
    required this.onPending,
    required this.textController,
    required this.focusNode,
    this.channelId,
    this.directMessageId,
    this.filePicker,
    this.clipboardReader,
  }) : assert((channelId == null) != (directMessageId == null));

  final AppState state;
  final List<MessageAttachment> attachments;
  final ValueChanged<List<MessageAttachment>> onChanged;
  final ValueChanged<bool> onPending;
  final TextEditingController textController;
  final FocusNode focusNode;
  final String? channelId;
  final String? directMessageId;
  final Future<List<XFile>> Function()? filePicker;
  final Future<ClipboardPasteContent?> Function()? clipboardReader;

  @override
  State<MessageAttachmentComposer> createState() =>
      MessageAttachmentComposerState();
}

class MessageAttachmentComposerState extends State<MessageAttachmentComposer> {
  bool _pending = false;
  String? _error;
  final List<_AttachmentSource> _failedFiles = [];
  String? _activeName;
  int? _activePercent;
  int _generation = 0;

  String get _scope => widget.channelId == null
      ? 'dm:${widget.directMessageId}'
      : 'text:${widget.channelId}';

  bool _isCurrent(int generation, String scope) =>
      mounted && _generation == generation && _scope == scope;

  Future<void> pickFiles() => _pick();

  @override
  void didUpdateWidget(covariant MessageAttachmentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldScope = oldWidget.channelId == null
        ? 'dm:${oldWidget.directMessageId}'
        : 'text:${oldWidget.channelId}';
    if (oldScope != _scope) {
      _generation++;
      _failedFiles.clear();
      _pending = false;
      _error = null;
      _activeName = null;
      _activePercent = null;
      if (oldWidget.onPending != widget.onPending) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPending(false);
        });
      }
    }
  }

  Future<void> _pick() async {
    if (_pending || widget.state.sending) return;
    final remaining = 10 - widget.attachments.length - _failedFiles.length;
    if (remaining <= 0) {
      setState(
        () => _error = 'К сообщению можно прикрепить не более 10 файлов.',
      );
      return;
    }
    final generation = _generation;
    final scope = _scope;
    List<XFile> files;
    try {
      files =
          await (widget.filePicker?.call() ??
              openFiles(
                acceptedTypeGroups: const [XTypeGroup(label: 'Любые файлы')],
              ));
    } catch (_) {
      if (_isCurrent(generation, scope)) {
        setState(() => _error = 'Не удалось выбрать файлы. Повторите попытку.');
      }
      return;
    }
    if (files.isEmpty || !_isCurrent(generation, scope)) return;
    if (files.length > remaining) {
      setState(
        () => _error = 'К сообщению можно прикрепить не более 10 файлов.',
      );
      return;
    }
    await _uploadBatch(
      files.map(_AttachmentSource.fromXFile).toList(growable: false),
      generation: generation,
      scope: scope,
    );
  }

  Future<void> pasteFromClipboard() async {
    if (widget.state.sending) return;
    final generation = _generation;
    final scope = _scope;
    final originalValue = widget.textController.value;
    ClipboardPasteContent? content;
    var clipboardReadFailed = false;
    try {
      content =
          await (widget.clipboardReader?.call() ?? readSystemClipboardPaste());
    } catch (_) {
      // Fall back to Flutter's text-only clipboard below. This keeps standard
      // text paste working if native image clipboard access is unavailable.
      clipboardReadFailed = true;
    }
    String? fallbackText;
    if (content == null) {
      try {
        fallbackText = (await Clipboard.getData('text/plain'))?.text;
      } catch (_) {
        if (content == null && _isCurrent(generation, scope)) {
          setState(
            () => _error =
                'Не удалось прочитать буфер обмена. Повторите попытку.',
          );
        }
      }
    }
    if (!_isCurrent(generation, scope)) {
      return;
    }
    if (content == null && fallbackText == null) {
      if (clipboardReadFailed) {
        setState(
          () =>
              _error = 'Не удалось прочитать буфер обмена. Повторите попытку.',
        );
      }
      return;
    }
    if (widget.textController.text == originalValue.text &&
        widget.textController.selection == originalValue.selection &&
        widget.textController.value.composing == originalValue.composing) {
      _insertText(content?.text ?? fallbackText ?? '', originalValue);
    }
    if (content?.imageError case final imageError?) {
      setState(() => _error = imageError);
    }
    final image = content?.image;
    if (image != null) {
      if (_pending) {
        setState(() => _error = 'Дождитесь завершения текущей загрузки.');
      } else {
        await addClipboardImage(
          image.bytes,
          fileName: image.fileName,
          expectedGeneration: generation,
          expectedScope: scope,
        );
      }
    }
    widget.focusNode.requestFocus();
  }

  void _insertText(String text, TextEditingValue value) {
    if (text.isEmpty) return;
    final currentSelection = value.selection;
    final start = currentSelection.isValid
        ? currentSelection.start.clamp(0, value.text.length)
        : value.text.length;
    final end = currentSelection.isValid
        ? currentSelection.end.clamp(start, value.text.length)
        : value.text.length;
    final updated = value.text.replaceRange(start, end, text);
    widget.textController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  Future<void> addClipboardImage(
    Uint8List bytes, {
    required String fileName,
    int? expectedGeneration,
    String? expectedScope,
  }) async {
    if (_pending || widget.state.sending) return;
    final generation = expectedGeneration ?? _generation;
    final scope = expectedScope ?? _scope;
    if (!_isCurrent(generation, scope)) return;
    final remaining = 10 - widget.attachments.length - _failedFiles.length;
    if (remaining <= 0) {
      setState(
        () => _error = 'К сообщению можно прикрепить не более 10 файлов.',
      );
      return;
    }
    await _uploadBatch(
      [_AttachmentSource.fromBytes(bytes, name: fileName)],
      generation: generation,
      scope: scope,
    );
  }

  Future<void> _retry(_AttachmentSource file) async {
    if (_pending || widget.state.sending || !_failedFiles.contains(file)) {
      return;
    }
    setState(() => _failedFiles.remove(file));
    await _uploadBatch([file], generation: _generation, scope: _scope);
  }

  Future<void> _uploadBatch(
    List<_AttachmentSource> files, {
    required int generation,
    required String scope,
  }) async {
    if (!_isCurrent(generation, scope) || _pending) return;
    final channelId = widget.channelId;
    final directMessageId = widget.directMessageId;
    setState(() {
      _pending = true;
      _error = null;
    });
    widget.onPending(true);
    final selected = [...widget.attachments];
    try {
      for (final file in files) {
        if (!_isCurrent(generation, scope)) return;
        setState(() {
          _activeName = file.name;
          _activePercent = 0;
        });
        try {
          final size = await file.length();
          if (!_isCurrent(generation, scope)) return;
          if (size > 25000000) {
            throw const FormatException(
              'Файл не соответствует ограничению вложения.',
            );
          }
          final bytes = await file.readAsBytes();
          if (!_isCurrent(generation, scope)) return;
          if (bytes.length > 25000000) {
            throw const FormatException(
              'Файл не соответствует ограничению вложения.',
            );
          }
          final uploaded = await widget.state.uploadAttachment(
            file.name,
            bytes,
            channelId: channelId,
            directMessageId: directMessageId,
            onProgress: (sent, total) {
              if (!_isCurrent(generation, scope) || total <= 0) return;
              final percent = (sent * 100 ~/ total).clamp(0, 100);
              if (percent != _activePercent) {
                setState(() => _activePercent = percent);
              }
            },
          );
          if (!_isCurrent(generation, scope)) return;
          selected.add(uploaded);
          widget.onChanged(List.unmodifiable(selected));
        } on FormatException catch (cause) {
          if (!_isCurrent(generation, scope)) return;
          setState(() {
            _failedFiles.add(file);
            _error = cause.message;
          });
        } catch (cause) {
          if (!_isCurrent(generation, scope)) return;
          setState(() {
            _failedFiles.add(file);
            _error = cause is ApiFailure && cause.status == 507
                ? 'На сервере недостаточно места для ${file.name}. Повторите позже.'
                : 'Не удалось загрузить ${file.name}. Проверьте соединение и попробуйте снова.';
          });
        }
      }
    } finally {
      if (_isCurrent(generation, scope)) {
        setState(() {
          _pending = false;
          _activeName = null;
          _activePercent = null;
        });
        widget.onPending(false);
      }
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1000) return '$bytes Б';
    if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(1)} КБ';
    return '${(bytes / 1000000).toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_pending)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: _activePercent == null ? null : _activePercent! / 100,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _activeName == null
                      ? 'Загружаем…'
                      : _activePercent == 100
                      ? '${_activeName!} · обрабатываем…'
                      : '${_activeName!} · ${_activePercent ?? 0}%',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      if (_error case final error?)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: const TextStyle(color: Color(0xFFFF7777), fontSize: 12),
            ),
          ),
        ),
      if (widget.attachments.isNotEmpty)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final attachment in widget.attachments)
              InputChip(
                avatar: const Icon(Icons.insert_drive_file_outlined, size: 17),
                label: Text(
                  '${attachment.originalName} · ${_sizeLabel(attachment.sizeBytes)}',
                  overflow: TextOverflow.ellipsis,
                ),
                onDeleted: _pending || widget.state.sending
                    ? null
                    : () => widget.onChanged(
                        widget.attachments
                            .where((item) => item.id != attachment.id)
                            .toList(growable: false),
                      ),
              ),
          ],
        ),
      if (_failedFiles.isNotEmpty)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final file in _failedFiles)
              Tooltip(
                message: 'Повторить загрузку ${file.name}',
                child: InputChip(
                  avatar: const Icon(Icons.error_outline, size: 17),
                  label: Text('${file.name} · не загружено'),
                  onPressed: _pending || widget.state.sending
                      ? null
                      : () => _retry(file),
                  onDeleted: _pending || widget.state.sending
                      ? null
                      : () => setState(() => _failedFiles.remove(file)),
                ),
              ),
          ],
        ),
    ],
  );
}

class _AttachmentSource {
  const _AttachmentSource({
    required this.name,
    required this.length,
    required this.readAsBytes,
  });

  factory _AttachmentSource.fromXFile(XFile file) => _AttachmentSource(
    name: file.name,
    length: file.length,
    readAsBytes: file.readAsBytes,
  );

  factory _AttachmentSource.fromBytes(
    Uint8List bytes, {
    required String name,
  }) => _AttachmentSource(
    name: name,
    length: () async => bytes.length,
    readAsBytes: () async => bytes,
  );

  final String name;
  final Future<int> Function() length;
  final Future<Uint8List> Function() readAsBytes;
}
