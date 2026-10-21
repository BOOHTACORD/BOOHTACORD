import 'package:flutter/material.dart';

class VoiceViewerLayout extends StatelessWidget {
  const VoiceViewerLayout({
    super.key,
    required this.stage,
    required this.diagnostics,
    required this.participants,
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
        participants,
      ];
      if (short) {
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: (constraints.maxHeight * .5).clamp(80.0, 240.0),
                child: stage,
              ),
              ...details,
            ],
          ),
        );
      }
      return Column(
        children: [
          Expanded(child: stage),
          ...details,
        ],
      );
    },
  );
}
