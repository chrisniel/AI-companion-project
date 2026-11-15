#include "windows_toast_channel.h"

#include <flutter/standard_method_codec.h>
#include <mmsystem.h>
#include <notificationactivationcallback.h>
#include <propkey.h>
#include <propvarutil.h>
#include <roapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <windows.data.xml.dom.h>
#include <windows.globalization.h>
#include <winstring.h>

#include <atomic>
#include <cwchar>
#include <utility>

namespace {

constexpr size_t kMaxRetainedToastRefs = 64;
constexpr size_t kMaxToastTagLength = 60;

// Deterministic COM CLSID for AI Companion Desktop's unpackaged WinRT
// INotificationActivationCallback local server:
// {7A4D8B91-3C2E-4F1A-9E6D-1B8C5A2D4F90}
constexpr CLSID kToastActivatorClsid = {
    0x7a4d8b91,
    0x3c2e,
    0x4f1a,
    {0x9e, 0x6d, 0x1b, 0x8c, 0x5a, 0x2d, 0x4f, 0x90}};
constexpr wchar_t kToastActivatorClsidStr[] =
    L"{7A4D8B91-3C2E-4F1A-9E6D-1B8C5A2D4F90}";

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

void PostActivationToWindow(HWND hwnd, std::wstring arguments_text) {
  if (hwnd == nullptr || !::IsWindow(hwnd)) {
    return;
  }
  auto payload = std::make_unique<std::wstring>(std::move(arguments_text));
  if (::PostMessageW(hwnd, kWmToastActivated, 0,
                     reinterpret_cast<LPARAM>(payload.get()))) {
    payload.release();
  }
}

std::wstring GetCurrentExePath() {
  std::wstring buffer(MAX_PATH, L'\0');
  for (;;) {
    const DWORD copied = ::GetModuleFileNameW(
        nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (copied == 0) {
      return L"";
    }
    if (copied < buffer.size() - 1) {
      buffer.resize(copied);
      return buffer;
    }
    if (buffer.size() > 32768) {
      return L"";
    }
    buffer.resize(buffer.size() * 2);
  }
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
    return static_cast<ULONG>(
        ref_count_.fetch_add(1, std::memory_order_relaxed) + 1);
  }

  IFACEMETHODIMP_(ULONG) Release() override {
    const ULONG next =
        static_cast<ULONG>(ref_count_.fetch_sub(1, std::memory_order_acq_rel) -
                           1);
    if (next == 0) {
      delete this;
    }
    return next;
  }

  IFACEMETHODIMP Invoke(
      ABI::Windows::UI::Notifications::IToastNotification* /*sender*/,
      IInspectable* args) override {
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

    PostActivationToWindow(hwnd_, std::move(arguments_text));
    return S_OK;
  }

 private:
  ~ToastActivatedHandler() = default;

  HWND hwnd_;
  std::atomic<LONG> ref_count_{1};
};

class ToastNotificationCallback final : public INotificationActivationCallback {
 public:
  explicit ToastNotificationCallback(HWND hwnd) : hwnd_(hwnd) {}

  IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (ppv == nullptr) {
      return E_POINTER;
    }
    if (riid == IID_IUnknown ||
        riid == __uuidof(INotificationActivationCallback)) {
      *ppv = static_cast<INotificationActivationCallback*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  IFACEMETHODIMP_(ULONG) AddRef() override {
    return static_cast<ULONG>(
        ref_count_.fetch_add(1, std::memory_order_relaxed) + 1);
  }

  IFACEMETHODIMP_(ULONG) Release() override {
    const ULONG next =
        static_cast<ULONG>(ref_count_.fetch_sub(1, std::memory_order_acq_rel) -
                           1);
    if (next == 0) {
      delete this;
    }
    return next;
  }

  IFACEMETHODIMP Activate(LPCWSTR /*appUserModelId*/,
                          LPCWSTR invokedArgs,
                          const NOTIFICATION_USER_INPUT_DATA* /*data*/,
                          ULONG /*count*/) override {
    std::wstring args = invokedArgs != nullptr ? invokedArgs : L"";
    PostActivationToWindow(hwnd_, std::move(args));
    return S_OK;
  }

 private:
  ~ToastNotificationCallback() = default;

  HWND hwnd_;
  std::atomic<LONG> ref_count_{1};
};

class ToastActivatorClassFactory final : public IClassFactory {
 public:
  explicit ToastActivatorClassFactory(HWND hwnd) : hwnd_(hwnd) {}

  IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (ppv == nullptr) {
      return E_POINTER;
    }
    if (riid == IID_IUnknown || riid == IID_IClassFactory) {
      *ppv = static_cast<IClassFactory*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  IFACEMETHODIMP_(ULONG) AddRef() override {
    return static_cast<ULONG>(
        ref_count_.fetch_add(1, std::memory_order_relaxed) + 1);
  }

  IFACEMETHODIMP_(ULONG) Release() override {
    const ULONG next =
        static_cast<ULONG>(ref_count_.fetch_sub(1, std::memory_order_acq_rel) -
                           1);
    if (next == 0) {
      delete this;
    }
    return next;
  }

  IFACEMETHODIMP CreateInstance(IUnknown* pUnkOuter,
                                REFIID riid,
                                void** ppv) override {
    if (pUnkOuter != nullptr) {
      return CLASS_E_NOAGGREGATION;
    }
    if (ppv == nullptr) {
      return E_POINTER;
    }
    Microsoft::WRL::ComPtr<ToastNotificationCallback> cb;
    cb.Attach(new ToastNotificationCallback(hwnd_));
    return cb->QueryInterface(riid, ppv);
  }

  IFACEMETHODIMP LockServer(BOOL /*fLock*/) override { return S_OK; }

 private:
  ~ToastActivatorClassFactory() = default;

  HWND hwnd_;
  std::atomic<LONG> ref_count_{1};
};

}  // namespace

WindowsToastChannel::WindowsToastChannel(flutter::BinaryMessenger* messenger,
                                         HWND hwnd)
    : hwnd_(hwnd) {
  EnsureAumidRegistered();
  EnsureStartMenuShortcut();
  RegisterComActivator();

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
  UnregisterComActivator();
  for (auto& kv : active_toasts_) {
    if (kv.second.toast != nullptr && kv.second.activated_token.value != 0) {
      kv.second.toast->remove_Activated(kv.second.activated_token);
    }
  }
  active_toasts_.clear();
}

void WindowsToastChannel::EnsureAumidRegistered() {
  const std::wstring exe_path = GetCurrentExePath();

  std::wstring subkey = L"Software\\Classes\\AppUserModelId\\";
  subkey += kAppUserModelId;
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, subkey.c_str(), 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &key,
                        nullptr) == ERROR_SUCCESS &&
      key != nullptr) {
    const DWORD display_bytes =
        static_cast<DWORD>((wcslen(kAppDisplayName) + 1) * sizeof(wchar_t));
    ::RegSetValueExW(key, L"DisplayName", 0, REG_SZ,
                     reinterpret_cast<const BYTE*>(kAppDisplayName),
                     display_bytes);
    const DWORD clsid_bytes =
        static_cast<DWORD>((wcslen(kToastActivatorClsidStr) + 1) *
                           sizeof(wchar_t));
    ::RegSetValueExW(key, L"CustomActivator", 0, REG_SZ,
                     reinterpret_cast<const BYTE*>(kToastActivatorClsidStr),
                     clsid_bytes);
    ::RegCloseKey(key);
  }

  if (!exe_path.empty()) {
    std::wstring clsid_key = L"Software\\Classes\\CLSID\\";
    clsid_key += kToastActivatorClsidStr;
    clsid_key += L"\\LocalServer32";
    HKEY server_key = nullptr;
    if (::RegCreateKeyExW(HKEY_CURRENT_USER, clsid_key.c_str(), 0, nullptr,
                          REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr,
                          &server_key, nullptr) == ERROR_SUCCESS &&
        server_key != nullptr) {
      std::wstring command = L"\"";
      command += exe_path;
      command += L"\" --toast-activated";
      const DWORD cmd_bytes =
          static_cast<DWORD>((command.length() + 1) * sizeof(wchar_t));
      ::RegSetValueExW(server_key, nullptr, 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(command.c_str()),
                       cmd_bytes);
      ::RegCloseKey(server_key);
    }
  }
}

void WindowsToastChannel::EnsureStartMenuShortcut() {
  const std::wstring exe_path = GetCurrentExePath();
  if (exe_path.empty()) {
    return;
  }

  PWSTR programs_dir = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_Programs, 0, nullptr,
                                    &programs_dir)) ||
      programs_dir == nullptr) {
    return;
  }

  std::wstring shortcut_path = programs_dir;
  ::CoTaskMemFree(programs_dir);
  if (!shortcut_path.empty() && shortcut_path.back() != L'\\') {
    shortcut_path += L'\\';
  }
  shortcut_path += L"AI Companion.lnk";

  std::wstring work_dir = exe_path;
  const size_t slash = work_dir.find_last_of(L"\\/");
  if (slash != std::wstring::npos) {
    work_dir.resize(slash);
  }

  Microsoft::WRL::ComPtr<IShellLinkW> shell_link;
  HRESULT hr = ::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&shell_link));
  if (FAILED(hr) || shell_link == nullptr) {
    return;
  }

  shell_link->SetPath(exe_path.c_str());
  if (!work_dir.empty()) {
    shell_link->SetWorkingDirectory(work_dir.c_str());
  }
  shell_link->SetIconLocation(exe_path.c_str(), 0);

  Microsoft::WRL::ComPtr<IPropertyStore> prop_store;
  if (SUCCEEDED(shell_link.As(&prop_store)) && prop_store != nullptr) {
    PROPVARIANT app_id_prop;
    ::PropVariantInit(&app_id_prop);
    if (SUCCEEDED(::InitPropVariantFromString(kAppUserModelId, &app_id_prop))) {
      prop_store->SetValue(PKEY_AppUserModel_ID, app_id_prop);
      ::PropVariantClear(&app_id_prop);
    }

    PROPVARIANT clsid_prop;
    ::PropVariantInit(&clsid_prop);
    if (SUCCEEDED(::InitPropVariantFromCLSID(kToastActivatorClsid,
                                             &clsid_prop))) {
      prop_store->SetValue(PKEY_AppUserModel_ToastActivatorCLSID, clsid_prop);
      ::PropVariantClear(&clsid_prop);
    }
    prop_store->Commit();
  }

  Microsoft::WRL::ComPtr<IPersistFile> persist_file;
  if (SUCCEEDED(shell_link.As(&persist_file)) && persist_file != nullptr) {
    persist_file->Save(shortcut_path.c_str(), TRUE);
  }
}

void WindowsToastChannel::RegisterComActivator() {
  if (com_cookie_ != 0) {
    return;
  }
  Microsoft::WRL::ComPtr<ToastActivatorClassFactory> factory;
  factory.Attach(new ToastActivatorClassFactory(hwnd_));
  DWORD cookie = 0;
  const HRESULT hr = ::CoRegisterClassObject(
      kToastActivatorClsid, factory.Get(), CLSCTX_LOCAL_SERVER,
      REGCLS_MULTIPLEUSE, &cookie);
  if (SUCCEEDED(hr)) {
    com_cookie_ = cookie;
  }
}

void WindowsToastChannel::UnregisterComActivator() {
  if (com_cookie_ != 0) {
    ::CoRevokeClassObject(com_cookie_);
    com_cookie_ = 0;
  }
}

void WindowsToastChannel::PlayAlertChime(bool is_alarm) {
  if (is_alarm) {
    if (!::PlaySoundW(L"Notification.Looping.Alarm", nullptr,
                      SND_ALIAS | SND_ASYNC | SND_NODEFAULT)) {
      if (!::PlaySoundW(L"Notification.Reminder", nullptr,
                        SND_ALIAS | SND_ASYNC | SND_NODEFAULT)) {
        ::PlaySoundW(L"SystemExclamation", nullptr,
                     SND_ALIAS | SND_ASYNC | SND_NODEFAULT);
      }
    }
    return;
  }
  if (!::PlaySoundW(L"Notification.Reminder", nullptr,
                    SND_ALIAS | SND_ASYNC | SND_NODEFAULT)) {
    if (!::PlaySoundW(L"Notification.Default", nullptr,
                      SND_ALIAS | SND_ASYNC | SND_NODEFAULT)) {
      ::PlaySoundW(L"SystemNotification", nullptr,
                   SND_ALIAS | SND_ASYNC | SND_NODEFAULT);
    }
  }
}

std::string WindowsToastChannel::QueryDeviceIanaTimezone() {
  ScopedHString cal_class(RuntimeClass_Windows_Globalization_Calendar);
  Microsoft::WRL::ComPtr<IInspectable> inspectable;
  if (FAILED(::RoActivateInstance(cal_class.Get(), &inspectable)) ||
      inspectable == nullptr) {
    return "";
  }
  Microsoft::WRL::ComPtr<ABI::Windows::Globalization::ITimeZoneOnCalendar>
      tz_cal;
  if (FAILED(inspectable.As(&tz_cal)) || tz_cal == nullptr) {
    return "";
  }
  HSTRING raw_tz = nullptr;
  if (FAILED(tz_cal->GetTimeZone(&raw_tz)) || raw_tz == nullptr) {
    return "";
  }
  UINT32 len = 0;
  const wchar_t* buf = ::WindowsGetStringRawBuffer(raw_tz, &len);
  std::wstring wide_tz = (buf != nullptr && len > 0) ? std::wstring(buf, len) : L"";
  ::WindowsDeleteString(raw_tz);
  return WideToUtf8(wide_tz);
}

void WindowsToastChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (method_call.method_name() == "getDeviceTimezone") {
    result->Success(flutter::EncodableValue(QueryDeviceIanaTimezone()));
    return;
  }

  if (method_call.method_name() == "isWindowFocused") {
    const HWND foreground = ::GetForegroundWindow();
    const bool is_focused =
        hwnd_ != nullptr &&
        ::IsWindowVisible(hwnd_) &&
        !::IsIconic(hwnd_) &&
        foreground != nullptr &&
        (foreground == hwnd_ || ::IsChild(hwnd_, foreground));
    result->Success(flutter::EncodableValue(is_focused));
    return;
  }

  if (method_call.method_name() == "playAlertSound") {
    bool is_alarm = false;
    if (args != nullptr) {
      const auto alarm_it = args->find(flutter::EncodableValue("isAlarm"));
      if (alarm_it != args->end()) {
        if (const auto* val = std::get_if<bool>(&alarm_it->second)) {
          is_alarm = *val;
        }
      }
    }
    PlayAlertChime(is_alarm);
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method_call.method_name() == "showToast") {
    if (args == nullptr) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    std::string tag;
    std::string group = "ai_companion_alerts";
    std::string xml;
    bool suppress_popup = false;
    bool play_sound = true;
    bool is_alarm = false;

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
    const auto snd_it = args->find(flutter::EncodableValue("playSound"));
    if (snd_it != args->end()) {
      if (const auto* val = std::get_if<bool>(&snd_it->second)) {
        play_sound = *val;
      }
    }
    const auto alm_it = args->find(flutter::EncodableValue("isAlarm"));
    if (alm_it != args->end()) {
      if (const auto* val = std::get_if<bool>(&alm_it->second)) {
        is_alarm = *val;
      }
    }

    if (xml.empty()) {
      result->Success(flutter::EncodableValue(false));
      return;
    }

    const bool ok = ShowToast(ClampTag(Utf8ToWide(tag)), Utf8ToWide(group),
                              Utf8ToWide(xml), suppress_popup, play_sound,
                              is_alarm);
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
                                    bool suppress_popup,
                                    bool play_sound,
                                    bool is_alarm) {
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

  // Only bind per-instance Activated handler when COM CustomActivator class
  // factory is unavailable; otherwise Windows routes all toast/Action Center
  // activations uniformly through INotificationActivationCallback without
  // firing duplicate events.
  if (com_cookie_ == 0) {
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
  if (SUCCEEDED(hr) && !suppress_popup && play_sound) {
    PlayAlertChime(is_alarm);
  }
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
