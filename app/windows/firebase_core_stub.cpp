// Stub for the firebase_core Windows plugin on ARM64. Firebase ships no ARM64
// binaries for Windows, and the app only uses Firebase on mobile, so this no-op
// registrar lets the generated plugin registrant link on Windows ARM64.
extern "C" __declspec(dllexport) void FirebaseCorePluginCApiRegisterWithRegistrar(
    void* registrar) {
  (void)registrar;
}
