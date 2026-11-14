/* Local research bridge only: adapt the v0.1 initialization ABI to v0.2. */
typedef struct DenoiseState DenoiseState;
typedef struct RNNModel RNNModel;
extern int rnnoise_v02_init(DenoiseState *state, RNNModel *model);
extern float rnnoise_v02_process_frame(DenoiseState *state, float *out, const float *in);
static void (*after_frame)(void);
static int fail_initialization;
static int processed_frames;

void rnnoise_test_after_frame(void (*callback)(void)) { after_frame = callback; }
void rnnoise_test_fail_initialization(int fail) { fail_initialization = fail; }
int rnnoise_test_processed_frames(void) { return processed_frames; }

int rnnoise_init(DenoiseState *state) {
  if (fail_initialization) return -1;
  return rnnoise_v02_init(state, 0);
}

float rnnoise_process_frame(DenoiseState *state, float *out, const float *in) {
  ++processed_frames;
  float result = rnnoise_v02_process_frame(state, out, in);
  void (*callback)(void) = after_frame;
  after_frame = 0;
  if (callback) callback();
  return result;
}
