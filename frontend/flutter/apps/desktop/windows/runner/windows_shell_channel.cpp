#include "windows_shell_channel.h"

#include <shobjidl.h>
#include <tlhelp32.h>
#include <winternl.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cwctype>
#include <vector>

#include <flutter/standard_method_codec.h>

namespace {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (len <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(len), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), len);
  if (!wide.empty() && wide.back() == L'\0') {
    wide.pop_back();
  }
  return wide;
}

std::string WideToUtf8(const wchar_t* wide) {
  if (wide == nullptr || wide[0] == L'\0') {
    return std::string();
  }
  int len = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (len <= 0) {
    return std::string();
  }
  std::string utf8(static_cast<size_t>(len), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, utf8.data(), len, nullptr, nullptr);
  if (!utf8.empty() && utf8.back() == '\0') {
    utf8.pop_back();
  }
  return utf8;
}

struct ScopedComInit {
  HRESULT hr = E_FAIL;
  bool should_uninit = false;

  ScopedComInit() {
    hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    should_uninit = SUCCEEDED(hr);
  }

  ~ScopedComInit() {
    if (should_uninit) {
      CoUninitialize();
    }
  }

  bool ok() const {
    return SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;
  }
};

void ApplyInitialDirectory(IFileOpenDialog* dialog, const std::string& dir_utf8) {
  if (dialog == nullptr || dir_utf8.empty()) {
    return;
  }
  std::wstring dir_wide = Utf8ToWide(dir_utf8);
  if (dir_wide.empty()) {
    return;
  }
  Microsoft::WRL::ComPtr<IShellItem> folder_item;
  if (SUCCEEDED(SHCreateItemFromParsingName(dir_wide.c_str(), nullptr,
                                            IID_PPV_ARGS(&folder_item)))) {
    dialog->SetFolder(folder_item.Get());
  }
}

std::string ReadStringArg(const flutter::EncodableMap& args, const char* key) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return std::string();
  }
  if (const auto* str = std::get_if<std::string>(&it->second)) {
    return *str;
  }
  return std::string();
}

bool ReadBoolArg(const flutter::EncodableMap& args, const char* key, bool fallback) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return fallback;
  }
  if (const auto* flag = std::get_if<bool>(&it->second)) {
    return *flag;
  }
  return fallback;
}

bool ReadInt64Arg(const flutter::EncodableMap& args, const char* key, int64_t* out_val) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return false;
  }
  if (const auto* val32 = std::get_if<int32_t>(&it->second)) {
    *out_val = static_cast<int64_t>(*val32);
    return true;
  }
  if (const auto* val64 = std::get_if<int64_t>(&it->second)) {
    *out_val = *val64;
    return true;
  }
  return false;
}

struct ScopedHandle {
  HANDLE handle = nullptr;
  explicit ScopedHandle(HANDLE h = nullptr) : handle(h) {}
  ~ScopedHandle() {
    if (handle != nullptr && handle != INVALID_HANDLE_VALUE) {
      CloseHandle(handle);
    }
  }
  ScopedHandle(const ScopedHandle&) = delete;
  ScopedHandle& operator=(const ScopedHandle&) = delete;
  bool valid() const {
    return handle != nullptr && handle != INVALID_HANDLE_VALUE;
  }
};

std::wstring NormalizeWindowsPathLower(std::wstring value) {
  std::replace(value.begin(), value.end(), L'/', L'\\');
  std::transform(value.begin(), value.end(), value.begin(), [](wchar_t ch) {
    return static_cast<wchar_t>(std::towlower(static_cast<wint_t>(ch)));
  });
  return value;
}

bool StartsWithWide(const std::wstring& value, const std::wstring& prefix) {
  return value.size() >= prefix.size() &&
         value.compare(0, prefix.size(), prefix) == 0;
}

bool EndsWithWide(const std::wstring& value, const std::wstring& suffix) {
  return value.size() >= suffix.size() &&
         value.compare(value.size() - suffix.size(), suffix.size(), suffix) == 0;
}

std::wstring ExtractBaseName(const std::wstring& path_lower) {
  const size_t pos = path_lower.find_last_of(L'\\');
  if (pos == std::wstring::npos) {
    return path_lower;
  }
  return path_lower.substr(pos + 1);
}

std::wstring ExtractParentDir(const std::wstring& path_lower) {
  const size_t pos = path_lower.find_last_of(L'\\');
  if (pos == std::wstring::npos) {
    return std::wstring();
  }
  return path_lower.substr(0, pos);
}

bool IsPythonExecutableName(const std::wstring& base_lower) {
  return base_lower == L"python.exe" || base_lower == L"pythonw.exe" ||
         base_lower == L"python3.exe";
}

bool IsExecutablePathMatchWide(const std::wstring& actual_path,
                               const std::wstring& expected_executable) {
  if (actual_path.empty() || expected_executable.empty()) {
    return false;
  }
  const std::wstring actual_lower = NormalizeWindowsPathLower(actual_path);
  const std::wstring expected_lower = NormalizeWindowsPathLower(expected_executable);
  const std::wstring actual_base = ExtractBaseName(actual_lower);
  const std::wstring expected_base = ExtractBaseName(expected_lower);

  if (expected_lower.find(L'\\') == std::wstring::npos) {
    if (actual_base == expected_lower) {
      return true;
    }
    return IsPythonExecutableName(actual_base) && IsPythonExecutableName(expected_lower);
  }

  if (actual_lower == expected_lower) {
    return true;
  }
  if (IsPythonExecutableName(actual_base) && IsPythonExecutableName(expected_base)) {
    const std::wstring actual_dir = ExtractParentDir(actual_lower);
    const std::wstring expected_dir = ExtractParentDir(expected_lower);
    if (!actual_dir.empty() && actual_dir == expected_dir) {
      return true;
    }
  }
  if (actual_base != expected_base) {
    return false;
  }
  return EndsWithWide(actual_lower, expected_lower);
}

bool QueryProcessImagePath(HANDLE process_handle, std::wstring* out_path) {
  DWORD capacity = 1024;
  for (int attempt = 0; attempt < 2; ++attempt) {
    std::wstring buf(capacity, L'\0');
    DWORD len = capacity;
    if (QueryFullProcessImageNameW(process_handle, 0, buf.data(), &len)) {
      buf.resize(len);
      *out_path = std::move(buf);
      return true;
    }
    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
      return false;
    }
    capacity = 32768;
  }
  return false;
}

bool QueryProcessCreationIsoUtc(HANDLE process_handle, std::string* out_iso) {
  FILETIME create_ft{};
  FILETIME exit_ft{};
  FILETIME kernel_ft{};
  FILETIME user_ft{};
  if (!GetProcessTimes(process_handle, &create_ft, &exit_ft, &kernel_ft, &user_ft)) {
    return false;
  }
  SYSTEMTIME st{};
  if (!FileTimeToSystemTime(&create_ft, &st)) {
    return false;
  }
  char iso_buf[40] = {};
  std::snprintf(
      iso_buf,
      sizeof(iso_buf),
      "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ",
      static_cast<unsigned>(st.wYear),
      static_cast<unsigned>(st.wMonth),
      static_cast<unsigned>(st.wDay),
      static_cast<unsigned>(st.wHour),
      static_cast<unsigned>(st.wMinute),
      static_cast<unsigned>(st.wSecond),
      static_cast<unsigned>(st.wMilliseconds));
  *out_iso = iso_buf;
  return true;
}

using NtQueryInformationProcessFn = LONG(WINAPI*)(
    HANDLE ProcessHandle,
    PROCESSINFOCLASS ProcessInformationClass,
    PVOID ProcessInformation,
    ULONG ProcessInformationLength,
    PULONG ReturnLength);

bool ReadRemoteProcessCommandLine(HANDLE process_handle,
                                  NtQueryInformationProcessFn nt_query_proc,
                                  std::string* out_command_line) {
  static_assert(sizeof(void*) == 8, "x64 Windows runner required");
  static_assert(sizeof(UNICODE_STRING) == 16, "Expected x64 UNICODE_STRING size");

  if (nt_query_proc == nullptr) {
    return false;
  }

  PROCESS_BASIC_INFORMATION pbi{};
  ULONG return_len = 0;
  const LONG status = nt_query_proc(
      process_handle,
      ProcessBasicInformation,
      &pbi,
      static_cast<ULONG>(sizeof(pbi)),
      &return_len);
  if (status < 0 || pbi.PebBaseAddress == nullptr) {
    return false;
  }

  constexpr uintptr_t kPebProcessParametersOffsetX64 = 0x20;
  constexpr uintptr_t kParamsCommandLineOffsetX64 = 0x70;
  constexpr USHORT kMaxCommandLineBytes = 16384;

  uint64_t params_addr = 0;
  SIZE_T bytes_read = 0;
  const LPCVOID peb_params_ptr = reinterpret_cast<LPCVOID>(
      reinterpret_cast<uintptr_t>(pbi.PebBaseAddress) + kPebProcessParametersOffsetX64);
  if (!ReadProcessMemory(process_handle, peb_params_ptr, &params_addr,
                         sizeof(params_addr), &bytes_read) ||
      bytes_read != sizeof(params_addr) || params_addr == 0) {
    return false;
  }

  UNICODE_STRING cmd_str{};
  bytes_read = 0;
  const LPCVOID cmd_struct_ptr = reinterpret_cast<LPCVOID>(
      static_cast<uintptr_t>(params_addr) + kParamsCommandLineOffsetX64);
  if (!ReadProcessMemory(process_handle, cmd_struct_ptr, &cmd_str,
                         sizeof(cmd_str), &bytes_read) ||
      bytes_read != sizeof(cmd_str)) {
    return false;
  }

  if ((cmd_str.Length % sizeof(wchar_t)) != 0 || cmd_str.Length > kMaxCommandLineBytes) {
    return false;
  }
  if (cmd_str.Length == 0) {
    out_command_line->clear();
    return true;
  }
  if (cmd_str.Buffer == nullptr) {
    return false;
  }

  const size_t wchar_count = static_cast<size_t>(cmd_str.Length) / sizeof(wchar_t);
  std::vector<wchar_t> cmd_buf(wchar_count + 1, L'\0');
  bytes_read = 0;
  if (!ReadProcessMemory(process_handle, cmd_str.Buffer, cmd_buf.data(),
                         cmd_str.Length, &bytes_read) ||
      bytes_read != cmd_str.Length) {
    return false;
  }

  *out_command_line = WideToUtf8(cmd_buf.data());
  return true;
}

bool MatchesTargetProcessPrefix(const std::wstring& process_exe_name_lower,
                                const std::wstring& target_base_lower) {
  if (target_base_lower.empty()) {
    return false;
  }
  if (IsPythonExecutableName(target_base_lower)) {
    return StartsWithWide(process_exe_name_lower, L"python");
  }
  std::wstring stem = target_base_lower;
  if (EndsWithWide(stem, L".exe")) {
    stem.resize(stem.size() - 4);
  }
  if (stem.empty()) {
    return false;
  }
  return StartsWithWide(process_exe_name_lower, stem);
}

flutter::EncodableValue BuildNeedsFallbackResult() {
  flutter::EncodableMap map;
  map[flutter::EncodableValue("needsFallback")] = flutter::EncodableValue(true);
  return flutter::EncodableValue(map);
}

}  // namespace

WindowsShellChannel::WindowsShellChannel(flutter::BinaryMessenger* messenger, HWND hwnd)
    : hwnd_(hwnd) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
}

WindowsShellChannel::~WindowsShellChannel() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }
}

void WindowsShellChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableMap args;
  if (method_call.arguments() != nullptr) {
    if (const auto* map = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
      args = *map;
    }
  }

  if (method_call.method_name() == "isProcessAliveAndMatching") {
    int64_t pid_val = 0;
    const std::string expected_utf8 = ReadStringArg(args, "expectedExecutable");
    if (!ReadInt64Arg(args, "pid", &pid_val) || pid_val <= 0 ||
        pid_val > static_cast<int64_t>(MAXDWORD) || expected_utf8.empty()) {
      result->Success(flutter::EncodableValue(false));
      return;
    }

    ScopedHandle proc(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                                  static_cast<DWORD>(pid_val)));
    if (!proc.valid()) {
      if (GetLastError() == ERROR_INVALID_PARAMETER) {
        result->Success(flutter::EncodableValue(false));
      } else {
        // Access denied or indeterminate error: let Dart fall back safely.
        result->Success(flutter::EncodableValue());
      }
      return;
    }

    DWORD exit_code = 0;
    if (!GetExitCodeProcess(proc.handle, &exit_code)) {
      result->Success(flutter::EncodableValue());
      return;
    }
    if (exit_code != STILL_ACTIVE) {
      result->Success(flutter::EncodableValue(false));
      return;
    }

    std::wstring actual_path;
    if (!QueryProcessImagePath(proc.handle, &actual_path)) {
      if (GetExitCodeProcess(proc.handle, &exit_code) && exit_code != STILL_ACTIVE) {
        result->Success(flutter::EncodableValue(false));
      } else {
        result->Success(flutter::EncodableValue());
      }
      return;
    }

    const bool matched = IsExecutablePathMatchWide(actual_path, Utf8ToWide(expected_utf8));
    result->Success(flutter::EncodableValue(matched));
    return;
  }

  if (method_call.method_name() == "discoverCandidateProcesses") {
    static_assert(sizeof(void*) == 8, "x64 Windows runner required");
    const std::string target_base_utf8 = ReadStringArg(args, "targetExecutableBase");
    const std::wstring target_base_lower =
        ExtractBaseName(NormalizeWindowsPathLower(Utf8ToWide(target_base_utf8)));
    if (target_base_lower.empty()) {
      result->Success(BuildNeedsFallbackResult());
      return;
    }

    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    NtQueryInformationProcessFn nt_query_proc = nullptr;
    if (ntdll != nullptr) {
      nt_query_proc = reinterpret_cast<NtQueryInformationProcessFn>(
          GetProcAddress(ntdll, "NtQueryInformationProcess"));
    }
    if (nt_query_proc == nullptr) {
      result->Success(BuildNeedsFallbackResult());
      return;
    }

    ScopedHandle snapshot(CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0));
    if (!snapshot.valid()) {
      result->Success(BuildNeedsFallbackResult());
      return;
    }

    PROCESSENTRY32W entry{};
    entry.dwSize = sizeof(entry);
    if (!Process32FirstW(snapshot.handle, &entry)) {
      result->Success(BuildNeedsFallbackResult());
      return;
    }

    const DWORD current_pid = GetCurrentProcessId();
    flutter::EncodableList candidates;
    do {
      if (entry.th32ProcessID == 0 || entry.th32ProcessID == current_pid) {
        continue;
      }
      const std::wstring exe_name_lower = NormalizeWindowsPathLower(entry.szExeFile);
      if (!MatchesTargetProcessPrefix(exe_name_lower, target_base_lower)) {
        continue;
      }

      ScopedHandle proc(OpenProcess(
          PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ,
          FALSE,
          entry.th32ProcessID));
      if (!proc.valid()) {
        if (GetLastError() == ERROR_INVALID_PARAMETER) {
          continue;  // Exited mid-snapshot; ignore safely.
        }
        result->Success(BuildNeedsFallbackResult());
        return;
      }

      BOOL is_wow64 = FALSE;
      if (!IsWow64Process(proc.handle, &is_wow64) || is_wow64) {
        result->Success(BuildNeedsFallbackResult());
        return;
      }

      DWORD exit_code = 0;
      if (GetExitCodeProcess(proc.handle, &exit_code) && exit_code != STILL_ACTIVE) {
        continue;
      }

      std::wstring actual_path;
      std::string creation_iso;
      std::string command_line;
      if (!QueryProcessImagePath(proc.handle, &actual_path) ||
          !QueryProcessCreationIsoUtc(proc.handle, &creation_iso) ||
          !ReadRemoteProcessCommandLine(proc.handle, nt_query_proc, &command_line)) {
        if (GetExitCodeProcess(proc.handle, &exit_code) && exit_code != STILL_ACTIVE) {
          continue;
        }
        result->Success(BuildNeedsFallbackResult());
        return;
      }

      flutter::EncodableMap cand_map;
      cand_map[flutter::EncodableValue("pid")] =
          flutter::EncodableValue(static_cast<int64_t>(entry.th32ProcessID));
      cand_map[flutter::EncodableValue("executablePath")] =
          flutter::EncodableValue(WideToUtf8(actual_path.c_str()));
      cand_map[flutter::EncodableValue("commandLine")] =
          flutter::EncodableValue(command_line);
      cand_map[flutter::EncodableValue("creationDate")] =
          flutter::EncodableValue(creation_iso);
      candidates.push_back(flutter::EncodableValue(cand_map));
    } while (Process32NextW(snapshot.handle, &entry));

    flutter::EncodableMap out;
    out[flutter::EncodableValue("needsFallback")] = flutter::EncodableValue(false);
    out[flutter::EncodableValue("candidates")] = flutter::EncodableValue(candidates);
    result->Success(flutter::EncodableValue(out));
    return;
  }

  if (method_call.method_name() == "pickFolder") {
    ScopedComInit com;
    if (!com.ok()) {
      result->Error("COM_INIT_FAILED", "Failed to initialize COM for Windows shell dialog.");
      return;
    }

    Microsoft::WRL::ComPtr<IFileOpenDialog> dialog;
    HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&dialog));
    if (FAILED(hr) || !dialog) {
      result->Error("DIALOG_CREATE_FAILED", "Could not open Windows folder picker.");
      return;
    }

    DWORD options = 0;
    if (SUCCEEDED(dialog->GetOptions(&options))) {
      dialog->SetOptions(options | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
    }

    const std::string title = ReadStringArg(args, "title");
    if (!title.empty()) {
      dialog->SetTitle(Utf8ToWide(title).c_str());
    }
    ApplyInitialDirectory(dialog.Get(), ReadStringArg(args, "initialDirectory"));

    hr = dialog->Show(hwnd_);
    if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
      result->Success(flutter::EncodableValue());
      return;
    }
    if (FAILED(hr)) {
      result->Error("DIALOG_SHOW_FAILED", "Failed to display Windows folder picker.");
      return;
    }

    Microsoft::WRL::ComPtr<IShellItem> item;
    hr = dialog->GetResult(&item);
    if (FAILED(hr) || !item) {
      result->Success(flutter::EncodableValue());
      return;
    }

    wchar_t* path_ptr = nullptr;
    hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path_ptr);
    if (FAILED(hr) || path_ptr == nullptr) {
      result->Success(flutter::EncodableValue());
      return;
    }
    std::string utf8_path = WideToUtf8(path_ptr);
    CoTaskMemFree(path_ptr);
    result->Success(flutter::EncodableValue(utf8_path));
    return;
  }

  if (method_call.method_name() == "pickFiles") {
    ScopedComInit com;
    if (!com.ok()) {
      result->Error("COM_INIT_FAILED", "Failed to initialize COM for Windows shell dialog.");
      return;
    }

    Microsoft::WRL::ComPtr<IFileOpenDialog> dialog;
    HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&dialog));
    if (FAILED(hr) || !dialog) {
      result->Error("DIALOG_CREATE_FAILED", "Could not open Windows file picker.");
      return;
    }

    const bool allow_multiple = ReadBoolArg(args, "allowMultiple", true);
    DWORD options = 0;
    if (SUCCEEDED(dialog->GetOptions(&options))) {
      DWORD next = options | FOS_FORCEFILESYSTEM | FOS_FILEMUSTEXIST;
      if (allow_multiple) {
        next |= FOS_ALLOWMULTISELECT;
      }
      dialog->SetOptions(next);
    }

    const std::string filter_preset = ReadStringArg(args, "filterPreset");
    if (filter_preset == "executables") {
      const COMDLG_FILTERSPEC exe_filters[] = {
          {L"Windows Executables (*.exe)", L"*.exe"},
          {L"All Files (*.*)", L"*.*"},
      };
      dialog->SetFileTypes(static_cast<UINT>(sizeof(exe_filters) / sizeof(exe_filters[0])), exe_filters);
      dialog->SetFileTypeIndex(1);
    } else {
      const COMDLG_FILTERSPEC model_filters[] = {
          {L"GGUF Model Files (*.gguf)", L"*.gguf"},
          {L"All AI Model Files (*.gguf;*.safetensors;*.onnx;*.bin;*.pt;*.pth;*.pkl)",
           L"*.gguf;*.safetensors;*.onnx;*.bin;*.pt;*.pth;*.pkl"},
          {L"All Files (*.*)", L"*.*"},
      };
      dialog->SetFileTypes(static_cast<UINT>(sizeof(model_filters) / sizeof(model_filters[0])), model_filters);
      dialog->SetFileTypeIndex(2);
    }

    const std::string title = ReadStringArg(args, "title");
    if (!title.empty()) {
      dialog->SetTitle(Utf8ToWide(title).c_str());
    }
    ApplyInitialDirectory(dialog.Get(), ReadStringArg(args, "initialDirectory"));

    hr = dialog->Show(hwnd_);
    if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
      result->Success(flutter::EncodableValue(flutter::EncodableList{}));
      return;
    }
    if (FAILED(hr)) {
      result->Error("DIALOG_SHOW_FAILED", "Failed to display Windows file picker.");
      return;
    }

    Microsoft::WRL::ComPtr<IShellItemArray> items;
    hr = dialog->GetResults(&items);
    if (FAILED(hr) || !items) {
      result->Success(flutter::EncodableValue(flutter::EncodableList{}));
      return;
    }

    DWORD count = 0;
    items->GetCount(&count);
    flutter::EncodableList out;
    for (DWORD i = 0; i < count; ++i) {
      Microsoft::WRL::ComPtr<IShellItem> item;
      if (FAILED(items->GetItemAt(i, &item)) || !item) {
        continue;
      }
      wchar_t* path_ptr = nullptr;
      if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path_ptr)) &&
          path_ptr != nullptr) {
        std::string utf8_path = WideToUtf8(path_ptr);
        CoTaskMemFree(path_ptr);
        if (!utf8_path.empty()) {
          out.push_back(flutter::EncodableValue(utf8_path));
        }
      }
    }
    result->Success(flutter::EncodableValue(out));
    return;
  }

  result->NotImplemented();
}
