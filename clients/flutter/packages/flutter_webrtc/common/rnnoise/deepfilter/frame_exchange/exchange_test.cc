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

  FrameExchange<2> bad_output;
  assert(bad_output.Capture(input, 1, false, output) == ExchangeStatus::no_frame);
  assert(bad_output.WorkerPop(1, worker));
  worker.samples[0] = 1.01f;
  assert(bad_output.WorkerPush(worker));
  assert(bad_output.Capture(input, 1, false, output) == ExchangeStatus::invalid_audio);
  for (float sample : output) assert(sample == 0.0f);

  FrameExchange<4> delayed(2);
  for (int frame = 1; frame <= 3; ++frame) {
    for (auto& sample : input) sample = 0.1f * frame;
    const auto status = delayed.Capture(input, 7, false, output);
    assert(status == (frame < 3 ? ExchangeStatus::buffering : ExchangeStatus::ready));
    for (float sample : output) assert(sample == (frame < 3 ? 0.0f : 0.1f));
    assert(delayed.WorkerPop(7, worker)); assert(delayed.WorkerPush(worker));
  }
  assert(delayed.Capture(input, 8, false, output) == ExchangeStatus::buffering);
  for (float sample : output) assert(sample == 0.0f);
  assert(delayed.WorkerPop(8, worker)); assert(delayed.WorkerPush(worker));
  assert(delayed.Capture(input, 8, false, output) == ExchangeStatus::buffering);
  assert(delayed.WorkerPop(8, worker)); assert(delayed.WorkerPush(worker));
  assert(delayed.Capture(input, 8, false, output) == ExchangeStatus::ready);
  for (float sample : output) assert(sample == 0.3f);
}
