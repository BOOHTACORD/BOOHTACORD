#include "exchange.h"
#include <atomic>
#include <cassert>
#include <chrono>
#include <thread>

int main() {
  using namespace boohta::deepfilter;
  FrameExchange<8> exchange;
  std::atomic<bool> running{false}, done{false};
  std::atomic<unsigned> processed{0};
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
  std::thread worker([&] {
    AudioFrame frame{}; running.store(true);
    while (!done.load()) {
      if (!exchange.WorkerPop(1, frame)) { std::this_thread::yield(); continue; }
      while (!exchange.WorkerPush(frame)) {
        if (done.load()) return;
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::yield();
      }
      processed.fetch_add(1);
    }
  });
  while (!running.load()) std::this_thread::yield();
  float input[480]{}, output[480]{}, last = -1.0f;
  unsigned received = 0;
  for (unsigned i = 0; i < 10000; ++i) {
    for (float& value : input) value = static_cast<float>(i) / 10000.0f;
    const auto status = exchange.Capture(input, 1, false, output);
    assert(status != ExchangeStatus::invalid_audio && status != ExchangeStatus::overload);
    if (status == ExchangeStatus::ready) {
      assert(output[0] >= last && output[0] <= 1.0f); last = output[0]; ++received;
      for (float value : output) assert(value == output[0]);
    } else {
      for (float value : output) assert(value == 0.0f);
    }
    assert(std::chrono::steady_clock::now() < deadline);
    while (processed.load() <= i) {
      assert(std::chrono::steady_clock::now() < deadline);
      std::this_thread::yield();
    }
  }
  done.store(true); worker.join();
  assert(received > 0);
}
