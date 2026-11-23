import 'package:flutter/material.dart';

class FpsScene extends StatefulWidget {
  const FpsScene({super.key});
  @override
  State<FpsScene> createState() => _FpsSceneState();
}

class _FpsSceneState extends State<FpsScene>
    with SingleTickerProviderStateMixin {
  late final clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: clock,
              builder: (_, _) => CustomPaint(painter: _Pattern(clock.value)),
            ),
          ),
          const Text('Owned FPS source', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );
}

class _Pattern extends CustomPainter {
  _Pattern(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.black, BlendMode.src);
    final pen = Paint()..color = Colors.cyan;
    for (var y = 0.0; y < size.height; y += 48) {
      final x = (phase * size.width + y) % size.width;
      canvas.drawRect(Rect.fromLTWH(x, y, 120, 24), pen);
    }
  }

  @override
  bool shouldRepaint(_Pattern old) => phase != old.phase;
}
