#include "processor.h"
#include <algorithm>
#include <cassert>
#include <cmath>
int main() {
  boohta::MicrophoneControls p;
  p.Initialize(48000, 1);
  float pcm[480];
  auto block = [&](float level) { std::fill_n(pcm, 480, level); p.Process(pcm, 480, 480); };
  p.Configure(-50, 100, false, false, true);
  block(100); assert(std::fabs(pcm[479] - 100) < .01);
  p.Configure(-50, 200, false, false, true);
  block(1000); block(1000); assert(std::fabs(pcm[479] - 2000) < .01);
  block(25000); assert(p.clipping()); assert(pcm[479] <= 32767);
  p.Configure(-50, 200, false, true, true);
  block(1000); block(1000); assert(std::fabs(pcm[479] - 1000) < .01);
  p.Configure(-50, 200, false, false, true);
  block(1000); block(1000); assert(std::fabs(pcm[479] - 2000) < .01);
  p.Configure(-50, 0, false, false, true);
  block(1000); assert(pcm[479] == 0);
  p.Configure(-50, 100, true, false, true);
#if defined(_WIN32)
  p.Reset(); block(30); block(30); block(2000);
  assert(pcm[0] > 0 && pcm[0] < 1); assert(std::fabs(pcm[479] - 30) < .1);
  for (int i = 0; i < 19; ++i) block(30);
  block(30); assert(pcm[0] > 0 && pcm[479] < pcm[0]);
  for (int i = 0; i < 5; ++i) block(30);
  block(30); assert(pcm[479] == 0);
  p.Reset(); block(0); block(30); block(2000); block(2000);
  for (float sample : pcm) assert(std::fabs(sample - 30) < .1);
#else
  p.Reset(); block(30); block(30); block(2000);
  assert(std::fabs(pcm[0] - 30) < .1);
  for (int i = 0; i < 20; ++i) block(30);
  assert(pcm[0] == 0);
#endif
  p.Reset(); block(1); assert(pcm[479] == 0);
  block(2000); block(2000); block(2000); assert(pcm[0] > 0);
  block(10); assert(pcm[479] > 0);
  for (int i = 0; i < 25; ++i) block(1);
  assert(pcm[479] == 0);
  p.Configure(-20, 100, false, false, true);
  block(1); assert(pcm[479] > 0);
  p.Initialize(48000, 2); block(1000);
  assert(!p.supported() && pcm[479] == 0);
  return 0;
}
