import 'package:flutter/material.dart';

class DirectHistoryViewport extends StatefulWidget {
  const DirectHistoryViewport({
    super.key,
    required this.child,
    required this.scroll,
    required this.available,
    required this.onJump,
  });
  final Widget child;
  final ScrollController scroll;
  final bool Function() available;
  final VoidCallback onJump;
  @override
  State<DirectHistoryViewport> createState() => _DirectHistoryViewportState();
}

class _DirectHistoryViewportState extends State<DirectHistoryViewport> {
  bool _visible = false;
  bool _queued = false;
  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant DirectHistoryViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scroll != widget.scroll) {
      oldWidget.scroll.removeListener(_schedule);
      widget.scroll.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      final visible =
          widget.available() &&
          widget.scroll.hasClients &&
          widget.scroll.position.hasContentDimensions &&
          widget.scroll.position.extentAfter > 24;
      if (visible != _visible) setState(() => _visible = visible);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          _schedule();
          return false;
        },
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(child: widget.child),
              if (_visible &&
                  widget.available() &&
                  constraints.maxHeight >=
                      MediaQuery.textScalerOf(context).scale(14) * 4 + 40)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: FilledButton.icon(
                      key: const ValueKey('dm-jump-latest-action'),
                      onPressed: widget.onJump,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text(
                        'К последним сообщениям',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
