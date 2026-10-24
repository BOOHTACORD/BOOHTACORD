import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../widgets/screen_viewer_action_layer.dart';

class ScreenFullscreenPresentation {
  const ScreenFullscreenPresentation._({
    required this.platform,
    required this.wasWindowFullscreen,
    required this.systemChromeChanged,
  });

  final TargetPlatform platform;
  final bool? wasWindowFullscreen;
  final bool systemChromeChanged;

  static Future<ScreenFullscreenPresentation> enter() async {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows) {
      try {
        final wasFullscreen = await windowManager.isFullScreen();
        if (!wasFullscreen) await windowManager.setFullScreen(true);
        return ScreenFullscreenPresentation._(
          platform: platform,
          wasWindowFullscreen: wasFullscreen,
          systemChromeChanged: true,
        );
      } catch (_) {
        return ScreenFullscreenPresentation._(
          platform: platform,
          wasWindowFullscreen: null,
          systemChromeChanged: false,
        );
      }
    }
    if (platform == TargetPlatform.android) {
      try {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        return ScreenFullscreenPresentation._(
          platform: platform,
          wasWindowFullscreen: null,
          systemChromeChanged: true,
        );
      } catch (_) {
        return ScreenFullscreenPresentation._(
          platform: platform,
          wasWindowFullscreen: null,
          systemChromeChanged: false,
        );
      }
    }
    return ScreenFullscreenPresentation._(
      platform: platform,
      wasWindowFullscreen: null,
      systemChromeChanged: false,
    );
  }

  Future<void> restore() async {
    if (platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows) {
      if (wasWindowFullscreen == false) {
        try {
          await windowManager.setFullScreen(false);
        } catch (_) {}
      }
    } else if (platform == TargetPlatform.android && systemChromeChanged) {
      try {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (_) {}
    }
  }
}

class ScreenFullscreenOverlay extends StatefulWidget {
  const ScreenFullscreenOverlay({
    super.key,
    required this.publisherName,
    required this.video,
    required this.onClose,
    this.onStopWatching,
    this.participantsOverlay,
  });

  final String publisherName;
  final Widget video;
  final VoidCallback onClose;
  final VoidCallback? onStopWatching;
  final Widget? participantsOverlay;

  @override
  State<ScreenFullscreenOverlay> createState() =>
      _ScreenFullscreenOverlayState();
}

class _ScreenFullscreenOverlayState extends State<ScreenFullscreenOverlay>
    with SingleTickerProviderStateMixin {
  double _verticalTravel = 0;
  bool _closing = false;
  bool _dismissing = false;
  late final AnimationController _dismissController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<Offset> _dismissOffset =
      Tween<Offset>(begin: Offset.zero, end: const Offset(0, 0.35)).animate(
        CurvedAnimation(parent: _dismissController, curve: Curves.easeInCubic),
      );

  @override
  void dispose() {
    _dismissController.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    widget.onClose();
  }

  Future<void> _dismissBySwipe() async {
    if (_closing || _dismissing) return;
    _dismissing = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _dismissController.forward();
    }
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black,
    child: Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SlideTransition(
        position: _dismissOffset,
        child: FadeTransition(
          opacity: ReverseAnimation(_dismissController),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart:
                    defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.android
                    ? (_) => _verticalTravel = 0
                    : null,
                onVerticalDragUpdate:
                    defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.android
                    ? (details) => _verticalTravel += details.delta.dy
                    : null,
                onVerticalDragEnd:
                    defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.android
                    ? (_) {
                        if (_verticalTravel > 80) _dismissBySwipe();
                        _verticalTravel = 0;
                      }
                    : null,
                child: ColoredBox(color: Colors.black, child: widget.video),
              ),
              Positioned(
                left: 16,
                right: 76,
                top: 16,
                child: SafeArea(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Полноэкранный просмотр: ${widget.publisherName}',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xCC141922),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x446D7C94)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monitor_outlined, size: 17),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Экран ${widget.publisherName}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.participantsOverlay != null)
                Positioned(
                  top: 68,
                  right: 16,
                  child: SafeArea(child: widget.participantsOverlay!),
                ),
              Positioned.fill(
                child: ScreenViewerActionLayer(
                  actions: [
                    if (widget.onStopWatching != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: SafeArea(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Tooltip(
                              message: 'Остановить просмотр',
                              child: FilledButton.icon(
                                onPressed: () {
                                  if (_closing) return;
                                  _closing = true;
                                  widget.onStopWatching!();
                                },
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: const Text('Остановить просмотр'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 20,
                      top: 16,
                      child: SafeArea(
                        child: IconButton.filledTonal(
                          tooltip: 'Выйти из полноэкранного режима',
                          onPressed: _close,
                          icon: const Icon(Icons.fullscreen_exit_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
