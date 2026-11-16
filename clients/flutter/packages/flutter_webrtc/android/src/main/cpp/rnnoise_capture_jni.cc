#include <jni.h>
#include <new>
#include "rnnoise_capture_processor.h"
using boohta::RnnoiseCaptureProcessor;
static RnnoiseCaptureProcessor* Processor(jlong handle) {
  return reinterpret_cast<RnnoiseCaptureProcessor*>(handle);
}
extern "C" JNIEXPORT jlong JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeCreate(JNIEnv*, jclass) {
  return reinterpret_cast<jlong>(new (std::nothrow) RnnoiseCaptureProcessor(std::malloc, nullptr, true));
}
extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeDestroy(JNIEnv*, jclass, jlong handle) {
  delete Processor(handle);
}
extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeInitialize(JNIEnv*, jclass, jlong handle, jint rate, jint channels) {
  if (handle) Processor(handle)->Initialize(rate, channels);
}
extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeReset(JNIEnv*, jclass, jlong handle) {
  if (handle) Processor(handle)->Reset();
}
extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeSetEngine(JNIEnv*, jclass, jlong handle, jint engine) {
  if (handle && engine >= 0 && engine <= 2)
    Processor(handle)->SetEngine(static_cast<RnnoiseCaptureProcessor::Engine>(engine));
}
extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeProcess(JNIEnv* env, jclass, jlong handle, jint frames, jobject buffer) {
  if (!handle) return;
  auto* pcm = buffer ? static_cast<float*>(env->GetDirectBufferAddress(buffer)) : nullptr;
  auto capacity = buffer ? env->GetDirectBufferCapacity(buffer) : 0;
  if (reinterpret_cast<uintptr_t>(pcm) % alignof(float) != 0) pcm = nullptr;
  Processor(handle)->Process(pcm, frames, capacity >= 0 ? static_cast<int>(capacity / sizeof(float)) : 0);
}
extern "C" JNIEXPORT jlongArray JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeState(JNIEnv* env, jclass, jlong handle) {
  if (!handle) return nullptr;
  auto* p = Processor(handle);
  jlong state[] = {static_cast<jlong>(p->requested_engine()), static_cast<jlong>(p->EffectiveEngine()),
                  p->supported(), static_cast<jlong>(p->processed_frames()),
                  static_cast<jlong>(p->fallback_frames()), p->sample_rate(), p->channels()};
  auto result = env->NewLongArray(7);
  if (result) env->SetLongArrayRegion(result, 0, 7, state);
  return result;
}
extern "C" JNIEXPORT jstring JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeFailureReason(JNIEnv* env, jclass, jlong handle) {
  return env->NewStringUTF(handle ? Processor(handle)->failure_reason() : "processor-unavailable");
}
