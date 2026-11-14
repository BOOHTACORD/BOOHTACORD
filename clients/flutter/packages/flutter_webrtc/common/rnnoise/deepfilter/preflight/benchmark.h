#ifndef BOOHTA_DEEPFILTER_PREFLIGHT_BENCHMARK_H_
#define BOOHTA_DEEPFILTER_PREFLIGHT_BENCHMARK_H_
#include "../frame_queue/queue.h"
#include <algorithm>
#include <array>
#include <cmath>

namespace boohta::deepfilter {
struct PreflightResult {
  bool ready = false;
  std::int64_t p95_us = 0, max_us = 0;
  int measured_frames = 0;
};
// Worker-only synthetic probe: 10ms frames retain >=70% p95 scheduling margin.
// This is a conservative eligibility filter, not speech or end-to-end QA.
template <typename Process, typename Now>
PreflightResult RunPreflight(Process process, Now now) noexcept {
  PreflightResult result;
  std::array<std::int64_t, 32> times{};
  try {
    const auto started = now();
    for (int index = 0; index < 40; ++index) {
      AudioFrame frame{};
      for (int i = 0; i < 480; ++i)
        frame.samples[i] = static_cast<float>((i + index) % 32 - 16) * 0.001f;
      const auto before = now();
      if (!process(frame)) return result;
      const auto after = now();
      if (before < started || after < before || after - started > 1000000) return result;
      for (float value : frame.samples)
        if (!std::isfinite(value) || std::fabs(value) > 1.0f) return result;
      if (index < 8) continue;
      times[result.measured_frames++] = after - before;
    }
    std::sort(times.begin(), times.end());
    result.p95_us = times[30]; result.max_us = times.back();
    result.ready = result.p95_us <= 3000 && result.max_us <= 8000;
  } catch (...) { result.ready = false; }
  return result;
}
}  // namespace boohta::deepfilter
#endif
