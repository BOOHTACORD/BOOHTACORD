# Issue 687: RNNoise v0.2 x86 dispatch review

The pinned upstream v0.2 source `904a876dce1f9ab8860c0a5000ed151f9f6eef58`
contains scalar, SSE4.1 and AVX2 inference paths. Its `src/x86/x86cpu.c`
checks CPU feature bits for SSE4.1, AVX, FMA and AVX2, but the inspected
selection path does not check OSXSAVE or XCR0 before selecting AVX2. Intel's
[architecture manual, section 14.3](https://cdrdv2-public.intel.com/843827/253665-sdm-vol-1-dec-24.pdf)
requires checking operating-system support and XMM/YMM state before AVX use.
This is a source-level compatibility risk for systems where those states are
not enabled, not a reproduced crash on this Windows host.

The local v0.2 research builds use scalar code only and do not enable upstream
runtime dispatch. Production integration must implement and test safe OS and
CPU capability checks, scalar fallback, SIMD parity and timing on relevant
hardware. No SIMD performance or compatibility acceptance is claimed here.
