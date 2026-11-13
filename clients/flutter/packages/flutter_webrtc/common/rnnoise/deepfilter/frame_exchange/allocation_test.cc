#include "exchange.h"
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
  using namespace boohta::deepfilter;
  FrameExchange<4> exchange;
  AudioFrame frame{};
  float input[480]{}, output[480]{};
  const auto initial = allocations.load();
  void* probe = ::operator new(1);
  assert(allocations.load() == initial + 1); ::operator delete(probe);
  const auto before = allocations.load();
  for (int i = 0; i < 1000; ++i) {
    const auto result = exchange.Capture(input, 1, false, output);
    assert(result == (i == 0 ? ExchangeStatus::no_frame : ExchangeStatus::ready));
    assert(exchange.WorkerPop(1, frame)); assert(exchange.WorkerPush(frame));
  }
  assert(allocations.load() == before);
}
