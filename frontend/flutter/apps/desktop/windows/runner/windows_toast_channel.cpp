#include "windows_toast_channel.h"

#include <flutter/standard_method_codec.h>
#include <roapi.h>
#include <shobjidl.h>
#include <windows.data.xml.dom.h>
#include <winstring.h>

#include <atomic>
#include <utility>

namespace {

constexpr size_t kMaxRetainedToastRefs = 64;
constexpr size_t kMaxToastTagLength = 60;

class ScopedHString {
 public:
  ScopedHString() = default;
  explicit ScopedHString(const std::wstring& value) { Assign(value); }

  ~ScopedHString() { Reset(); }

  ScopedHString(const ScopedHString&) = delete;
  ScopedHString& operator=(const ScopedHString&) = delete;

  HRESULT Assign(const std::wstring& value) {
    Reset();
    return ::WindowsCreateString(
        value.c_str(), static_cast<UINT32>(value.length()), &value_);
  }

  void Reset() {
    if (value_ != nullptr) {
      ::WindowsDeleteString(value_);
      value_ = nullptr;
    }
  }

  HSTRING Get() const { return value_; }

 private:
  HSTRING value_ = nullptr;
};

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return L"";
  }
  const int required = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (required <= 0) {
    return L"";
  }
  std::wstring wide(static_cast<size_t>(required), L'\0');
  ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), wide.data(),
      required);
  return wide;
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return "";
  }
  const int required = ::WideCharToMultiByte(
      CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()), nullptr, 0,
      nullptr, nullptr);
  if (required <= 0) {
    return "";
  }
  std::string utf8(static_cast<size_t>(required), '\0');
  ::WideCharToMultiByte(
      CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()), utf8.data(),
      required, nullptr, nullptr);
  return utf8;
}

std::wstring ClampTag(const std::wstring& tag) {
  if (tag.length() <= kMaxToastTagLength) {
    return tag;
  }
  return tag.substr(0, kMaxToastTagLength);
}

using ToastActivatedHandlerInterface =
    __FITypedEventHandler_2_Windows__CUI__CNotifications__CToastNotification_IInspectable;

class ToastActivatedHandler final : public ToastActivatedHandlerInterface {
 public:
  explicit ToastActivatedHandler(HWND hwnd) : hwnd_(hwnd) {}

  IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (ppv == nullptr) {
      return E_POINTER;
    }
    if (riid == IID_IUnknown || riid == IID_IAgileObject ||
        riid == __uuidof(ToastActivatedHandlerInterface)) {
      *ppv = static_cast<ToastActivatedHandlerInterface*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  IFACEMETHODIMP_(ULONG) AddRef() override {
    return static_cast<ULONG>(ref_count_.fetch_add(1, std::memory_order_relaxed) + 1);
  }

  IFACEMETHODIMP_(ULONG) Release() override {
    const ULONG next =
        static_cast<ULONG>(ref_count_.fetch_sub(1, std::memory_order_acq_rel) - 1);
    if (next == 0) {
      delete this;
    }
    return next;
  }

  IFACEMETHODIMP Invoke(
      ABI::Windows::UI::Notifications::IToastNotification* /*sender*/,
      IInspectable* args) override {
    if (hwnd_ == nullptr || !::IsWindow(hwnd_)) {
      return S_OK;
    }

    std::wstring arguments_text;
    if (args != nullptr) {
      Microsoft::WRL::ComPtr<
          ABI::Windows::UI::Notifications::IToastActivatedEventArgs>
          activated_args;
      if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&activated_args))) &&
          activated_args != nullptr) {
        HSTRING raw_args = nullptr;
        if (SUCCEEDED(activated_args->get_Arguments(&raw_args)) &&
            raw_args != nullptr) {
          UINT32 len = 0;
          const wchar_t* buf = ::WindowsGetStringRawBuffer(raw_args, &len);
          if (buf != nullptr && len > 0) {
            arguments_text.assign(buf, len);
          }
          ::WindowsDeleteString(raw_args);
        }
      }
    }

    auto payload = std::make_unique<std::wstring>(std::move(arguments_text));
    if (::PostMessageW(hwnd_, kWmToastActivated, 0,
                       reinterpret_cast<LPARAM>(payload.get()))) {
      payload.release();
    }
    return S_OK;
  }

 private:
  ~ToastActivatedHandler() = default;

  HWND hwnd_;
  std::atomic<LONG> ref_count_{1};
};

}  // namespace

WindowsToastChannel::WindowsToastChannel(flutter::BinaryMessenger* messenger,
                                         HWND hwnd)
    : hwnd_(hwnd) {
  EnsureAumidRegistered();

  if (messenger != nullptr) {
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler(
        [this](const auto& call, auto result) {
          HandleMethodCall(call, std::move(result));
        });
  }
}

WindowsToastChannel::~WindowsToastChannel() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
  }
  for (auto& kv : active_toasts_) {
    if (kv.second.toast != nullptr && kv.second.activated_token.value != 0) {
      kv.second.toast->remove_Activated(kv.second.activated_token);
    }
  }
  active_toasts_.clear();
}

void WindowsToastChannel::EnsureAumidRegistered() {
  std::wstring subkey = L"Software\\Classes\\AppUserModelId\\";
  subkey += kAppUserModelId;

  HKEY key = nullptr;
  const LONG open_res = ::RegCreateKeyExW(
      HKEY_CURRENT_USER, subkey.c_str(), 0, nullptr, REG_OPTION_NON_VOLATILE,
      KEY_WRITE, nullptr, &key, nullptr);
  if (open_res != ERROR_SUCCESS || key == nullptr) {
    return;
  }

  const DWORD byte_len =
      static_cast<DWORD>((wcslen(kAppDisplayName) + 1) * sizeof(wchar_t));
  ::RegSetValueExW(key, L"DisplayName", 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(kAppDisplayName), byte_len);
  ::RegCloseKey(key);
}

void WindowsToastChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (method_call.method_name() == "showToast") {
    if (args == nullptr) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    std::string tag;
    std::string group = "ai_companion_alerts";
    std::string xml;
    bool suppress_popup = false;

    const auto tag_it = args->find(flutter::EncodableValue("tag"));
    if (tag_it != args->end()) {
      if (const auto* val = std::get_if<std::string>(&tag_it->second)) {
        tag = *val;
      }
    }
    const auto group_it = args->find(flutter::EncodableValue("group"));
    if (group_it != args->end()) {
      if (const auto* val = std::get_if<std::string>(&group_it->second)) {
        if (!val->empty()) {
          group = *val;
        }
      }
    }
    const auto xml_it = args->find(flutter::EncodableValue("xml"));
    if (xml_it != args->end()) {
      if (const auto* val = std::get_if<std::string>(&xml_it->second)) {
        xml = *val;
      }
    }
    const auto sup_it = args->find(flutter::EncodableValue("suppressPopup"));
    if (sup_it != args->end()) {
      if (const auto* val = std::get_if<bool>(&sup_it->second)) {
        suppress_popup = *val;
      }
    }

    if (xml.empty()) {
      result->Success(flutter::EncodableValue(false));
      return;
    }

    const bool ok = ShowToast(ClampTag(Utf8ToWide(tag)), Utf8ToWide(group),
                              Utf8ToWide(xml), suppress_popup);
    result->Success(flutter::EncodableValue(ok));
    return;
  }

  if (method_call.method_name() == "removeToast") {
    if (args == nullptr) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    std::string tag;
    std::string group = "ai_companion_alerts";
    const auto tag_it = args->find(flutter::EncodableValue("tag"));
    if (tag_it != args->end()) {
      if (const auto* val = std::get_if<std::string>(&tag_it->second)) {
        tag = *val;
      }
    }
    const auto group_it = args->find(flutter::EncodableValue("group"));
    if (group_it != args->end()) {
      if (const auto* val = std::get_if<std::string>(&group_it->second)) {
        if (!val->empty()) {
          group = *val;
        }
      }
    }
    if (tag.empty()) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    const bool ok = RemoveToast(ClampTag(Utf8ToWide(tag)), Utf8ToWide(group));
    result->Success(flutter::EncodableValue(ok));
    return;
  }

  if (method_call.method_name() == "clearToasts") {
    std::string group = "ai_companion_alerts";
    if (args != nullptr) {
      const auto group_it = args->find(flutter::EncodableValue("group"));
      if (group_it != args->end()) {
        if (const auto* val = std::get_if<std::string>(&group_it->second)) {
          if (!val->empty()) {
            group = *val;
          }
        }
      }
    }
    const bool ok = ClearToasts(Utf8ToWide(group));
    result->Success(flutter::EncodableValue(ok));
    return;
  }

  result->NotImplemented();
}

bool WindowsToastChannel::ShowToast(const std::wstring& tag,
                                    const std::wstring& group,
                                    const std::wstring& xml,
                                    bool suppress_popup) {
  ScopedHString xml_doc_class(
      RuntimeClass_Windows_Data_Xml_Dom_XmlDocument);
  Microsoft::WRL::ComPtr<IInspectable> xml_inspectable;
  HRESULT hr = ::RoActivateInstance(xml_doc_class.Get(), &xml_inspectable);
  if (FAILED(hr) || xml_inspectable == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<ABI::Windows::Data::Xml::Dom::IXmlDocument> xml_doc;
  hr = xml_inspectable.As(&xml_doc);
  if (FAILED(hr) || xml_doc == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<ABI::Windows::Data::Xml::Dom::IXmlDocumentIO> xml_io;
  hr = xml_doc.As(&xml_io);
  if (FAILED(hr) || xml_io == nullptr) {
    return false;
  }

  ScopedHString xml_hstr(xml);
  hr = xml_io->LoadXml(xml_hstr.Get());
  if (FAILED(hr)) {
    return false;
  }

  ScopedHString toast_class(
      RuntimeClass_Windows_UI_Notifications_ToastNotification);
  Microsoft::WRL::ComPtr<
      ABI::Windows::UI::Notifications::IToastNotificationFactory>
      toast_factory;
  hr = ::RoGetActivationFactory(toast_class.Get(),
                                IID_PPV_ARGS(&toast_factory));
  if (FAILED(hr) || toast_factory == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<ABI::Windows::UI::Notifications::IToastNotification>
      toast;
  hr = toast_factory->CreateToastNotification(xml_doc.Get(), &toast);
  if (FAILED(hr) || toast == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<ABI::Windows::UI::Notifications::IToastNotification2>
      toast2;
  if (SUCCEEDED(toast.As(&toast2)) && toast2 != nullptr) {
    if (!tag.empty()) {
      ScopedHString tag_hstr(tag);
      toast2->put_Tag(tag_hstr.Get());
    }
    if (!group.empty()) {
      ScopedHString group_hstr(group);
      toast2->put_Group(group_hstr.Get());
    }
    if (suppress_popup) {
      toast2->put_SuppressPopup(TRUE);
    }
  }

  Microsoft::WRL::ComPtr<ToastActivatedHandler> handler;
  handler.Attach(new ToastActivatedHandler(hwnd_));
  EventRegistrationToken token{};
  toast->add_Activated(handler.Get(), &token);

  if (!tag.empty()) {
    const auto existing = active_toasts_.find(tag);
    if (existing != active_toasts_.end()) {
      if (existing->second.toast != nullptr &&
          existing->second.activated_token.value != 0) {
        existing->second.toast->remove_Activated(
            existing->second.activated_token);
      }
      active_toasts_.erase(existing);
    } else if (active_toasts_.size() >= kMaxRetainedToastRefs) {
      auto oldest = active_toasts_.begin();
      if (oldest->second.toast != nullptr &&
          oldest->second.activated_token.value != 0) {
        oldest->second.toast->remove_Activated(oldest->second.activated_token);
      }
      active_toasts_.erase(oldest);
    }
    active_toasts_.emplace(tag, ActiveToastEntry{toast, token});
  }

  ScopedHString mgr_class(
      RuntimeClass_Windows_UI_Notifications_ToastNotificationManager);
  Microsoft::WRL::ComPtr<
      ABI::Windows::UI::Notifications::IToastNotificationManagerStatics>
      mgr_statics;
  hr = ::RoGetActivationFactory(mgr_class.Get(), IID_PPV_ARGS(&mgr_statics));
  if (FAILED(hr) || mgr_statics == nullptr) {
    return false;
  }

  ScopedHString aumid_hstr(kAppUserModelId);
  Microsoft::WRL::ComPtr<ABI::Windows::UI::Notifications::IToastNotifier>
      notifier;
  hr = mgr_statics->CreateToastNotifierWithId(aumid_hstr.Get(), &notifier);
  if (FAILED(hr) || notifier == nullptr) {
    return false;
  }

  hr = notifier->Show(toast.Get());
  return SUCCEEDED(hr);
}

bool WindowsToastChannel::RemoveToast(const std::wstring& tag,
                                      const std::wstring& group) {
  const auto existing = active_toasts_.find(tag);
  if (existing != active_toasts_.end()) {
    if (existing->second.toast != nullptr &&
        existing->second.activated_token.value != 0) {
      existing->second.toast->remove_Activated(existing->second.activated_token);
    }
    active_toasts_.erase(existing);
  }

  ScopedHString mgr_class(
      RuntimeClass_Windows_UI_Notifications_ToastNotificationManager);
  Microsoft::WRL::ComPtr<
      ABI::Windows::UI::Notifications::IToastNotificationManagerStatics2>
      mgr_statics2;
  HRESULT hr =
      ::RoGetActivationFactory(mgr_class.Get(), IID_PPV_ARGS(&mgr_statics2));
  if (FAILED(hr) || mgr_statics2 == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<
      ABI::Windows::UI::Notifications::IToastNotificationHistory>
      history;
  hr = mgr_statics2->get_History(&history);
  if (FAILED(hr) || history == nullptr) {
    return false;
  }

  ScopedHString tag_hstr(tag);
  ScopedHString group_hstr(group);
  ScopedHString aumid_hstr(kAppUserModelId);
  hr = history->RemoveGroupedTagWithId(tag_hstr.Get(), group_hstr.Get(),
                                       aumid_hstr.Get());
  return SUCCEEDED(hr);
}

bool WindowsToastChannel::ClearToasts(const std::wstring& group) {
  for (auto& kv : active_toasts_) {
    if (kv.second.toast != nullptr && kv.second.activated_token.value != 0) {
      kv.second.toast->remove_Activated(kv.second.activated_token);
    }
  }
  active_toasts_.clear();

  ScopedHString mgr_class(
      RuntimeClass_Windows_UI_Notifications_ToastNotificationManager);
  Microsoft::WRL::ComPtr<
      ABI::Windows::UI::Notifications::IToastNotificationManagerStatics2>
      mgr_statics2;
  HRESULT hr =
      ::RoGetActivationFactory(mgr_class.Get(), IID_PPV_ARGS(&mgr_statics2));
  if (FAILED(hr) || mgr_statics2 == nullptr) {
    return false;
  }

  Microsoft::WRL::ComPtr<
      ABI::Windows::UI::Notifications::IToastNotificationHistory>
      history;
  hr = mgr_statics2->get_History(&history);
  if (FAILED(hr) || history == nullptr) {
    return false;
  }

  ScopedHString group_hstr(group);
  ScopedHString aumid_hstr(kAppUserModelId);
  hr = history->RemoveGroupWithId(group_hstr.Get(), aumid_hstr.Get());
  return SUCCEEDED(hr);
}

void WindowsToastChannel::HandleToastActivatedMessage(WPARAM /*wparam*/,
                                                      LPARAM lparam) {
  std::unique_ptr<std::wstring> payload(
      reinterpret_cast<std::wstring*>(lparam));
  if (!channel_) {
    return;
  }

  const std::string args_utf8 =
      payload ? WideToUtf8(*payload) : std::string();

  const bool should_focus =
      args_utf8.empty() || args_utf8.find("action=open_") != std::string::npos;
  if (should_focus && hwnd_ != nullptr && ::IsWindow(hwnd_)) {
    if (::IsIconic(hwnd_)) {
      ::ShowWindow(hwnd_, SW_RESTORE);
    }
    ::SetForegroundWindow(hwnd_);
  }

  flutter::EncodableMap event_args;
  event_args[flutter::EncodableValue("arguments")] =
      flutter::EncodableValue(args_utf8);
  channel_->InvokeMethod(
      "onToastActivated",
      std::make_unique<flutter::EncodableValue>(std::move(event_args)));
}
