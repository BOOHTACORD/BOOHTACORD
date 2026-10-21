import '../native_bindings.dart';

class WorkspaceAudioDeviceDropdown extends StatelessWidget {
  const WorkspaceAudioDeviceDropdown({
    super.key,
    required this.label,
    required this.devices,
    required this.selectedId,
    required this.switching,
    required this.emptyLabel,
    required this.onChanged,
  });

  final String label;
  final List<MediaDevice> devices;
  final String? selectedId;
  final bool switching;
  final String emptyLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = devices.any((device) => device.deviceId == selectedId)
        ? selectedId!
        : devices.isEmpty
        ? '__none__'
        : devices.first.deviceId;
    String deviceLabel(MediaDevice device, int index) {
      if (device.deviceId == 'default') return 'Системный выбор · $label';
      if (device.label.trim().isEmpty) return '$label ${index + 1}';
      return device.label;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: GcColors.text,
            fontSize: GcTypography.body,
            height: GcTypography.bodyLine / GcTypography.body,
            fontWeight: GcTypography.medium,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          key: ValueKey('audio-device-control-$label'),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: GcColors.sidebar,
            border: Border.all(color: GcColors.control),
            borderRadius: BorderRadius.circular(GcRadii.md),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isDense: true,
              isExpanded: true,
              value: selected,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: GcColors.text,
                fontSize: GcTypography.body,
                height: GcTypography.bodyLine / GcTypography.body,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: GcColors.muted,
                size: GcLayout.iconSize,
              ),
              items: [
                if (devices.isEmpty)
                  DropdownMenuItem(
                    value: '__none__',
                    enabled: false,
                    child: Text(emptyLabel),
                  ),
                for (var index = 0; index < devices.length; index++)
                  DropdownMenuItem(
                    value: devices[index].deviceId,
                    child: Tooltip(
                      message: deviceLabel(devices[index], index),
                      child: Text(
                        deviceLabel(devices[index], index),
                        overflow: TextOverflow.ellipsis,
                        semanticsLabel: deviceLabel(devices[index], index),
                      ),
                    ),
                  ),
              ],
              onChanged: devices.isEmpty || switching
                  ? null
                  : (value) {
                      if (value != null) onChanged(value);
                    },
            ),
          ),
        ),
        if (switching) ...[
          const SizedBox(height: 8),
          Semantics(
            key: ValueKey('audio-device-switching-$label'),
            liveRegion: true,
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(switch (label) {
                  'Микрофон' => 'Переключаем микрофон…',
                  'Динамик' => 'Переключаем динамик…',
                  _ => 'Переключаем $label…',
                }, style: const TextStyle(color: GcColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
