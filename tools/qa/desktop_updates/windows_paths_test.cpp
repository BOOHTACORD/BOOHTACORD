// Native regression: use the shipping path helpers against real NTFS paths.
#include "../../../clients/flutter/native/desktop_recovery/windows.cpp"
#include <iostream>

int wmain() {
  wchar_t temporary[32768];
  const auto count = GetTempPathW(32768, temporary);
  if (!count || count >= 32768) return 1;
  const auto root = fs::path(temporary) / (L"BOOHTACORD-path-test-" + std::to_wstring(GetCurrentProcessId()));
  if (!fs::create_directory(root)) return 1;
  int failures = 0;
  auto check = [&](bool valid, const char *label) {
    std::cout << label << ": " << (valid ? "PASS" : "FAIL") << '\n';
    if (!valid) ++failures;
  };
  try {
    auto directory = root / L"DesktopUpdates" / L"\u041f\u0440\u043e\u0432\u0435\u0440\u043a\u0430 \u0441 \u043f\u0440\u043e\u0431\u0435\u043b\u0430\u043c\u0438";
    fs::create_directories(directory);
    auto file = directory / L"plan.json";
    { std::ofstream out(file); out << "{}"; }
    auto native = NativePath(file);
    fs::create_directories(directory / L"nested" / L"folder");
    const auto digestFile = directory / L"nested" / L"folder" / L"digest.bin";
    { std::ofstream out(digestFile); out << "synthetic-digest-probe"; }
    const auto mixed = NativePath(directory) / fs::path(L"nested/folder/digest.bin");
    check(!Digest(mixed).empty() && Digest(mixed) == Digest(digestFile), "extended-manifest-posix-separators");
    check(fs::is_regular_file(native), "native-unicode-file");
    check(native == NativePath(native), "native-idempotent");
    check(fs::is_regular_file(NativePath(native)), "native-repeated-file");
    auto canonical = NativePath(fs::weakly_canonical(native));
    auto shape = [](const fs::path &value) {
      std::string result;
      for (auto c : value.wstring()) result += (c == L'\\' || c == L'/' || c == L':' || c == L'?') ? static_cast<char>(c) : 'x';
      return result;
    };
    if (canonical.parent_path() != NativePath(directory))
      std::cout << "redacted-canonical: " << shape(canonical.parent_path())
                << "\nredacted-parent: " << shape(NativePath(directory)) << '\n';
    check(fs::is_regular_file(canonical), "canonical-native-file");
    check(canonical.parent_path() == NativePath(directory), "canonical-parent-identity");
    check(Within(root, file) && Within(root, canonical), "native-scope");
    check(!Within(root, fs::path(root.wstring() + L"-other") / L"plan.json"), "sibling-rejected");
    auto longDirectory = directory;
    for (int i = 0; i < 6; ++i) longDirectory /= L"long-path-segment-with-spaces-0123456789";
    fs::create_directories(NativePath(longDirectory));
    auto longFile = NativePath(longDirectory / L"plan.json");
    { std::ofstream out(longFile); out << "{}"; }
    check(fs::is_regular_file(longFile) && fs::is_regular_file(NativePath(longFile)), "long-file");
    check(fs::is_regular_file(NativePath(fs::weakly_canonical(longFile))), "long-canonical-file");
  } catch (...) {
    std::cout << "native-path-exception: FAIL\n";
    ++failures;
  }
  fs::remove_all(NativePath(root));
  return failures ? 1 : 0;
}
