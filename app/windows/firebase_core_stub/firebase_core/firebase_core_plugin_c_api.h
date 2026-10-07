// Stub header for the firebase_core Windows plugin on ARM64. Firebase ships no
// ARM64 binaries for Windows, and the real firebase_core header pulls in
// firebase/app.h from the C++ SDK, which is not available for ARM64. The app
// only uses Firebase on mobile, so the generated plugin registrant includes this
// header instead. It declares just the registrar entry point that
// firebase_core_stub.cpp implements as a no-op. The registrar is taken as void*
// so the header needs no Firebase or Flutter includes; the registrant passes a
// FlutterDesktopPluginRegistrarRef, which converts to void* implicitly.
#ifndef FLUTTER_PLUGIN_FIREBASE_CORE_PLUGIN_C_API_STUB_H_
#define FLUTTER_PLUGIN_FIREBASE_CORE_PLUGIN_C_API_STUB_H_

#if defined(__cplusplus)
extern "C" {
#endif

void FirebaseCorePluginCApiRegisterWithRegistrar(void* registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_FIREBASE_CORE_PLUGIN_C_API_STUB_H_
