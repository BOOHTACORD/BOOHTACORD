// Fixed-purpose local monitor. No downloads or command interpreter.
#include <windows.h>

#include <algorithm>
#include <bcrypt.h>
#include <chrono>
#include <cwctype>
#include <filesystem>
#include <fstream>
#include <regex>
#include <shellapi.h>
#include <stdexcept>
#include <string>
#include <thread>
#include <tlhelp32.h>
#include <vector>
#include <winrt/Windows.Data.Json.h>
#include <winrt/base.h>
using winrt::Windows::Data::Json::JsonObject;
using winrt::Windows::Data::Json::JsonValue;
namespace fs = std::filesystem;
// Extended paths keep the per-user cache/baseline usable without changing the
// machine-wide LongPathsEnabled policy (or requiring administrator rights).
static fs::path NativePath(const fs::path &path) {
  std::wstring value = fs::absolute(path).lexically_normal().wstring();
  if (value.rfind(L"\\\\?\\", 0) == 0)
    return fs::path(value);
  if (value.rfind(L"\\\\", 0) == 0)
    return fs::path(L"\\\\?\\UNC\\" + value.substr(2));
  return fs::path(L"\\\\?\\" + value);
}
static std::wstring ShellPath(const fs::path &path) {
  const auto value = path.wstring();
  if (value.rfind(L"\\\\?\\UNC\\", 0) == 0)
    return L"\\\\" + value.substr(8);
  if (value.rfind(L"\\\\?\\", 0) == 0)
    return value.substr(4);
  return value;
}
static constexpr auto exeName = L"boohtacord_desktop.exe";
static JsonObject Read(const fs::path &file, std::uintmax_t maximum = 65536) {
  if (!fs::is_regular_file(file) || fs::file_size(file) > maximum)
    return nullptr;
  std::ifstream stream(file, std::ios::binary);
  std::string bytes((std::istreambuf_iterator<char>(stream)), {});
  JsonObject result{nullptr};
  JsonObject::TryParse(winrt::to_hstring(bytes), result);
  return result;
}
static std::wstring Value(const JsonObject &json, const wchar_t *key) {
  return json ? std::wstring(json.GetNamedString(key, L"")) : L"";
}
static void Atomic(const fs::path &file, const JsonObject &json) {
  auto temp = file;
  temp += L".tmp";
  {
    std::ofstream out(temp, std::ios::binary);
    out << winrt::to_string(json.Stringify());
    out.flush();
    if (!out)
      throw std::runtime_error("write");
  }
  if (!MoveFileExW(temp.c_str(), file.c_str(),
                   MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
    throw std::runtime_error("rename");
}
static bool Within(const fs::path &root, const fs::path &child) {
  auto a = NativePath(root).lexically_normal().wstring(),
       b = NativePath(child).lexically_normal().wstring();
  std::transform(a.begin(), a.end(), a.begin(), ::towlower);
  std::transform(b.begin(), b.end(), b.begin(), ::towlower);
  return b.size() > a.size() && b.compare(0, a.size(), a) == 0 &&
         b[a.size()] == L'\\';
}
static bool SafeTree(const fs::path &root) {
  if ((GetFileAttributesW(root.c_str()) & FILE_ATTRIBUTE_REPARSE_POINT) != 0)
    return false;
  for (auto &e : fs::recursive_directory_iterator(root))
    if ((GetFileAttributesW(e.path().c_str()) & FILE_ATTRIBUTE_REPARSE_POINT) !=
        0)
      return false;
  return true;
}
static std::wstring Build(const fs::path &app) {
  auto file = app / exeName;
  DWORD ignored = 0, length = GetFileVersionInfoSizeW(file.c_str(), &ignored);
  if (!length || length > 1048576)
    return L"";
  std::vector<BYTE> data(length);
  if (!GetFileVersionInfoW(file.c_str(), 0, length, data.data()))
    return L"";
  VS_FIXEDFILEINFO *info = nullptr;
  UINT size = 0;
  if (!VerQueryValueW(data.data(), L"\\", reinterpret_cast<void **>(&info),
                      &size) ||
      size < sizeof(*info) || info->dwSignature != 0xfeef04bd)
    return L"";
  return std::to_wstring(LOWORD(info->dwFileVersionLS));
}
static std::wstring Digest(const fs::path &file) {
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr,
                                  0) < 0)
    return L"";
  if (BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) < 0) {
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return L"";
  }
  std::ifstream stream(file, std::ios::binary);
  char bytes[65536];
  bool valid = stream.is_open();
  while (stream) {
    stream.read(bytes, sizeof(bytes));
    auto size = stream.gcount();
    if (size > 0 && BCryptHashData(hash, reinterpret_cast<PUCHAR>(bytes),
                                   static_cast<ULONG>(size), 0) < 0) {
      valid = false;
      break;
    }
  }
  if (stream.bad())
    valid = false;
  unsigned char result[32];
  if (BCryptFinishHash(hash, result, 32, 0) < 0)
    valid = false;
  BCryptDestroyHash(hash);
  BCryptCloseAlgorithmProvider(algorithm, 0);
  if (!valid)
    return L"";
  std::wstring output;
  const wchar_t *digits = L"0123456789abcdef";
  for (auto byte : result) {
    output += digits[byte >> 4];
    output += digits[byte & 15];
  }
  return output;
}
static bool BaselineValid(const fs::path &root, const fs::path &backup) {
  auto manifest = Read(root / L"baseline.json", 2097152);
  if (!manifest || manifest.GetNamedNumber(L"schema_version", 0) != 1)
    return false;
  auto files = manifest.GetNamedObject(L"files");
  if (files.Size() == 0 || files.Size() > 5000)
    return false;
  std::size_t count = 0;
  for (auto &entry : fs::recursive_directory_iterator(backup))
    if (entry.is_regular_file())
      count++;
  if (count != files.Size())
    return false;
  for (auto &pair : files) {
    fs::path relative = std::wstring(pair.Key());
    auto expected = std::wstring(pair.Value().GetString());
    if (relative.is_absolute() || relative.wstring().size() > 1024 ||
        !Within(backup, fs::weakly_canonical(backup / relative)) ||
        !std::regex_match(expected, std::wregex(L"[0-9a-f]{64}")) ||
        Digest(backup / relative) != expected)
      return false;
  }
  return true;
}
static bool OwnProcess(DWORD pid, const fs::path &executable) {
  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, FALSE, pid);
  if (!process)
    return false;
  wchar_t name[32768];
  DWORD length = 32768;
  bool same =
      WaitForSingleObject(process, 0) == WAIT_TIMEOUT &&
      QueryFullProcessImageNameW(process, 0, name, &length) &&
      _wcsicmp(NativePath(name).c_str(), NativePath(executable).c_str()) == 0;
  CloseHandle(process);
  return same;
}
static std::vector<DWORD> Instances(const fs::path &executable) {
  std::vector<DWORD> result;
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE)
    throw std::runtime_error("processes");
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  if (Process32FirstW(snapshot, &entry))
    do {
      if (_wcsicmp(entry.szExeFile, exeName) == 0 &&
          OwnProcess(entry.th32ProcessID, executable))
        result.push_back(entry.th32ProcessID);
    } while (Process32NextW(snapshot, &entry));
  CloseHandle(snapshot);
  return result;
}
static BOOL CALLBACK CloseWindow(HWND window, LPARAM pid) {
  DWORD owner;
  GetWindowThreadProcessId(window, &owner);
  if (owner == static_cast<DWORD>(pid))
    PostMessageW(window, WM_CLOSE, 0, 0);
  return TRUE;
}
static void Launch(const fs::path &directory) {
  SHELLEXECUTEINFOW info{};
  info.cbSize = sizeof(info);
  info.fMask = SEE_MASK_FLAG_NO_UI;
  auto file = ShellPath(directory / exeName);
  auto working = ShellPath(directory);
  info.lpFile = file.c_str();
  info.lpDirectory = working.c_str();
  info.nShow = SW_SHOWNOACTIVATE;
  ShellExecuteExW(&info);
}
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  try {
    winrt::init_apartment();
    int argc;
    auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (argc < 3 || std::wstring(argv[1]) != L"--plan")
      return 2;
    fs::path planPath = fs::weakly_canonical(NativePath(argv[2]));
    LocalFree(argv);
    wchar_t local[32768];
    DWORD count = GetEnvironmentVariableW(L"LOCALAPPDATA", local, 32768);
    if (!count || count >= 32768 || !Within(local, planPath))
      return 2;
    auto plan = Read(planPath);
    if (!plan)
      return 2;
    auto transaction = Value(plan, L"transaction"),
         newBuild = Value(plan, L"new_build"),
         oldBuild = Value(plan, L"old_build"),
         release = Value(plan, L"new_release");
    fs::path target = NativePath(Value(plan, L"target")),
             backup = NativePath(Value(plan, L"backup")),
             root = planPath.parent_path();
    if (!std::regex_match(transaction, std::wregex(L"[A-Fa-f0-9-]{36}")) ||
        !Within(local, target) || target.filename() != L"current" ||
        backup != root / L"previous" ||
        root.wstring().find(L"DesktopUpdates") == std::wstring::npos)
      return 2;
    auto lock = root / L"recovery.lock";
    HANDLE exclusive =
        CreateFileW(lock.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr,
                    OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (exclusive == INVALID_HANDLE_VALUE)
      return 0;
    auto outcome = root / L"recovery-outcome.json",
         ack = root / L"bootstrap-ack.json";
    HKEY registry;
    const wchar_t *key =
        L"Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce";
    if (RegCreateKeyExW(HKEY_CURRENT_USER, key, 0, nullptr, 0, KEY_SET_VALUE,
                        nullptr, &registry, nullptr) != ERROR_SUCCESS)
      return 2;
    auto label = L"BOOHTACORDRecovery-" + transaction;
    auto finish = [&](const wchar_t *status, const wchar_t *reason) {
      JsonObject v;
      v.SetNamedValue(L"transaction",
                      JsonValue::CreateStringValue(transaction));
      v.SetNamedValue(L"status", JsonValue::CreateStringValue(status));
      v.SetNamedValue(L"reason", JsonValue::CreateStringValue(reason));
      Atomic(outcome, v);
      RegDeleteValueW(registry, label.c_str());
    };
    auto prior = Read(outcome);
    if (Value(prior, L"transaction") == transaction &&
        !Value(prior, L"status").empty()) {
      RegDeleteValueW(registry, label.c_str());
      return 0;
    }
    if (!fs::is_directory(backup)) {
      if (Build(target) == oldBuild)
        finish(L"rolledBack", L"restore_interrupted");
      else
        finish(L"manualRecovery", L"baseline_identity");
      return 0;
    }
    if (!SafeTree(backup) || Build(backup) != oldBuild ||
        !BaselineValid(root, backup)) {
      finish(L"manualRecovery", L"baseline_identity");
      return 2;
    }
    wchar_t self[32768];
    GetModuleFileNameW(nullptr, self, 32768);
    if (planPath.wstring().find(L'"') != std::wstring::npos)
      return 2;
    std::wstring command = L"\"" + std::wstring(self) + L"\" --plan \"" +
                           planPath.wstring() + L"\"";
    if (RegSetValueExW(registry, label.c_str(), 0, REG_SZ,
                       reinterpret_cast<const BYTE *>(command.c_str()),
                       static_cast<DWORD>((command.size() + 1) *
                                          sizeof(wchar_t))) != ERROR_SUCCESS) {
      finish(L"manualRecovery", L"recovery_registration");
      return 2;
    }
    auto cancelled = [&]() {
      return Value(Read(root / L"cancel.json"), L"transaction") == transaction;
    };
    {
      JsonObject ready;
      ready.SetNamedValue(L"transaction",
                          JsonValue::CreateStringValue(transaction));
      Atomic(root / L"recovery-ready.json", ready);
    }
    auto executable = target / exeName;
    DWORD oldPid = static_cast<DWORD>(plan.GetNamedNumber(L"old_pid", 0));
    auto wait = []() {
      std::this_thread::sleep_for(std::chrono::milliseconds(250));
    };
    auto deadline =
        std::chrono::steady_clock::now() + std::chrono::seconds(180);
    while (OwnProcess(oldPid, executable) &&
           std::chrono::steady_clock::now() < deadline) {
      if (cancelled()) {
        finish(L"cancelled", L"apply_cancelled");
        return 0;
      }
      wait();
    }
    if (OwnProcess(oldPid, executable)) {
      finish(L"manualRecovery", L"old_process_running");
      return 0;
    }
    deadline = std::chrono::steady_clock::now() + std::chrono::seconds(120);
    while (std::chrono::steady_clock::now() < deadline) {
      if (cancelled()) {
        finish(L"cancelled", L"apply_cancelled");
        return 0;
      }
      auto receipt = Read(ack);
      if (Value(receipt, L"transaction") == transaction &&
          Value(receipt, L"release_id") == release &&
          Value(receipt, L"native_build") == newBuild &&
          Build(target) == newBuild) {
        finish(L"completed", L"bootstrap");
        return 0;
      }
      wait();
    }
    auto build = Build(target);
    if (!build.empty() && build != oldBuild && build != newBuild) {
      finish(L"manualRecovery", L"installation_changed");
      return 0;
    }
    if (build == newBuild) {
      for (auto process : Instances(executable))
        EnumWindows(CloseWindow, process);
      deadline = std::chrono::steady_clock::now() + std::chrono::seconds(15);
      while (!Instances(executable).empty() &&
             std::chrono::steady_clock::now() < deadline)
        wait();
    }
    if (!Instances(executable).empty()) {
      finish(L"manualRecovery", L"new_process_running");
      return 0;
    }
    if (Build(target) == oldBuild) {
      finish(L"rolledBack", L"apply_failed");
      Launch(target);
      return 0;
    }
    auto failed = root / (L"failed-" + transaction);
    std::error_code error;
    if (fs::exists(target)) {
      fs::rename(target, failed, error);
      if (error) {
        finish(L"manualRecovery", L"replace_denied");
        return 0;
      }
    }
    fs::rename(backup, target, error);
    if (error) {
      if (fs::exists(failed))
        fs::rename(failed, target, error);
      finish(L"manualRecovery", L"restore_denied");
      return 0;
    }
    finish(L"rolledBack", L"local_bootstrap");
    Launch(target);
    RegCloseKey(registry);
    CloseHandle(exclusive);
    return 0;
  } catch (...) {
    return 2;
  }
}
