import 'package:flutter/widgets.dart';

/// Pauses the local video surface only. It owns no tracks or subscriptions.
class LocalVideoPresentation extends StatefulWidget {
  const LocalVideoPresentation({
    super.key,
    required this.generation,
    required this.builder,
  });
  final Object generation;
  final Widget Function(BuildContext, bool, VoidCallback) builder;
  @override
  State<LocalVideoPresentation> createState() => _LocalVideoPresentationState();
}

class _LocalVideoPresentationState extends State<LocalVideoPresentation> {
  bool paused = false;
  @override
  void didUpdateWidget(covariant LocalVideoPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) paused = false;
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, paused, () => setState(() => paused = !paused));
}
