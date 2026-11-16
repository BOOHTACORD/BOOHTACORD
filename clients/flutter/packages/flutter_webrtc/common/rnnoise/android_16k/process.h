#ifndef BOOHTA_RNNOISE_ANDROID_16K_PROCESS_H_
#define BOOHTA_RNNOISE_ANDROID_16K_PROCESS_H_
#include "../deepfilter/resample_16k/resampler.h"
extern "C" {
#include "../upstream/include/rnnoise.h"
}
namespace boohta {
inline void ProcessAndroid16k(DenoiseState* state, deepfilter::Resampler16k& resampler,
                             float* pcm) {
  float work[480];
  resampler.Upsample(pcm, work);
  rnnoise_process_frame(state, work, work);
  resampler.Downsample(work, pcm);
}
}
#endif
