#include <jni.h>

#include <algorithm>

#include "ScreenAudioSource.h"

using flutter_webrtc_plugin::ScreenAudioSource;

extern "C" JNIEXPORT jlong JNICALL
Java_com_cloudwebrtc_webrtc_ScreenAudioCapture_nativeCreateSource(JNIEnv *, jclass) {
  auto *source = new ScreenAudioSource();
  source->AddRef();
  return reinterpret_cast<jlong>(source);
}

extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_ScreenAudioCapture_nativeCaptureFrame(
    JNIEnv *env, jclass, jlong native_source, jshortArray samples,
    jint sample_count, jint sample_rate, jint channels) {
  auto *source = reinterpret_cast<ScreenAudioSource *>(native_source);
  if (source == nullptr || samples == nullptr || sample_rate <= 0 || channels <= 0) return;
  const jsize array_length = env->GetArrayLength(samples);
  sample_count = std::min<jint>(sample_count, array_length);
  if (sample_count <= 0) return;
  jshort *pcm = env->GetShortArrayElements(samples, nullptr);
  if (pcm == nullptr) return;
  source->CaptureFrame(pcm, 16, sample_rate, static_cast<size_t>(channels),
                       static_cast<size_t>(sample_count / channels));
  env->ReleaseShortArrayElements(samples, pcm, JNI_ABORT);
}

extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_ScreenAudioCapture_nativeStopSource(
    JNIEnv *, jclass, jlong native_source) {
  auto *source = reinterpret_cast<ScreenAudioSource *>(native_source);
  if (source != nullptr) source->Stop();
}
