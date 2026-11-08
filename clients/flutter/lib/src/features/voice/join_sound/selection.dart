import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<Uint8List?> chooseJoinSoundFile() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(label: 'Аудио', extensions: ['mp3', 'wav', 'ogg']),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 2097152) throw const FormatException('Too large');
  final bytes = BytesBuilder();
  await for (final chunk in file.openRead(0, await file.length())) {
    if (bytes.length + chunk.length > 2097152)
      throw const FormatException('Too large');
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
