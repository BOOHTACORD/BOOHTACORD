#include "engine.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <string>

using namespace boohta::deepfilter;
int wmain(int argc, wchar_t** argv) {
  assert(argc == 3);
  std::ifstream in{std::filesystem::path(argv[2])};
  std::string dll_hash; in >> dll_hash;
  assert(dll_hash.size() == 64);
  wchar_t temp[MAX_PATH]{}, file[MAX_PATH]{};
  assert(GetTempPathW(MAX_PATH, temp) && GetTempFileNameW(temp, L"dfm", 0, file));
  const std::wstring model_path = std::wstring(file) + L"-\u0437\u0432\u0443\u043a";
  assert(MoveFileW(file, model_path.c_str()));
  HANDLE handle = CreateFileW(model_path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, 0, nullptr);
  assert(handle != INVALID_HANDLE_VALUE);
  DWORD written = 0;
  assert(WriteFile(handle, "abc", 3, &written, nullptr) && written == 3);
  assert(CloseHandle(handle));
  const char* model_hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
  {
    VerifiedEngine bad;
    assert(!bad.Open(argv[1], dll_hash.c_str(), model_path,
                     "0000000000000000000000000000000000000000000000000000000000000000"));
    assert(!bad.Reset());
  }
  {
    VerifiedEngine engine;
    assert(engine.Open(argv[1], dll_hash.c_str(), model_path, model_hash));
    assert(!DeleteFileW(model_path.c_str()));
    assert(engine.Reset());
    AudioFrame frame{}; frame.samples.fill(0.5f);
    assert(engine.Process(frame));
    for (float value : frame.samples) assert(value == 0.25f);
    assert(engine.Reset());
    assert(engine.Close());
    assert(engine.Close());
  }
  assert(DeleteFileW(model_path.c_str()));
}
