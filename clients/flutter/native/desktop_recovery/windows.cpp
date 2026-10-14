// Fixed-purpose local monitor. No downloads or command interpreter.
#include <algorithm>
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
#include <windows.h>
#include <winrt/Windows.Data.Json.h>
#include <winrt/base.h>
using winrt::Windows::Data::Json::JsonObject;
using winrt::Windows::Data::Json::JsonValue;
namespace fs = std::filesystem;
static constexpr auto exeName = L"boohtacord_desktop.exe";
static JsonObject Read(const fs::path &file) {
  if (!fs::is_regular_file(file) || fs::file_size(file) > 65536)
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
  auto a = root.lexically_normal().wstring(),
       b = child.lexically_normal().wstring();
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
static bool OwnProcess(DWORD pid, const fs::path &executable) {
  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, FALSE, pid);
  if (!process)
    return false;
  wchar_t name[32768];
  DWORD length = 32768;
  bool same = WaitForSingleObject(process, 0) == WAIT_TIMEOUT &&
              QueryFullProcessImageNameW(process, 0, name, &length) &&
              _wcsicmp(name, executable.c_str()) == 0;
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
  auto file = directory / exeName;
  info.lpFile = file.c_str();
  info.lpDirectory = directory.c_str();
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
    fs::path planPath = fs::weakly_canonical(argv[2]);
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
    fs::path target = Value(plan, L"target"), backup = Value(plan, L"backup"),
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
    if (!SafeTree(backup) || Build(backup) != oldBuild) {
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
