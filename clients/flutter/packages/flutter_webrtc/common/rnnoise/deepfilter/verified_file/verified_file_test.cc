#include "verified_file.h"
#include <cassert>
#include <string>

using boohta::deepfilter::VerifiedFile;
int main() {
  wchar_t directory[MAX_PATH]{}, temporary[MAX_PATH]{};
  assert(GetTempPathW(MAX_PATH, directory) > 0);
  assert(GetTempFileNameW(directory, L"dfn", 0, temporary));
  const std::wstring unicode = std::wstring(temporary) + L"-\u0437\u0432\u0443\u043a";
  assert(MoveFileW(temporary, unicode.c_str()));
  HANDLE output = CreateFileW(unicode.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  assert(output != INVALID_HANDLE_VALUE);
  DWORD written = 0;
  assert(WriteFile(output, "abc", 3, &written, nullptr) && written == 3);
  assert(CloseHandle(output));
  const char* hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
  {
    VerifiedFile valid;
    assert(valid.Open(unicode, hash, 3));
    HANDLE overwrite = CreateFileW(unicode.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
    assert(overwrite == INVALID_HANDLE_VALUE);
    assert(!DeleteFileW(unicode.c_str()));
    assert(!valid.Open(unicode, hash, 3));
  }
  {
    VerifiedFile bad;
    assert(!bad.Open(unicode, "0000000000000000000000000000000000000000000000000000000000000000", 3));
    assert(!bad.Open(unicode, hash, 2));
    assert(!bad.Open(L"relative.txt", hash, 3));
    assert(!bad.Open(unicode, "invalid", 3));
  }
  assert(DeleteFileW(unicode.c_str()));
}
