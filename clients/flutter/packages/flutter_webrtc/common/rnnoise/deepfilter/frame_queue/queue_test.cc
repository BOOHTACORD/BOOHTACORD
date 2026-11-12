#include "queue.h"
#include <array>
#include <atomic>
#include <cassert>
#include <chrono>
#include <cstdlib>
#include <new>
#include <thread>

using boohta::deepfilter::AudioFrame;
using boohta::deepfilter::FrameQueue;

static std::atomic<std::size_t> allocations{0};
void* operator new(std::size_t size) {
  allocations.fetch_add(1, std::memory_order_relaxed);
  if (void* memory = std::malloc(size)) return memory;
  throw std::bad_alloc();
}
void operator delete(void* memory) noexcept { std::free(memory); }
void operator delete(void* memory, std::size_t) noexcept { std::free(memory); }

int main() {
  FrameQueue<4> queue;
  AudioFrame frame{}, result{};
  const auto before = allocations.load(std::memory_order_relaxed);
  assert(!queue.TryPop(result));
  for (int i = 0; i < 4; ++i) {
    frame.generation = 7;
    frame.sequence = i;
    frame.samples.fill(static_cast<float>(i));
    assert(queue.TryPush(frame));
  }
  assert(!queue.TryPush(frame));
  for (int i = 0; i < 4; ++i) {
    assert(queue.TryPop(result));
    assert(result.generation == 7 && result.sequence == static_cast<unsigned>(i));
    for (auto sample : result.samples) assert(sample == i);
  }
  assert(!queue.TryPop(result));
  assert(allocations.load(std::memory_order_relaxed) == before);

  constexpr unsigned count = 10000;
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
  std::thread producer([&] {
    AudioFrame input{};
    for (unsigned i = 0; i < count; ++i) {
      input.generation = i / 1000;
      input.sequence = i;
      input.samples.fill(static_cast<float>(i));
      while (!queue.TryPush(input)) {
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::yield();
      }
    }
  });
  for (unsigned i = 0; i < count; ++i) {
    while (!queue.TryPop(result)) {
      assert(std::chrono::steady_clock::now() < deadline);
      std::this_thread::yield();
    }
    assert(result.generation == i / 1000 && result.sequence == i);
    for (auto sample : result.samples) assert(sample == static_cast<float>(i));
  }
  producer.join();
  assert(!queue.TryPop(result));
}
