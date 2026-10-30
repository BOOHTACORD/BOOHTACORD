import 'package:flutter/material.dart';

class ScreenRecoveryRetry extends StatelessWidget {
  const ScreenRecoveryRetry({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh),
      label: const Text('Повторить просмотр'),
    ),
  );
}
