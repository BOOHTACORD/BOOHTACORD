import 'package:flutter/material.dart';

import '../../profile/content_mode.dart';

class ContentModePicker extends StatelessWidget {
  const ContentModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ScreenShareContentMode value;
  final ValueChanged<ScreenShareContentMode> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Содержимое экрана',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('screen-content-motion'),
              label: const Text('Движение'),
              selected: value == ScreenShareContentMode.motion,
              onSelected: (_) => onChanged(ScreenShareContentMode.motion),
            ),
            ChoiceChip(
              key: const ValueKey('screen-content-text'),
              label: const Text('Текст'),
              selected: value == ScreenShareContentMode.text,
              onSelected: (_) => onChanged(ScreenShareContentMode.text),
            ),
          ],
        ),
      ],
    ),
  );
}
