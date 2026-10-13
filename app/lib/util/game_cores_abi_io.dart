import 'dart:ffi' show Abi;

/// The buildbot path segment and in-zip file suffix for this device, or null
/// when libretro publishes no build for the architecture.
({String dir, String suffix})? currentBuildbotTarget() {
  switch (Abi.current()) {
    case Abi.androidArm64:
      return (dir: 'android/latest/arm64-v8a', suffix: '_libretro_android.so.zip');
    case Abi.androidArm:
      return (dir: 'android/latest/armeabi-v7a', suffix: '_libretro_android.so.zip');
    case Abi.androidX64:
      return (dir: 'android/latest/x86_64', suffix: '_libretro_android.so.zip');
    case Abi.linuxX64:
      return (dir: 'linux/x86_64/latest', suffix: '_libretro.so.zip');
    case Abi.macosArm64:
      return (dir: 'apple/osx/arm64/latest', suffix: '_libretro.dylib.zip');
    case Abi.macosX64:
      return (dir: 'apple/osx/x86_64/latest', suffix: '_libretro.dylib.zip');
    case Abi.windowsX64:
      return (dir: 'windows/x86_64/latest', suffix: '_libretro.dll.zip');
    default:
      return null;
  }
}

/// The ABI tag used to keep downloaded cores separated by architecture.
String currentAbiTag() =>
    Abi.current().toString().replaceAll(RegExp('[^A-Za-z0-9]'), '');
