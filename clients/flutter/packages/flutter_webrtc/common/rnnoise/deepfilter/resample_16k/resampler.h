#ifndef BOOHTA_DEEPFILTER_RESAMPLER_16K_H_
#define BOOHTA_DEEPFILTER_RESAMPLER_16K_H_
#include <algorithm>
#include <array>
namespace boohta::deepfilter {
// Two 127-tap, 7.2 kHz Hamming low-pass FIRs at 48 kHz. Audio-thread-only,
// fixed storage, mono 10 ms frames. The combined filter delay is 2.625 ms.
class Resampler16k {
 public:
  void Reset() noexcept { up_ = {}; down_ = {}; }
  void Upsample(const float* in, float* out) noexcept {
    for (int i = 0; i < 160; ++i) {
      for (int phase = 0; phase < 3; ++phase) {
        Push(up_, phase == 0 ? 3.f * in[i] : 0.f);
        out[3*i+phase] = std::clamp(Sample(up_), -32768.f, 32768.f);
      }
    }
  }
  void Downsample(const float* in, float* out) noexcept {
    for (int i = 0; i < 160; ++i) {
      for (int phase = 0; phase < 3; ++phase) Push(down_, in[3*i+phase]);
      out[i] = std::clamp(Sample(down_), -32768.f, 32768.f);
    }
  }
 private:
  static constexpr std::size_t kSize = 127;
  struct Filter { std::array<float, kSize> values{}; std::size_t position = 0; };
  static void Push(Filter& filter, float value) noexcept {
    filter.values[filter.position] = value;
    if (++filter.position == kSize) filter.position = 0;
  }
  static float Sample(const Filter& filter) noexcept {
    float value = 0.f;
    std::size_t index = filter.position;
    for (std::size_t k = 0; k < kSize; ++k) {
      index = index ? index - 1 : kSize - 1;
      value += kTaps[k] * filter.values[index];
    }
    return value;
  }
  static constexpr std::array<float, kSize> kTaps = {
    0.000124798f, 0.000393074f, 0.000347080f, -0.000000000f, -0.000388651f,
    -0.000491381f, -0.000173171f, 0.000359658f, 0.000671466f, 0.000434643f,
    -0.000252220f, -0.000857888f, -0.000806852f, 0.000000000f, 0.000985181f,
    0.001277912f, 0.000457541f, -0.000957541f, -0.001789445f, -0.001153392f,
    0.000663788f, 0.002232518f, 0.002071821f, -0.000000000f, -0.002453838f,
    -0.003132128f, -0.001103411f, 0.002272531f, 0.004181009f, 0.002654514f,
    -0.001505818f, -0.004995786f, -0.004577123f, 0.000000000f, 0.005298517f,
    0.006696238f, 0.002338154f, -0.004778297f, -0.008733317f, -0.005515080f,
    0.003115823f, 0.010309516f, 0.009434205f, -0.000000000f, -0.010948943f,
    -0.013893553f, -0.004881410f, 0.010061747f, 0.018598826f, 0.011915628f,
    -0.006854405f, -0.023191141f, -0.021812050f, 0.000000000f, 0.027286171f,
    0.036443085f, 0.013650306f, -0.030519420f, -0.062702418f, -0.046307968f,
    0.032591195f, 0.150889395f, 0.257149385f, 0.299741848f, 0.257149385f,
    0.150889395f, 0.032591195f, -0.046307968f, -0.062702418f, -0.030519420f,
    0.013650306f, 0.036443085f, 0.027286171f, 0.000000000f, -0.021812050f,
    -0.023191141f, -0.006854405f, 0.011915628f, 0.018598826f, 0.010061747f,
    -0.004881410f, -0.013893553f, -0.010948943f, -0.000000000f, 0.009434205f,
    0.010309516f, 0.003115823f, -0.005515080f, -0.008733317f, -0.004778297f,
    0.002338154f, 0.006696238f, 0.005298517f, 0.000000000f, -0.004577123f,
    -0.004995786f, -0.001505818f, 0.002654514f, 0.004181009f, 0.002272531f,
    -0.001103411f, -0.003132128f, -0.002453838f, -0.000000000f, 0.002071821f,
    0.002232518f, 0.000663788f, -0.001153392f, -0.001789445f, -0.000957541f,
    0.000457541f, 0.001277912f, 0.000985181f, 0.000000000f, -0.000806852f,
    -0.000857888f, -0.000252220f, 0.000434643f, 0.000671466f, 0.000359658f,
    -0.000173171f, -0.000491381f, -0.000388651f, -0.000000000f, 0.000347080f,
    0.000393074f, 0.000124798f,
  };
  Filter up_{}, down_{};
};
}
#endif
