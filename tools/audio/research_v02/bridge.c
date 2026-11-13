#include <string.h>
#include "rnnoise.h"

static float input_frame[480], output_frame[480];
static unsigned char state_storage[65536] __attribute__((aligned(16)));
static int reset_state(void) {
  if (rnnoise_get_size() > sizeof(state_storage) || rnnoise_get_frame_size() != 480) return 0;
  memset(input_frame, 0, sizeof(input_frame));
  memset(output_frame, 0, sizeof(output_frame));
  return rnnoise_init((DenoiseState *)state_storage, 0) == 0;
}
int ns_init(void) {
  if (!reset_state()) return 0;
  rnnoise_process_frame((DenoiseState *)state_storage, output_frame, input_frame);
  return reset_state();
}
void ns_reset(void) { reset_state(); }
float *ns_input(void) { return input_frame; }
float *ns_output(void) { return output_frame; }
float ns_process(void) { return rnnoise_process_frame((DenoiseState *)state_storage, output_frame, input_frame); }
