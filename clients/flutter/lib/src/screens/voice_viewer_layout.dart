import 'package:flutter/material.dart';

class VoiceViewerLayout extends StatelessWidget {
  const VoiceViewerLayout({
    super.key,
    required this.stage,
    required this.diagnostics,
    required this.participants,
    this.participantsOverlay,
    this.audioControls,
    this.streamRail,
    this.bottomActions,
  });

  final Widget stage;
  final Widget diagnostics;
  final Widget? audioControls;
  final Widget? streamRail;
  final Widget? bottomActions;
  final Widget participants;
  final Widget? participantsOverlay;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final short =
          constraints.maxHeight < 360 ||
          (MediaQuery.textScalerOf(context).scale(12) > 16 &&
              constraints.maxHeight < 600);
      final details = <Widget>[
        diagnostics,
        ?audioControls,
        ?streamRail,
        ?bottomActions,
        if (participantsOverlay == null) participants,
      ];
      final content = short
          ? SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: (constraints.maxHeight * .5).clamp(80.0, 240.0),
                    child: stage,
                  ),
                  ...details,
                ],
              ),
            )
          : Column(
              children: [
                Expanded(child: stage),
                ...details,
              ],
            );
      if (participantsOverlay == null) return content;
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(top: 60, right: 12, child: participantsOverlay!),
        ],
      );
    },
  );
}
