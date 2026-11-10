import 'package:flutter/material.dart';

import 'controller.dart';
import 'evaluator.dart';
import 'required_page.dart';

class RequiredUpdateGuard extends StatelessWidget {
  const RequiredUpdateGuard({
    super.key,
    required this.updates,
    required this.appBusy,
    required this.child,
  });
  final UpdateController updates;
  final bool appBusy;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: updates,
    builder: (context, _) {
      final policy = updates.policy;
      final required =
          policy != null &&
          requiresUpdate(
            updates.identity.local,
            policy,
            updates.identity.environment,
          );
      return PopScope(
        canPop: !required,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: required,
              child: AbsorbPointer(
                absorbing: required,
                child: ExcludeSemantics(excluding: required, child: child),
              ),
            ),
            if (required)
              Positioned.fill(
                child: RequiredUpdatePage(updates: updates, appBusy: appBusy),
              ),
          ],
        ),
      );
    },
  );
}
