#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <roapi.h>
#include <shobjidl.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize Windows Runtime (which also initializes a COM STA apartment)
  // so both Shell/Win32 plugins and WRL WinRT toast calls share a valid apartment.
  const HRESULT ro_hr = ::RoInitialize(RO_INIT_SINGLETHREADED);
  bool co_initialized_fallback = false;
  if (FAILED(ro_hr) && ro_hr != RPC_E_CHANGED_MODE) {
    co_initialized_fallback =
        SUCCEEDED(::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED));
  }
  ::SetCurrentProcessExplicitAppUserModelID(L"AICompanion.Desktop");

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  bool start_hidden = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--minimized-to-tray" || arg == "--autostart") {
      start_hidden = true;
      break;
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_hidden);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"AI Companion", origin, size)) {
    if (SUCCEEDED(ro_hr)) {
      ::RoUninitialize();
    } else if (co_initialized_fallback) {
      ::CoUninitialize();
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (SUCCEEDED(ro_hr)) {
    ::RoUninitialize();
  } else if (co_initialized_fallback) {
    ::CoUninitialize();
  }
  return EXIT_SUCCESS;
}
