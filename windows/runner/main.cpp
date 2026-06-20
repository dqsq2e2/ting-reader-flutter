#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <utility>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

std::vector<std::wstring> LoadPrivateFonts() {
  wchar_t module_path[MAX_PATH];
  const DWORD length =
      ::GetModuleFileNameW(nullptr, module_path, ARRAYSIZE(module_path));
  if (length == 0 || length == ARRAYSIZE(module_path)) {
    return {};
  }

  std::wstring directory(module_path, length);
  const size_t separator = directory.find_last_of(L"\\/");
  directory.resize(separator == std::wstring::npos ? 0 : separator + 1);

  std::vector<std::wstring> loaded_fonts;
  for (const wchar_t* filename : {
           L"NotoSansCJKsc-Regular.otf",
           L"NotoSansCJKsc-Bold.otf",
       }) {
    std::wstring path = directory + L"fonts\\" + filename;
    if (::AddFontResourceExW(path.c_str(), FR_PRIVATE, nullptr) > 0) {
      loaded_fonts.push_back(std::move(path));
    }
  }
  return loaded_fonts;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  const std::vector<std::wstring> private_fonts = LoadPrivateFonts();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"听悦", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  for (const std::wstring& font : private_fonts) {
    ::RemoveFontResourceExW(font.c_str(), FR_PRIVATE, nullptr);
  }
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
