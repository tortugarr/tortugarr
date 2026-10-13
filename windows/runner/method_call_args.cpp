#include "method_call_args.h"

namespace method_call_args {

int GetInt(const flutter::EncodableMap& map, const char* key, int fallback) {
  const auto it = map.find(flutter::EncodableValue(std::string(key)));
  if (it != map.end()) {
    if (const auto* value = std::get_if<int>(&it->second)) {
      return *value;
    }
    if (const auto* value = std::get_if<int64_t>(&it->second)) {
      return static_cast<int>(*value);
    }
  }
  return fallback;
}

bool GetBool(const flutter::EncodableMap& map, const char* key, bool fallback) {
  const auto it = map.find(flutter::EncodableValue(std::string(key)));
  if (it != map.end()) {
    if (const auto* value = std::get_if<bool>(&it->second)) {
      return *value;
    }
  }
  return fallback;
}

std::string GetString(const flutter::EncodableMap& map, const char* key) {
  const auto it = map.find(flutter::EncodableValue(std::string(key)));
  if (it != map.end()) {
    if (const auto* value = std::get_if<std::string>(&it->second)) {
      return *value;
    }
  }
  return std::string();
}

}  // namespace method_call_args
