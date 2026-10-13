# Standalone Phase 0 probe for native HDR video output on Windows.
#
# Deliberately NOT wired into windows/CMakeLists.txt - it is a developer tool,
# not part of the app, and nothing add_subdirectory()s this folder.
#
#   cmake -S native/hdr_probe -B build/hdr_probe
#   cmake --build build/hdr_probe --config Release

cmake_minimum_required(VERSION 3.15)
project(hdr_probe LANGUAGES CXX)

add_executable(hdr_probe "hdr_probe.cpp")

target_compile_features(hdr_probe PRIVATE cxx_std_17)
target_compile_definitions(hdr_probe PRIVATE UNICODE _UNICODE NOMINMAX)

# libmpv is loaded with LoadLibrary at runtime, so there is nothing to link
# against and no headers to find. Only the Win32 window needs a library.
if(MSVC)
  target_compile_options(hdr_probe PRIVATE /W4)
endif()
