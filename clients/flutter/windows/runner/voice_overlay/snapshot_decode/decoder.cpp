#include "decoder.h"
#include <variant>

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;
const EncodableValue* Find(const EncodableMap& map, const char* key) {
  const auto found = map.find(EncodableValue(std::string(key)));
  return found == map.end() ? nullptr : &found->second;
}
std::optional<std::wstring> Name(const std::string& value) {
  if (value.empty() || value.size() > 256) return std::nullopt;
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      value.data(), static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) return std::nullopt;
  std::wstring wide(size, L'\0');
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), wide.data(), size)) return std::nullopt;
  if (wide.size() > 128) wide.resize(128);
  if (!wide.empty() && wide.back() >= 0xD800 && wide.back() <= 0xDBFF) wide.pop_back();
  return wide;
}
}

std::optional<DecodedOverlaySnapshot> DecodeOverlaySnapshot(const EncodableValue* value) {
  const auto* args = value ? std::get_if<EncodableMap>(value) : nullptr;
  const auto* flag = args ? Find(*args, "visible") : nullptr;
  const auto* visible = flag ? std::get_if<bool>(flag) : nullptr;
  if (!visible) return std::nullopt;
  if (!*visible) return DecodedOverlaySnapshot{false, {}};
  const auto* raw = Find(*args, "members");
  const auto* members = raw ? std::get_if<flutter::EncodableList>(raw) : nullptr;
  if (!members || members->size() > 12) return std::nullopt;
  std::vector<VoiceOverlayMember> projected;
  for (const auto& item : *members) {
    const auto* member = std::get_if<EncodableMap>(&item);
    if (!member) return std::nullopt;
    const auto* name_value = Find(*member, "displayName");
    const auto* speaking_value = Find(*member, "speaking");
    const auto* muted_value = Find(*member, "microphoneMuted");
    const auto* deafened_value = Find(*member, "deafened");
    const auto* name = name_value ? std::get_if<std::string>(name_value) : nullptr;
    const auto* speaking = speaking_value ? std::get_if<bool>(speaking_value) : nullptr;
    const auto* muted = muted_value ? std::get_if<bool>(muted_value) : nullptr;
    const auto* deafened = deafened_value ? std::get_if<bool>(deafened_value) : nullptr;
    const auto wide = name ? Name(*name) : std::nullopt;
    if (!wide || !speaking || !muted || (deafened_value && !deafened)) return std::nullopt;
    projected.push_back({*wide, *speaking, *muted, deafened ? *deafened : false});
  }
  return DecodedOverlaySnapshot{true, projected};
}
