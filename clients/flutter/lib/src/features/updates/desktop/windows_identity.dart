import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import 'artifact.dart';

Future<void> verifyWindowsPackage(
  String extracted,
  VerifiedInstallArtifact artifact,
) async {
  final entries = await Directory(extracted)
      .list(recursive: true, followLinks: false)
      .where((e) => e is File)
      .toList();
  final specs = entries
      .where((e) => e.path.toLowerCase().endsWith('.nuspec'))
      .toList();
  final executables = entries
      .where(
        (e) => path.basename(e.path).toLowerCase() == 'boohtacord_desktop.exe',
      )
      .toList();
  if (specs.length != 1 || executables.length != 1) {
    throw const ArtifactFailure('package_identity');
  }
  final spec = File(specs.single.path);
  if (await spec.length() > 128 * 1024) {
    throw const ArtifactFailure('package_identity');
  }
  final doc = XmlDocument.parse(await spec.readAsString());
  final metadata = doc.findAllElements('metadata').firstOrNull;
  if (metadata?.getElement('id')?.innerText != artifact.packageId ||
      metadata?.getElement('version')?.innerText != artifact.version) {
    throw const ArtifactFailure('package_identity');
  }
  final executable = File(executables.single.path),
      input = await executable.open();
  try {
    final header = ByteData.sublistView(await input.read(64));
    if (header.lengthInBytes != 64 ||
        header.getUint16(0, Endian.little) != 0x5a4d) {
      throw const ArtifactFailure('package_arch');
    }
    final offset = header.getUint32(60, Endian.little);
    if (offset > await input.length() - 24) {
      throw const ArtifactFailure('package_arch');
    }
    await input.setPosition(offset);
    final pe = ByteData.sublistView(await input.read(24));
    if (pe.getUint32(0, Endian.little) != 0x4550 ||
        pe.getUint16(4, Endian.little) != 0x8664) {
      throw const ArtifactFailure('package_arch');
    }
  } finally {
    await input.close();
  }
  final version = _version(executable.path);
  if (version.$1 != artifact.version || version.$2 != artifact.nativeBuild) {
    throw const ArtifactFailure('package_identity');
  }
}

(String, String) _version(String file) {
  final library = DynamicLibrary.open('version.dll');
  final length = library
      .lookupFunction<
        Uint32 Function(Pointer<Utf16>, Pointer<Uint32>),
        int Function(Pointer<Utf16>, Pointer<Uint32>)
      >('GetFileVersionInfoSizeW');
  final read = library
      .lookupFunction<
        Int32 Function(Pointer<Utf16>, Uint32, Uint32, Pointer<Void>),
        int Function(Pointer<Utf16>, int, int, Pointer<Void>)
      >('GetFileVersionInfoW');
  final query = library
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<Pointer<Void>>,
          Pointer<Uint32>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<Pointer<Void>>,
          Pointer<Uint32>,
        )
      >('VerQueryValueW');
  final name = file.toNativeUtf16(),
      handle = calloc<Uint32>(),
      out = calloc<Pointer<Void>>(),
      outSize = calloc<Uint32>(),
      root = r'\'.toNativeUtf16();
  Pointer<Uint8> buffer = nullptr;
  try {
    final size = length(name, handle);
    if (size < 1 || size > 1024 * 1024) {
      throw const ArtifactFailure('package_identity');
    }
    buffer = calloc<Uint8>(size);
    if (read(name, 0, size, buffer.cast()) == 0 ||
        query(buffer.cast(), root, out, outSize) == 0 ||
        outSize.value < 52) {
      throw const ArtifactFailure('package_identity');
    }
    final data = out.value.cast<Uint32>();
    if (data[0] != 0xfeef04bd) throw const ArtifactFailure('package_identity');
    return (
      '${data[2] >> 16}.${data[2] & 0xffff}.${data[3] >> 16}',
      '${data[3] & 0xffff}',
    );
  } finally {
    calloc.free(name);
    calloc.free(handle);
    calloc.free(out);
    calloc.free(outSize);
    calloc.free(root);
    if (buffer != nullptr) calloc.free(buffer);
  }
}
