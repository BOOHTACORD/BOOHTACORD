/* Offline parity probe. Input/output are mono 48 kHz float32le. */
#include <math.h>
#include <stdio.h>
#include "rnnoise.h"

int main(int argc, char **argv) {
  if (argc != 3) return 1;
  FILE *input = fopen(argv[1], "rb");
  if (!input) return 2;
  if (fseek(input, 0, SEEK_END) || ftell(input) <= 0 || ftell(input) % sizeof(float) ||
      fseek(input, 0, SEEK_SET)) return 2;
  FILE *output = fopen(argv[2], "wbx");
  if (!output) return 2;
  DenoiseState *state = rnnoise_create(NULL);
  if (!state || rnnoise_get_frame_size() != 480) return 3;
  float source[480] = {0}, target[480] = {0};
  rnnoise_process_frame(state, target, source);
  if (rnnoise_init(state, NULL) != 0) return 4;
  size_t count;
  int tail = 0;
  while ((count = fread(source, sizeof(float), 480, input)) > 0 || tail++ < 12) {
    for (size_t i = 0; i < 480; ++i) {
      float value = i < count ? source[i] : 0;
      if (!isfinite(value)) return 5;
      source[i] = fmaxf(-1, fminf(1, value)) * 32768;
    }
    rnnoise_process_frame(state, target, source);
    for (int i = 0; i < 480; ++i) {
      if (!isfinite(target[i])) return 6;
      target[i] = fmaxf(-1, fminf(1, target[i] / 32768));
    }
    if (fwrite(target, sizeof(float), 480, output) != 480) return 7;
  }
  if (ferror(input)) return 8;
  rnnoise_destroy(state);
  int input_error = fclose(input), output_error = fclose(output);
  return input_error || output_error;
}
