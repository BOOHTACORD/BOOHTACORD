#include "worker.h"
#include <cassert>
#include <limits>

using namespace boohta::deepfilter;

struct FakeEngine {
  int resets = 0, calls = 0;
  bool reset_ok = true, process_ok = true, throws = false, bad_output = false, alters_metadata = false;
  bool Reset() { ++resets; return reset_ok; }
  bool Process(AudioFrame& frame) {
    ++calls;
    if (throws) throw 1;
    for (auto& sample : frame.samples) sample *= 0.5f;
    if (bad_output) frame.samples[0] = std::numeric_limits<float>::quiet_NaN();
    if (alters_metadata) { frame.generation = 999; frame.sequence = 999; }
    return process_ok;
  }
};

int main() {
  FrameExchange<2> exchange;
  FakeEngine engine;
  WorkerStep<FakeEngine, 2> worker(engine);
  float input[480], output[480];
  for (auto& sample : input) sample = 0.5f;
  assert(worker.Run(exchange, 1) == WorkerStatus::idle);
  assert(exchange.Capture(input, 1, false, output) == ExchangeStatus::no_frame);
  engine.alters_metadata = true;
  assert(worker.Run(exchange, 1) == WorkerStatus::processed);
  assert(engine.resets == 1 && engine.calls == 1);
  assert(exchange.Capture(input, 1, false, output) == ExchangeStatus::ready);
  for (float sample : output) assert(sample == 0.25f);

  assert(worker.Run(exchange, 2) == WorkerStatus::idle); // Generation 1 discarded.
  assert(engine.calls == 1);
  assert(exchange.Capture(input, 2, false, output) == ExchangeStatus::no_frame);
  assert(worker.Run(exchange, 2) == WorkerStatus::processed);
  assert(engine.resets == 2 && engine.calls == 2);

  assert(exchange.Capture(input, 3, false, output) == ExchangeStatus::no_frame);
  engine.reset_ok = false;
  assert(worker.Run(exchange, 3) == WorkerStatus::engine_error);
  assert(engine.calls == 2);
  assert(exchange.Capture(input, 4, false, output) == ExchangeStatus::no_frame);
  engine.reset_ok = true; engine.process_ok = false;
  assert(worker.Run(exchange, 4) == WorkerStatus::engine_error);
  assert(exchange.Capture(input, 5, false, output) == ExchangeStatus::no_frame);
  for (float sample : output) assert(sample == 0.0f);

  FrameExchange<2> broken;
  FakeEngine broken_engine;
  WorkerStep<FakeEngine, 2> broken_worker(broken_engine);
  assert(broken.Capture(input, 1, false, output) == ExchangeStatus::no_frame);
  broken_engine.throws = true;
  assert(broken_worker.Run(broken, 1) == WorkerStatus::engine_error);
  assert(broken.Capture(input, 1, false, output) == ExchangeStatus::no_frame);
  broken_engine.throws = false;
  assert(broken_worker.Run(broken, 1) == WorkerStatus::engine_error);
  assert(broken_engine.calls == 1); // A failed generation cannot resume.
  assert(broken.Capture(input, 2, false, output) == ExchangeStatus::no_frame);
  broken_engine.bad_output = true;
  assert(broken_worker.Run(broken, 2) == WorkerStatus::engine_error);
  assert(broken.Capture(input, 3, false, output) == ExchangeStatus::no_frame);
  for (float sample : output) assert(sample == 0.0f);

  FrameExchange<2> congested;
  FakeEngine congested_engine;
  WorkerStep<FakeEngine, 2> congested_worker(congested_engine);
  assert(congested.Capture(input, 1, false, output) == ExchangeStatus::no_frame);
  AudioFrame filler{};
  assert(congested.WorkerPush(filler)); assert(congested.WorkerPush(filler));
  assert(congested_worker.Run(congested, 1) == WorkerStatus::output_overload);
  assert(congested_worker.Run(congested, 1) == WorkerStatus::engine_error);
}
