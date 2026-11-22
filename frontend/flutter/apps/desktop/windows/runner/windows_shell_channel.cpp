#include "windows_shell_channel.h"

#include <shobjidl.h>
#include <wrl/client.h>

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

  ScopedComInit com;
  if (!com.ok()) {
    result->Error("COM_INIT_FAILED", "Failed to initialize COM for Windows shell dialog.");
    return;
  }

  if (method_call.method_name() == "pickFolder") {
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

    const COMDLG_FILTERSPEC filters[] = {
        {L"GGUF Model Files (*.gguf)", L"*.gguf"},
        {L"All AI Model Files (*.gguf;*.safetensors;*.onnx;*.bin;*.pt;*.pth;*.pkl)",
         L"*.gguf;*.safetensors;*.onnx;*.bin;*.pt;*.pth;*.pkl"},
        {L"All Files (*.*)", L"*.*"},
    };
    dialog->SetFileTypes(static_cast<UINT>(sizeof(filters) / sizeof(filters[0])), filters);
    dialog->SetFileTypeIndex(2);

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
