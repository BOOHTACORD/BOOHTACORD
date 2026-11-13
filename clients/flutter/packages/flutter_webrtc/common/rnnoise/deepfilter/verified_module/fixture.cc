#include <windows.h>
#include <cstdlib>
extern "C" __declspec(dllexport) int __cdecl fixture_add(int a, int b) { return a + b; }
extern "C" __declspec(dllexport) int __cdecl research_create(const unsigned char* path, size_t length, void** state) {
  if (!path || !length || length > 32768 || !state ||
      !MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, reinterpret_cast<const char*>(path),
                           static_cast<int>(length), nullptr, 0)) return 1;
  *state = std::malloc(1); return *state ? 0 : 2;
}
extern "C" __declspec(dllexport) int __cdecl research_process(void* state, const float* in, float* out, size_t count) {
  if (!state || !in || !out || count != 480) return 1;
  for (size_t i = 0; i < count; ++i) out[i] = in[i] * 0.5f;
  return 0;
}
extern "C" __declspec(dllexport) int __cdecl research_free(void* state) {
  if (!state) return 1;
  std::free(state); return 0;
}
