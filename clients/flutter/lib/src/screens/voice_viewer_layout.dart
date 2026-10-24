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
      if (participantsOverlay != null) {
        final topActions = <Widget>[?streamRail, participantsOverlay!];
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: stage),
            Positioned(left: 0, top: 56, child: SafeArea(child: diagnostics)),
            Positioned(
              left: 12,
              right: 12,
              top: 56,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (constraints.maxWidth - 24)
                          .clamp(0.0, double.infinity)
                          .toDouble(),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: topActions,
                    ),
                  ),
                ),
              ),
            ),
            if (audioControls != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: SafeArea(child: audioControls!),
              ),
            if (bottomActions != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: SafeArea(child: bottomActions!),
              ),
          ],
        );
      }

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
      return content;
    },
  );
}
