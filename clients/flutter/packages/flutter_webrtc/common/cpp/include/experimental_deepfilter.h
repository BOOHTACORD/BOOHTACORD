#ifndef FLUTTER_EXPERIMENTAL_DEEPFILTER_H_
#define FLUTTER_EXPERIMENTAL_DEEPFILTER_H_
#include <memory>
namespace boohta::deepfilter { class CaptureHook; }
namespace flutter_webrtc_plugin {
class ExperimentalDeepFilter {
 public:
  ExperimentalDeepFilter();
  ~ExperimentalDeepFilter();
  ExperimentalDeepFilter(const ExperimentalDeepFilter&) = delete;
  ExperimentalDeepFilter& operator=(const ExperimentalDeepFilter&) = delete;
  bool Open();
  boohta::deepfilter::CaptureHook* hook() const noexcept;
 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};
std::unique_ptr<ExperimentalDeepFilter> OpenExperimentalDeepFilter();
}
#endif
