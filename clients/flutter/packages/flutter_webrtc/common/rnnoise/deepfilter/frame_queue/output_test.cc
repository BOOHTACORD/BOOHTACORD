#include "output.h"
#include <cassert>
#include <limits>

using boohta::deepfilter::AudioFrame;
using boohta::deepfilter::FrameQueue;
using boohta::deepfilter::FrameStatus;
using boohta::deepfilter::TakeCurrentFrame;

int main() {
  FrameQueue<4> queue;
  AudioFrame input{}, output{};
  input.samples.fill(1.0f);
  input.generation = 1;
  input.sequence = 4;
  assert(queue.TryPush(input));
  input.generation = 2;
  input.sequence = 3;
  assert(queue.TryPush(input));
  input.sequence = 5;
  assert(queue.TryPush(input));
  assert(TakeCurrentFrame(queue, 2, false, true, 3, output) == FrameStatus::ready);
  assert(output.generation == 2 && output.sequence == 5);
  assert(output.samples[0] == 1.0f);
  assert(TakeCurrentFrame(queue, 2, false, true, 5, output) == FrameStatus::no_frame);
  for (float sample : output.samples) assert(sample == 0.0f);
  input.sequence = 6;
  assert(queue.TryPush(input));
  assert(TakeCurrentFrame(queue, 2, true, true, 5, output) == FrameStatus::no_frame);
  for (float sample : output.samples) assert(sample == 0.0f);
  assert(TakeCurrentFrame(queue, 2, false, true, 5, output) == FrameStatus::no_frame);
  input.sequence = 0;
  assert(queue.TryPush(input));
  assert(TakeCurrentFrame(queue, 2, false, false, 0, output) == FrameStatus::ready);
  assert(output.sequence == 0);
  input.sequence = 1;
  input.samples[9] = std::numeric_limits<float>::quiet_NaN();
  assert(queue.TryPush(input));
  assert(TakeCurrentFrame(queue, 2, false, true, 0, output) == FrameStatus::invalid_audio);
  for (float sample : output.samples) assert(sample == 0.0f);
}
