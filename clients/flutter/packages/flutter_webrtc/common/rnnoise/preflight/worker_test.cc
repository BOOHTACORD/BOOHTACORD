#include "worker.h"
#include <cassert>
#include <chrono>
#include <cstdio>
#include <thread>

int main() {
  boohta::RnnoisePreflight probe;
  assert(probe.state() == 0);
  assert(probe.Start());
  assert(!probe.Start());
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (probe.state() == 1 && std::chrono::steady_clock::now() < deadline)
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  assert(probe.state() == 2 || probe.state() == 3);
  // Hardware load may reject eligibility, but terminal metrics must be coherent.
  if (probe.state() == 2) {
    assert(probe.p95_us() >= 0 && probe.p95_us() <= 3000);
    assert(probe.max_us() >= probe.p95_us() && probe.max_us() <= 8000);
  }
  std::printf("rnnoise_preflight_state=%d p95_us=%lld max_us=%lld\n", probe.state(),
      static_cast<long long>(probe.p95_us()), static_cast<long long>(probe.max_us()));
}
