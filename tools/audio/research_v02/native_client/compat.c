/* Research-only bridge for the upstream v0.2 initialization ABI. */
typedef struct DenoiseState DenoiseState;
typedef struct RNNModel RNNModel;
extern int rnnoise_v02_init(DenoiseState *state, RNNModel *model);
extern float rnnoise_v02_process_frame(DenoiseState *state, float *out, const float *in);

int rnnoise_init(DenoiseState *state) { return rnnoise_v02_init(state, 0); }
float rnnoise_process_frame(DenoiseState *state, float *out, const float *in) {
  return rnnoise_v02_process_frame(state, out, in);
}
