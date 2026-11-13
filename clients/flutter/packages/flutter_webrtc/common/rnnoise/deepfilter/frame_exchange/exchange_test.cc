#include "exchange.h"
#include <cassert>
#include <limits>

using boohta::deepfilter::AudioFrame;
using boohta::deepfilter::ExchangeStatus;
using boohta::deepfilter::FrameExchange;

int main() {
  FrameExchange<2> exchange;
  AudioFrame worker{};
  float input[480], output[480];
  for (auto& sample : input) sample = 0.25f;
  assert(exchange.Capture(input, 1, false, output) == ExchangeStatus::no_frame);
  for (float sample : output) assert(sample == 0.0f);
  assert(exchange.WorkerPop(1, worker));
  for (auto& sample : worker.samples) sample *= 2;
  assert(exchange.WorkerPush(worker));
  assert(exchange.Capture(input, 1, false, output) == ExchangeStatus::ready);
  for (float sample : output) assert(sample == 0.5f);

  assert(exchange.Capture(input, 1, true, output) == ExchangeStatus::no_frame);
  for (float sample : output) assert(sample == 0.0f);
  assert(!exchange.WorkerPop(2, worker));  // Stale generation is discarded.
  worker.generation = 1; worker.sequence = 42; worker.samples.fill(1.0f);
  assert(exchange.WorkerPush(worker));
  assert(exchange.Capture(input, 2, false, output) == ExchangeStatus::no_frame);
  for (float sample : output) assert(sample == 0.0f);
  assert(exchange.WorkerPop(2, worker));
  assert(exchange.WorkerPush(worker));
  assert(exchange.Capture(input, 2, false, output) == ExchangeStatus::ready);
  input[0] = std::numeric_limits<float>::quiet_NaN();
  assert(exchange.Capture(input, 2, false, output) == ExchangeStatus::invalid_audio);
  for (float sample : output) assert(sample == 0.0f);
  input[0] = 1.01f;
  assert(exchange.Capture(input, 2, false, output) == ExchangeStatus::invalid_audio);
  input[0] = 0.25f;
  assert(exchange.Capture(input, 2, false, output) == ExchangeStatus::no_frame);
  assert(exchange.Capture(input, 2, false, output) == ExchangeStatus::overload);
  for (float sample : output) assert(sample == 0.0f);

  FrameExchange<2> in_place;
  assert(in_place.Capture(input, 1, false, input) == ExchangeStatus::no_frame);
  assert(in_place.WorkerPop(1, worker));
  for (float sample : worker.samples) assert(sample == 0.25f);
  assert(in_place.WorkerPush(worker));
  for (auto& sample : input) sample = 0.75f;
  assert(in_place.Capture(input, 1, false, input) == ExchangeStatus::ready);
  for (float sample : input) assert(sample == 0.25f);
}
