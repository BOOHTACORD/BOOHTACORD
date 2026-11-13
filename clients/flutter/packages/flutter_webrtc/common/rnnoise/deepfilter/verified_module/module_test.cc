#include "module.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <string>

using boohta::deepfilter::VerifiedModule;
int wmain(int argc, wchar_t** argv) {
  assert(argc == 3);
  std::ifstream hash_file{std::filesystem::path(argv[2])};
  std::string hash; hash_file >> hash;
  assert(hash.size() == 64);
  const auto name = std::filesystem::path(argv[1]).filename().wstring();
  assert(GetModuleHandleW(name.c_str()) == nullptr);
  {
    VerifiedModule wrong;
    assert(!wrong.Open(argv[1], "0000000000000000000000000000000000000000000000000000000000000000", 100000000));
    assert(GetModuleHandleW(name.c_str()) == nullptr);
  }
  {
    VerifiedModule module;
    assert(module.Open(argv[1], hash.c_str(), 100000000));
    using Add = int (__cdecl *)(int, int);
    auto add = reinterpret_cast<Add>(module.Symbol("fixture_add"));
    assert(add && add(20, 22) == 42);
    assert(module.Symbol("missing") == nullptr);
    assert(!DeleteFileW(argv[1]));
    assert(!module.Open(argv[1], hash.c_str(), 100000000));
  }
  assert(GetModuleHandleW(name.c_str()) == nullptr);
}
