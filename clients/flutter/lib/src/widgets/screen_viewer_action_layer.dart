import 'dart:async';

import 'package:flutter/material.dart';

/// Reveals screen-viewer actions while a desktop pointer is active.
///
/// Touch platforms keep actions visible because they have no hover affordance.
class ScreenViewerActionLayer extends StatefulWidget {
  const ScreenViewerActionLayer({
    super.key,
    required this.actions,
    this.hideDelay = const Duration(milliseconds: 1800),
  });

  final List<Widget> actions;
  final Duration hideDelay;

  @override
  State<ScreenViewerActionLayer> createState() =>
      _ScreenViewerActionLayerState();
}

class _ScreenViewerActionLayerState extends State<ScreenViewerActionLayer> {
  static const _transitionDuration = Duration(milliseconds: 200);

  Timer? _hideTimer;
  var _focused = false;
  var _touchPlatform = false;
  var _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final platform = Theme.of(context).platform;
    final touchPlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (touchPlatform != _touchPlatform) {
      _touchPlatform = touchPlatform;
      _visible = touchPlatform;
    }
  }

  void _reveal() {
    _hideTimer?.cancel();
    if (!_visible && !_touchPlatform) {
      setState(() => _visible = true);
    }
    if (_touchPlatform) return;
    _hideTimer = Timer(widget.hideDelay, _hideIfUnfocused);
  }

  void _hideIfUnfocused() {
    _hideTimer = null;
    if (!mounted || _focused || _touchPlatform || !_visible) return;
    setState(() => _visible = false);
  }

  void _focusChanged(bool focused) {
    _focused = focused;
    if (focused) {
      _reveal();
    } else if (!_touchPlatform) {
      _hideTimer?.cancel();
      _hideTimer = Timer(widget.hideDelay, _hideIfUnfocused);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerHover: (_) => _reveal(),
    child: MouseRegion(
      opaque: false,
      onEnter: (_) => _reveal(),
      onHover: (_) => _reveal(),
      child: Focus(
        onFocusChange: _focusChanged,
        child: SizedBox.expand(
          child: IgnorePointer(
            key: const ValueKey('screen-viewer-action-hit-test'),
            ignoring: !_visible,
            child: ExcludeSemantics(
              excluding: !_visible,
              child: AnimatedOpacity(
                key: const ValueKey('screen-viewer-action-content'),
                opacity: _visible ? 1 : 0,
                duration: _transitionDuration,
                curve: Curves.easeOut,
                child: AnimatedSlide(
                  key: const ValueKey('screen-viewer-action-slide'),
                  offset: _visible ? Offset.zero : const Offset(0, .016),
                  duration: _transitionDuration,
                  curve: Curves.easeOutCubic,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: widget.actions,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
