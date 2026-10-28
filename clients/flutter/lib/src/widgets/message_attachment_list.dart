import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'attachment_revocation/view.dart';

class MessageAttachmentList extends StatefulWidget {
  const MessageAttachmentList({
    super.key,
    required this.state,
    required this.parentPath,
    required this.attachments,
    this.messageId,
  });

  final AppState state;
  final String parentPath;
  final List<MessageAttachment> attachments;
  final String? messageId;

  @override
  State<MessageAttachmentList> createState() => _MessageAttachmentListState();
}

class _MessageAttachmentListState extends State<MessageAttachmentList> {
  final Map<String, Future<Uint8List>> _previews = {};
  final Set<String> _failedPreviews = {};
  final Set<String> _previewFailurePending = {};

  void _markPreviewFailed(String attachmentId) {
    if (!mounted ||
        _failedPreviews.contains(attachmentId) ||
        !_previewFailurePending.add(attachmentId)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewFailurePending.remove(attachmentId);
      if (!mounted || !_failedPreviews.add(attachmentId)) return;
      setState(() {});
    });
  }

  Future<void> _showPreview(MessageAttachment attachment) => showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (_) => RevocableAttachmentView(
      state: widget.state,
      parentPath: widget.parentPath,
      messageId: widget.messageId,
      attachmentId: attachment.id,
      child: _ProtectedImagePreview(
        state: widget.state,
        parentPath: widget.parentPath,
        attachment: attachment,
        onSave: () => _save(attachment),
      ),
    ),
  );

  Future<void> _save(MessageAttachment attachment) async {
    try {
      final bytes = await widget.state.api.messageAttachmentBytes(
        widget.parentPath,
        attachment.id,
      );
      if (Platform.isAndroid) {
        await const MethodChannel('boohtacord/download')
            .invokeMethod<bool>('save', {
              'filename': attachment.originalName,
              'mimeType': _mimeType(attachment.originalName),
              'bytes': bytes,
            });
        return;
      }
      final location = await getSaveLocation(
        suggestedName: attachment.originalName,
      );
      if (location == null) return;
      await File(location.path).writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось скачать вложение.')),
        );
      }
    }
  }

  String _mimeType(String name) => switch (name.split('.').last.toLowerCase()) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };

  String _sizeLabel(int bytes) {
    if (bytes < 1000) return '$bytes Б';
    if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(1)} КБ';
    return '${(bytes / 1000000).toStringAsFixed(1)} МБ';
  }

  bool _isImage(String name) =>
      RegExp(r'\.(png|jpe?g|gif)$', caseSensitive: false).hasMatch(name);

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 440.0;
        final compact = MediaQuery.sizeOf(context).width <= 1023;
        final imageWidth = availableWidth.clamp(0.0, 440.0).toDouble();
        final imageHeight = compact ? 144.0 : 200.0;

        return Padding(
          padding: const EdgeInsets.only(top: GcSpacing.x2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (
                var index = 0;
                index < widget.attachments.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(height: GcSpacing.x2),
                if (_isImage(widget.attachments[index].originalName) &&
                    !_failedPreviews.contains(widget.attachments[index].id))
                  SizedBox(
                    key: ValueKey(
                      'attachment-card-${widget.attachments[index].id}',
                    ),
                    width: imageWidth,
                    height: imageHeight + 38,
                    child: _imageCard(widget.attachments[index], imageHeight),
                  )
                else
                  SizedBox(
                    width: availableWidth.clamp(0.0, 340.0).toDouble(),
                    child: _fileCard(
                      widget.attachments[index],
                      onPreview:
                          _isImage(widget.attachments[index].originalName)
                          ? () => _showPreview(widget.attachments[index])
                          : null,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _imageCard(MessageAttachment attachment, double previewHeight) {
    const borderRadius = BorderRadius.all(Radius.circular(10));
    return Container(
      decoration: BoxDecoration(
        color: GcColors.streamCanvas,
        borderRadius: borderRadius,
        border: Border.all(color: GcColors.borderSubtle),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: previewHeight,
            child: Semantics(
              button: true,
              label: 'Открыть изображение ${attachment.originalName}',
              child: Tooltip(
                message: 'Открыть изображение ${attachment.originalName}',
                child: InkWell(
                  key: ValueKey('attachment-preview-${attachment.id}'),
                  onTap: () => _showPreview(attachment),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                    child: SizedBox.expand(
                      child: FutureBuilder<Uint8List>(
                        future: _previews.putIfAbsent(
                          attachment.id,
                          () => widget.state.api.messageAttachmentBytes(
                            widget.parentPath,
                            attachment.id,
                            preview: true,
                          ),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) {
                                _markPreviewFailed(attachment.id);
                                return const Icon(Icons.broken_image_outlined);
                              },
                            );
                          }
                          if (snapshot.hasError) {
                            _markPreviewFailed(attachment.id);
                            return const Icon(Icons.broken_image_outlined);
                          }
                          return const Center(
                            child: Icon(Icons.image_outlined, size: 24),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: GcSpacing.x3),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            attachment.originalName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GcColors.text,
                              fontSize: GcTypography.caption,
                              height:
                                  GcTypography.captionLine /
                                  GcTypography.caption,
                            ),
                          ),
                        ),
                        const SizedBox(width: GcSpacing.x2),
                        Text(
                          _sizeLabel(attachment.sizeBytes),
                          style: const TextStyle(
                            color: GcColors.muted,
                            fontSize: GcTypography.caption,
                            height:
                                GcTypography.captionLine / GcTypography.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    tooltip: 'Скачать ${attachment.originalName}',
                    onPressed: () => _save(attachment),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: const Icon(Icons.download_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileCard(
    MessageAttachment attachment, {
    VoidCallback? onPreview,
  }) => Container(
    key: ValueKey('attachment-card-${attachment.id}'),
    constraints: const BoxConstraints(maxWidth: 340, minHeight: 62),
    padding: const EdgeInsets.all(GcSpacing.x2),
    decoration: BoxDecoration(
      color: GcColors.raised,
      borderRadius: BorderRadius.circular(GcRadii.md),
      border: Border.all(color: GcColors.borderSubtle),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: GcColors.surface,
            borderRadius: BorderRadius.circular(GcRadii.sm),
            child: onPreview == null
                ? const Center(
                    child: Icon(
                      Icons.insert_drive_file_outlined,
                      color: GcColors.textSecondary,
                    ),
                  )
                : Semantics(
                    button: true,
                    label: 'Открыть изображение ${attachment.originalName}',
                    child: Tooltip(
                      message: 'Открыть изображение ${attachment.originalName}',
                      child: InkWell(
                        key: ValueKey('attachment-preview-${attachment.id}'),
                        borderRadius: BorderRadius.circular(GcRadii.sm),
                        onTap: onPreview,
                        child: const Center(
                          child: Icon(
                            Icons.insert_drive_file_outlined,
                            color: GcColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: GcSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                attachment.originalName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GcColors.text,
                  fontSize: GcTypography.body,
                  fontWeight: GcTypography.semibold,
                  height: GcTypography.bodyLine / GcTypography.body,
                ),
              ),
              const SizedBox(height: GcSpacing.x1),
              Text(
                _sizeLabel(attachment.sizeBytes),
                style: const TextStyle(
                  color: GcColors.muted,
                  fontSize: GcTypography.caption,
                  height: GcTypography.captionLine / GcTypography.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: GcSpacing.x3),
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            tooltip: 'Скачать ${attachment.originalName}',
            onPressed: () => _save(attachment),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: const Icon(Icons.download_outlined, size: 20),
          ),
        ),
      ],
    ),
  );
}

class _ProtectedImagePreview extends StatefulWidget {
  const _ProtectedImagePreview({
    required this.state,
    required this.parentPath,
    required this.attachment,
    required this.onSave,
  });

  final AppState state;
  final String parentPath;
  final MessageAttachment attachment;
  final VoidCallback onSave;

  @override
  State<_ProtectedImagePreview> createState() => _ProtectedImagePreviewState();
}

class _ProtectedImagePreviewState extends State<_ProtectedImagePreview> {
  late Future<Uint8List?> _image;
  Object? _loadError;
  bool _imageDecodeFailed = false;

  @override
  void initState() {
    super.initState();
    _image = _load();
  }

  Future<Uint8List?> _load() async {
    try {
      _loadError = null;
      return await widget.state.api.messageAttachmentBytes(
        widget.parentPath,
        widget.attachment.id,
        preview: true,
      );
    } catch (error) {
      _loadError = error;
      return null;
    }
  }

  void _retry() {
    setState(() {
      _imageDecodeFailed = false;
      _image = _load();
    });
  }

  void _markImageDecodeFailed() {
    if (!mounted || _imageDecodeFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _imageDecodeFailed) return;
      setState(() => _imageDecodeFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    namesRoute: true,
    label: 'Просмотр изображения ${widget.attachment.originalName}',
    child: Dialog.fullscreen(
      key: const ValueKey('protected-image-viewer'),
      backgroundColor: const Color.fromRGBO(3, 5, 9, 0.94),
      child: SafeArea(
        minimum: MediaQuery.viewPaddingOf(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = MediaQuery.sizeOf(context).width <= 1023;
            final headerHeight = compact ? 56.0 : 64.0;
            final controlSize = compact ? 44.0 : 36.0;
            final horizontalPadding = compact ? 12.0 : 24.0;
            return Column(
              children: [
                SizedBox(
                  key: const ValueKey('protected-image-viewer-header'),
                  height: headerHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          key: ValueKey('protected-image-viewer-file-icon'),
                          size: 20,
                          color: GcColors.textSecondary,
                        ),
                        const SizedBox(width: GcSpacing.x3),
                        Expanded(
                          child: Text(
                            widget.attachment.originalName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GcColors.textSecondary,
                              fontSize: 14,
                              height:
                                  GcTypography.titleLine / GcTypography.title,
                            ),
                          ),
                        ),
                        FutureBuilder<Uint8List?>(
                          future: _image,
                          builder: (context, snapshot) =>
                              snapshot.hasData && !_imageDecodeFailed
                              ? TextButton.icon(
                                  key: const ValueKey(
                                    'protected-image-viewer-download',
                                  ),
                                  onPressed: widget.onSave,
                                  style: TextButton.styleFrom(
                                    foregroundColor: GcColors.textSecondary,
                                    minimumSize: Size(0, controlSize),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 8 : 14,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.download_outlined,
                                    size: 20,
                                  ),
                                  label: const Text('Скачать'),
                                )
                              : const SizedBox.shrink(),
                        ),
                        SizedBox(width: compact ? 4 : 8),
                        SizedBox(
                          key: const ValueKey('protected-image-viewer-close'),
                          width: controlSize,
                          height: controlSize,
                          child: IconButton(
                            tooltip: 'Закрыть просмотр изображения',
                            autofocus: true,
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(
                              width: controlSize,
                              height: controlSize,
                            ),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 12 : 48),
                    child: FutureBuilder<Uint8List?>(
                      future: _image,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          if (_imageDecodeFailed) {
                            return _PreviewUnavailable(onRetry: _retry);
                          }
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                semanticLabel: widget.attachment.originalName,
                                errorBuilder: (_, _, _) {
                                  _markImageDecodeFailed();
                                  return _PreviewUnavailable(onRetry: _retry);
                                },
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.done) {
                          final unavailable =
                              _loadError is ApiFailure &&
                              ((_loadError! as ApiFailure).status == 404 ||
                                  (_loadError! as ApiFailure).status == 410);
                          return _PreviewUnavailable(
                            deleted: unavailable,
                            onRetry: unavailable ? null : _retry,
                          );
                        }
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Semantics(
                                container: true,
                                liveRegion: true,
                                label: 'Загружаем изображение…',
                                child: const ExcludeSemantics(
                                  child: Text('Загружаем изображение…'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  key: const ValueKey('protected-image-viewer-footer'),
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Изображение целиком · Масштаб по размеру окна',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GcColors.muted,
                      fontSize: GcTypography.caption,
                      height: GcTypography.bodyLine / GcTypography.body,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({this.deleted = false, this.onRetry});

  final bool deleted;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = deleted
        ? 'Вложение удалено или недоступно.'
        : 'Не удалось загрузить изображение.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 42),
          const SizedBox(height: 10),
          Semantics(
            container: true,
            liveRegion: true,
            label: message,
            child: ExcludeSemantics(
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ],
      ),
    );
  }
}
