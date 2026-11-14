#include "benchmark.h"
#include <cassert>
#include <limits>

using namespace boohta::deepfilter;
int main() {
  std::int64_t clock = 0;
  int frames = 0;
  auto now = [&] { return clock; };
  auto fast = [&](AudioFrame& frame) { ++frames; clock += 1000; return true; };
  auto result = RunPreflight(fast, now);
  assert(result.ready && result.p95_us == 1000 && result.max_us == 1000);
  assert(result.measured_frames == 32 && frames == 40);
  auto slow = [&](AudioFrame&) { clock += 4000; return true; };
  assert(!RunPreflight(slow, now).ready);
  auto stalled = [&](AudioFrame&) { clock += 11000; return true; };
  assert(!RunPreflight(stalled, now).ready);
  int calls = 0;
  auto spike = [&](AudioFrame&) { clock += ++calls == 20 ? 9000 : 1000; return true; };
  auto spiked = RunPreflight(spike, now);
  assert(!spiked.ready && spiked.p95_us == 1000 && spiked.max_us == 9000);
  auto deadline = [&](AudioFrame&) { clock += 200000; return true; };
  assert(!RunPreflight(deadline, now).ready);
  auto invalid = [&](AudioFrame& f) { f.samples[0] = std::numeric_limits<float>::quiet_NaN(); return true; };
  assert(!RunPreflight(invalid, now).ready);
  auto clipped = [&](AudioFrame& f) { f.samples[0] = 2; return true; };
  assert(!RunPreflight(clipped, now).ready);
  auto failed = [&](AudioFrame&) { return false; };
  assert(!RunPreflight(failed, now).ready);
  auto threw = [&](AudioFrame&) -> bool { throw 1; };
  assert(!RunPreflight(threw, now).ready);
  auto reverse = [&](AudioFrame&) { --clock; return true; };
  assert(!RunPreflight(reverse, now).ready);
  return 0;
}
