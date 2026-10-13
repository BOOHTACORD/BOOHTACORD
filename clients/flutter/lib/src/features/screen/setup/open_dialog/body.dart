import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../../../../services/screen_share_quality.dart';
import '../../profile/content_mode.dart';
import '../../capabilities/preflight.dart';
import '../../capabilities/notice.dart';
import '../selection/result.dart';
import '../select_source/inventory.dart';
import '../select_source/grid.dart';
import '../quality/picker.dart';
import '../quality/mode_picker.dart';
import 'header.dart';
import 'footer.dart';
import 'quality_content.dart';
import 'surface.dart';
import 'source_tabs.dart';

class SetupBody extends StatefulWidget {
  const SetupBody({
    super.key,
    required this.initialQuality,
    required this.allowSourceSelection,
    required this.updating,
    this.capturer,
    this.initialContentMode = ScreenShareContentMode.motion,
  });
  final ScreenShareQuality initialQuality;
  final ScreenShareContentMode initialContentMode;
  final bool allowSourceSelection, updating;
  final rtc.DesktopCapturer? capturer;
  @override
  State<SetupBody> createState() => _SetupState();
}

class _SetupState extends State<SetupBody> {
  late ScreenShareQuality quality;
  late ScreenShareContentMode contentMode;
  bool captureScreenAudio = false;
  late SourceInventory inventory;
  @override
  void initState() {
    super.initState();
    quality = widget.initialQuality;
    contentMode = widget.initialContentMode;
    inventory =
        SourceInventory(
            enabled: widget.allowSourceSelection,
            capturer: widget.capturer,
          )
          ..addListener(_changed)
          ..start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    inventory.removeListener(_changed);
    inventory.dispose();
    super.dispose();
  }

  void close([ScreenShareSetupSelection? selection]) =>
      Navigator.of(context).pop(selection);
  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final compact =
        MediaQuery.sizeOf(context).width < 640 ||
        MediaQuery.sizeOf(context).height < 500 ||
        MediaQuery.textScalerOf(context).scale(16) > 18;
    final dimensions = ScreenShareQuality.sourceDimensionsFromJpeg(
      inventory.selected?.thumbnail,
    );
    final capability = ScreenPreflight.detect(
      platform: platform,
      web: kIsWeb,
      selecting: widget.allowSourceSelection,
      sourceAvailable: inventory.sources.isNotEmpty,
      sourceError: inventory.error != null,
    );
    final canStart =
        capability.captureConfigured &&
        (!widget.allowSourceSelection ||
            (inventory.selected != null &&
                (platform != TargetPlatform.windows || dimensions != null)));
    final picker = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QualityPicker(
          quality: quality,
          onChanged: (value) => setState(() => quality = value),
          advancedInitiallyExpanded: widget.updating,
        ),
        ContentModePicker(
          value: contentMode,
          onChanged: (value) => setState(() => contentMode = value),
        ),
      ],
    );
    return SetupSurface(
      children: [
        SetupHeader(updating: widget.updating, onClose: close),
        if (widget.allowSourceSelection) ...[
          if (compact)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScreenCapabilityNotice(capability: capability),
                    if (capability.captureAudioConfigured && !widget.updating)
                      _ScreenAudioToggle(
                        selected: captureScreenAudio,
                        onChanged: (value) =>
                            setState(() => captureScreenAudio = value),
                      ),
                    SourceTabs(inventory: inventory),
                    SourceGrid(inventory: inventory, shrinkWrap: true),
                    picker,
                  ],
                ),
              ),
            )
          else ...[
            ScreenCapabilityNotice(capability: capability),
            if (capability.captureAudioConfigured && !widget.updating)
              _ScreenAudioToggle(
                selected: captureScreenAudio,
                onChanged: (value) =>
                    setState(() => captureScreenAudio = value),
              ),
            SourceTabs(inventory: inventory),
            Expanded(child: SourceGrid(inventory: inventory)),
            picker,
          ],
        ] else
          Expanded(
            child: SetupQualityContent(
              capability: capability,
              updating: widget.updating,
              picker: picker,
              captureScreenAudio: captureScreenAudio,
              onCaptureScreenAudioChanged: (value) =>
                  setState(() => captureScreenAudio = value),
            ),
          ),
        SetupFooter(
          canStart: canStart,
          updating: widget.updating,
          selecting: widget.allowSourceSelection,
          keyboardConstrained: MediaQuery.of(context).viewInsets.bottom > 0,
          selectedName: inventory.selected?.name,
          onCancel: close,
          onStart: () => close(
            ScreenShareSetupSelection(
              sourceId: inventory.selectedId,
              quality: quality,
              sourceDimensions: dimensions,
              captureScreenAudio: captureScreenAudio,
              contentMode: contentMode,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenAudioToggle extends StatelessWidget {
  const _ScreenAudioToggle({required this.selected, required this.onChanged});

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    key: const ValueKey('capture-screen-audio'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    value: selected,
    onChanged: onChanged,
    title: const Text('Передавать звук экрана'),
    subtitle: const Text(
      'Звук игры или приложения передаётся, если источник и система разрешают захват.',
    ),
  );
}
