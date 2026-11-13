/* Local research bridge only: adapt the v0.1 initialization ABI to v0.2. */
typedef struct DenoiseState DenoiseState;
typedef struct RNNModel RNNModel;
extern int rnnoise_v02_init(DenoiseState *state, RNNModel *model);
extern float rnnoise_v02_process_frame(DenoiseState *state, float *out, const float *in);
static void (*after_frame)(void);

void rnnoise_test_after_frame(void (*callback)(void)) { after_frame = callback; }

int rnnoise_init(DenoiseState *state) {
  return rnnoise_v02_init(state, 0);
}

float rnnoise_process_frame(DenoiseState *state, float *out, const float *in) {
  float result = rnnoise_v02_process_frame(state, out, in);
  void (*callback)(void) = after_frame;
  after_frame = 0;
  if (callback) callback();
  return result;
}
