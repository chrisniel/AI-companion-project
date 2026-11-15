#ifndef RUNNER_WINDOWS_TOAST_CHANNEL_H_
#define RUNNER_WINDOWS_TOAST_CHANNEL_H_

#include <windows.h>
#include <windows.ui.notifications.h>
#include <wrl/client.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <map>
#include <memory>
#include <string>

// Custom Win32 message posted from WinRT / COM background activation callbacks
// back to FlutterWindow's UI thread message loop. LPARAM owns a heap-allocated
// std::wstring* containing the query-encoded toast arguments.
constexpr UINT kWmToastActivated = WM_APP + 0x42;

class WindowsToastChannel {
 public:
  static constexpr wchar_t kAppUserModelId[] = L"AICompanion.Desktop";
  static constexpr wchar_t kAppDisplayName[] = L"AI Companion";
  static constexpr char kChannelName[] = "ai_companion/windows_notifications";

  WindowsToastChannel(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~WindowsToastChannel();

  WindowsToastChannel(const WindowsToastChannel&) = delete;
  WindowsToastChannel& operator=(const WindowsToastChannel&) = delete;

  // Dispatches a marshaled WinRT / COM Activated callback payload on UI thread.
  void HandleToastActivatedMessage(WPARAM wparam, LPARAM lparam);

 private:
  void EnsureAumidRegistered();
  void EnsureStartMenuShortcut();
  void RegisterComActivator();
  void UnregisterComActivator();
  void PlayAlertChime(bool is_alarm);
  std::string QueryDeviceIanaTimezone();

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool ShowToast(const std::wstring& tag,
                 const std::wstring& group,
                 const std::wstring& xml,
                 bool suppress_popup,
                 bool play_sound,
                 bool is_alarm);
  bool RemoveToast(const std::wstring& tag, const std::wstring& group);
  bool ClearToasts(const std::wstring& group);

  HWND hwnd_;
  DWORD com_cookie_ = 0;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  struct ActiveToastEntry {
    Microsoft::WRL::ComPtr<ABI::Windows::UI::Notifications::IToastNotification>
        toast;
    EventRegistrationToken activated_token{};
  };
  // Keep recently shown IToastNotification instances alive as a fallback when
  // COM LocalServer activation isn't bound, and unregister tokens on cleanup.
  std::map<std::wstring, ActiveToastEntry> active_toasts_;
};

#endif  // RUNNER_WINDOWS_TOAST_CHANNEL_H_
