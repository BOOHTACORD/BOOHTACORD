#ifndef BOOHTA_RNNOISE_PREFLIGHT_WARMUP_H_
#define BOOHTA_RNNOISE_PREFLIGHT_WARMUP_H_
#include <mutex>
extern "C" {
#include "../upstream/include/rnnoise.h"
}
namespace boohta {
// Shared across control initialization and probe workers. Never called on capture.
inline void WarmRnnoiseFft(DenoiseState* state) {
  static std::once_flag ready;
  std::call_once(ready, [state] {
    float silence[480]{};
    rnnoise_process_frame(state, silence, silence);
  });
}
}
#endif
