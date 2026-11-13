#include "verified_file.h"
#include <bcrypt.h>
#include <array>
#include <cstring>

namespace boohta::deepfilter {
namespace {
struct HashHandles {
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  ~HashHandles() { if (hash) BCryptDestroyHash(hash); if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0); }
};
int Hex(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}
bool Parse(const char* text, std::array<unsigned char, 32>& result) {
  if (!text || std::strlen(text) != 64) return false;
  for (std::size_t i = 0; i < result.size(); ++i) {
    const int high = Hex(text[2 * i]), low = Hex(text[2 * i + 1]);
    if (high < 0 || low < 0) return false;
    result[i] = static_cast<unsigned char>((high << 4) | low);
  }
  return true;
}
bool AbsoluteLocal(const std::wstring& path) {
  return path.size() >= 3 && ((path[0] >= L'A' && path[0] <= L'Z') || (path[0] >= L'a' && path[0] <= L'z')) &&
         path[1] == L':' && (path[2] == L'\\' || path[2] == L'/');
}
bool Verify(HANDLE file, const std::array<unsigned char, 32>& expected, std::uint64_t limit) {
  FILE_ATTRIBUTE_TAG_INFO info{};
  LARGE_INTEGER size{};
  if (!GetFileInformationByHandleEx(file, FileAttributeTagInfo, &info, sizeof(info)) ||
      (info.FileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) ||
      !GetFileSizeEx(file, &size) || size.QuadPart <= 0 || static_cast<std::uint64_t>(size.QuadPart) > limit)
    return false;
  HashHandles handles;
  if (BCryptOpenAlgorithmProvider(&handles.algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0 ||
      BCryptCreateHash(handles.algorithm, &handles.hash, nullptr, 0, nullptr, 0, 0) < 0) return false;
  std::array<unsigned char, 65536> buffer{};
  DWORD read = 0;
  do {
    if (!ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &read, nullptr)) return false;
    if (read && BCryptHashData(handles.hash, buffer.data(), read, 0) < 0) return false;
  } while (read);
  std::array<unsigned char, 32> actual{};
  if (BCryptFinishHash(handles.hash, actual.data(), static_cast<ULONG>(actual.size()), 0) < 0) return false;
  unsigned difference = 0;
  for (std::size_t i = 0; i < actual.size(); ++i) difference |= actual[i] ^ expected[i];
  return difference == 0;
}
}  // namespace
VerifiedFile::~VerifiedFile() { if (handle_ != INVALID_HANDLE_VALUE) CloseHandle(handle_); }
bool VerifiedFile::Open(const std::wstring& path, const char* sha256, std::uint64_t max_bytes) {
  std::array<unsigned char, 32> expected{};
  if (handle_ != INVALID_HANDLE_VALUE || !AbsoluteLocal(path) || !Parse(sha256, expected)) return false;
  const HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                                  FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
  if (file == INVALID_HANDLE_VALUE) return false;
  if (!Verify(file, expected, max_bytes)) { CloseHandle(file); return false; }
  handle_ = file;
  return true;
}
}  // namespace boohta::deepfilter
