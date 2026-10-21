import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/widgets/local_video_presentation.dart';

int active = 0, peak = 0;

class _Renderer extends StatefulWidget {
  const _Renderer();
  @override
  State<_Renderer> createState() => _RendererState();
}

class _RendererState extends State<_Renderer> {
  @override
  void initState() {
    super.initState();
    active++;
    if (active > peak) peak = active;
  }

  @override
  void dispose() {
    active--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('video');
}

void main() {
  testWidgets(
    'local pause releases only video, survives rebuild and resets for next publication',
    (t) async {
      active = peak = 0;
      var audioChanges = 0;
      Widget app(String generation) => MaterialApp(
        home: LocalVideoPresentation(
          generation: generation,
          builder: (_, paused, toggle) => Column(
            children: [
              TextButton(
                onPressed: toggle,
                child: Text(paused ? 'resume' : 'pause'),
              ),
              TextButton(
                onPressed: () => audioChanges++,
                child: const Text('audio'),
              ),
              if (!paused) const _Renderer(),
            ],
          ),
        ),
      );
      await t.pumpWidget(app('one'));
      expect(active, 1);
      await t.tap(find.text('pause'));
      await t.pump();
      expect(active, 0);
      expect(audioChanges, 0);
      await t.pumpWidget(app('one'));
      expect(find.text('resume'), findsOneWidget);
      await t.tap(find.text('resume'));
      await t.pump();
      expect(active, 1);
      expect(peak, 1);
      await t.tap(find.text('pause'));
      await t.pump();
      await t.pumpWidget(app('two'));
      expect(find.text('pause'), findsOneWidget);
      expect(active, 1);
      await t.pumpWidget(const SizedBox());
      expect(active, 0);
      expect(audioChanges, 0);
    },
  );
}
