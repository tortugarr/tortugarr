#ifndef RUNNER_METHOD_CALL_ARGS_H_
#define RUNNER_METHOD_CALL_ARGS_H_

#include <flutter/encodable_value.h>

#include <string>

// Typed readers for a method call's argument map, shared by every channel
// handler in the runner. Each returns the fallback (or an empty string) when
// the key is missing or holds a different type.
namespace method_call_args {

// Accepts both int32 and int64 encodings, since the standard codec picks
// whichever fits the value.
int GetInt(const flutter::EncodableMap& map, const char* key, int fallback);
bool GetBool(const flutter::EncodableMap& map, const char* key, bool fallback);
std::string GetString(const flutter::EncodableMap& map, const char* key);

}  // namespace method_call_args

#endif  // RUNNER_METHOD_CALL_ARGS_H_
