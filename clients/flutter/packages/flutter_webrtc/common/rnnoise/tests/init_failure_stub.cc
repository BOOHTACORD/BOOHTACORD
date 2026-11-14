extern "C" {
#include "upstream/include/rnnoise.h"
}
#include <cstdlib>
struct DenoiseState { int initialized; };
static bool fail = false;
static int calls = 0;
void fail_init(bool value) { fail = value; }
int processed_calls() { return calls; }
extern "C" {
int rnnoise_get_size() { return sizeof(DenoiseState); }
int rnnoise_init(DenoiseState* state) {
  if (fail) return -1;
  state->initialized = 1; return 0;
}
void rnnoise_destroy(DenoiseState* state) { std::free(state); }
float rnnoise_process_frame(DenoiseState* state, float* out, const float* in) {
  if (!state->initialized) std::abort();
  ++calls;
  for (int i = 0; i < 480; ++i) out[i] = in[i] * .5f;
  return 0.f;
}
}
