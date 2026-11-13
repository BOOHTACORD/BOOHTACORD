#include "resampler.h"
#include <atomic>
#include <cassert>
#include <cstdlib>
#include <new>
static std::atomic<std::size_t> allocations{0};
void* operator new(std::size_t size) {
  allocations.fetch_add(1, std::memory_order_relaxed);
  if (void* memory = std::malloc(size)) return memory;
  throw std::bad_alloc();
}
void operator delete(void* memory) noexcept { std::free(memory); }
void operator delete(void* memory, std::size_t) noexcept { std::free(memory); }
int main() {
  boohta::deepfilter::Resampler16k resampler;
  float input[160]{}, wide[480]{}, output[160]{};
  input[80] = 1000.f;
  void* probe = ::operator new(1);
  assert(allocations.load() > 0); ::operator delete(probe);
  const auto before = allocations.load();
  volatile float check = 0;
  for (int i = 0; i < 100; ++i) {
    resampler.Upsample(input, wide); resampler.Downsample(wide, output);
    check = output[i % 160];
  }
  (void)check;
  assert(allocations.load() == before);
}
