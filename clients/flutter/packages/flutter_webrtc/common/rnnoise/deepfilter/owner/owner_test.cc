#include "owner.h"
#include "../../webrtc_capture_adapter.h"
#include <cassert>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <thread>
using namespace boohta;
using namespace boohta::deepfilter;
int wmain(int argc, wchar_t** argv) {
  assert(argc == 3);
  std::ifstream in{std::filesystem::path(argv[2])};
  std::string dll_hash; in >> dll_hash;
  wchar_t temp[MAX_PATH]{}, model[MAX_PATH]{};
  assert(GetTempPathW(MAX_PATH, temp) && GetTempFileNameW(temp, L"dfo", 0, model));
  HANDLE out = CreateFileW(model, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, 0, nullptr);
  assert(out != INVALID_HANDLE_VALUE);
  DWORD written = 0;
  assert(WriteFile(out, "abc", 3, &written, nullptr) && written == 3 && CloseHandle(out));
  const char* hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
  {
    ExperimentalOwner owner;
    assert(!owner.Open(argv[1], dll_hash.c_str(), model, "invalid"));
    assert(!owner.hook());
    assert(owner.Open(argv[1], dll_hash.c_str(), model, hash));
    assert(owner.hook() && !owner.Open(argv[1], dll_hash.c_str(), model, hash));
    assert(owner.hook()->ModelId() == nullptr); // The fixture is not the pinned production model.
    {
      WebrtcCaptureAdapter adapter(owner.hook());
      adapter.Initialize(48000, 1);
      adapter.processor.SetEngine(RnnoiseCaptureProcessor::Engine::kDeepFilter);
      const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
      while (owner.hook()->Readiness() == HookReadiness::preparing && std::chrono::steady_clock::now() < deadline)
        std::this_thread::yield();
      assert(owner.hook()->Readiness() == HookReadiness::ready);
      float pcm[480]{};
      for (int frame = 0; frame < 12; ++frame) {
        for (float& value : pcm) value = 2000.f;
        assert(adapter.processor.Process(pcm, 480, 480));
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
      }
      assert(adapter.processor.EffectiveEngine() == RnnoiseCaptureProcessor::Engine::kDeepFilter);
      assert(adapter.processor.processed_frames() > 0 && adapter.processor.fallback_frames() == 0);
      assert(pcm[0] == 1000.f);
      adapter.processor.SetEngine(RnnoiseCaptureProcessor::Engine::kBrowser);
    }
    assert(!DeleteFileW(model));
  }
  assert(DeleteFileW(model));
}
