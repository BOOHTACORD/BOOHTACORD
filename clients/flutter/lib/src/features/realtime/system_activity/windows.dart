import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class _LastInput extends Struct {
  @Uint32()
  external int size;
  @Uint32()
  external int tick;
}

typedef _QueryNative = Int32 Function(
  Pointer<Void>,
  Uint32,
  Int32,
  Pointer<Pointer<Uint8>>,
  Pointer<Uint32>,
);
typedef _QueryDart = int Function(
  Pointer<Void>,
  int,
  int,
  Pointer<Pointer<Uint8>>,
  Pointer<Uint32>,
);

/// Reads only aggregate input age and session lock state, never input contents.
class WindowsSystemActivity {
  WindowsSystemActivity()
    : _user = DynamicLibrary.open('user32.dll'),
      _kernel = DynamicLibrary.open('kernel32.dll'),
      _wts = DynamicLibrary.open('wtsapi32.dll');

  final DynamicLibrary _user, _kernel, _wts;

  Duration? readIdle() {
    if (!Platform.isWindows) return null;
    final info = calloc<_LastInput>();
    try {
      info.ref.size = sizeOf<_LastInput>();
      final lastInput = _user
          .lookupFunction<
            Int32 Function(Pointer<_LastInput>),
            int Function(Pointer<_LastInput>)
          >('GetLastInputInfo');
      if (lastInput(info) == 0) return null;
      final ticks = _kernel.lookupFunction<Uint32 Function(), int Function()>(
        'GetTickCount',
      )();
      return Duration(milliseconds: (ticks - info.ref.tick) & 0xffffffff);
    } finally {
      calloc.free(info);
    }
  }

  bool? readLocked() {
    if (!Platform.isWindows) return null;
    final buffer = calloc<Pointer<Uint8>>(), size = calloc<Uint32>();
    try {
      final query = _wts.lookupFunction<_QueryNative, _QueryDart>(
        'WTSQuerySessionInformationW',
      );
      if (query(nullptr, 0xffffffff, 25, buffer, size) == 0 ||
          size.value < 20) {
        return null;
      }
      // WTSINFOEXW, level 1, on the supported 64-bit Windows targets.
      if (buffer.value.cast<Uint32>().value != 1) return null;
      final state = (buffer.value + 16).cast<Int32>().value;
      if (state == 0) return true;
      if (state == 1) return false;
      return null;
    } finally {
      if (buffer.value != nullptr) {
        _wts.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('WTSFreeMemory')(buffer.value.cast());
      }
      calloc.free(buffer);
      calloc.free(size);
    }
  }
}
