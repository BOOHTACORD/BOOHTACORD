import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_playback/pcm.dart';

// Only the OS picker is deterministic. Production UI, HTTP, FFmpeg worker,
// database, session and SoLoud all run normally against the disposable stack.
class QaSoundFiles extends FileSelectorPlatform {
  int calls = 0;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    calls++;
    return XFile.fromData(
      defaultSound('started'),
      name: 'qa-sound.wav',
      mimeType: 'audio/wav',
    );
  }
}
