#ifndef RUNNER_WINDOWS_SHELL_CHANNEL_H_
#define RUNNER_WINDOWS_SHELL_CHANNEL_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

class WindowsShellChannel {
 public:
  static constexpr char kChannelName[] = "ai_companion/windows_shell";

  WindowsShellChannel(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~WindowsShellChannel();

  WindowsShellChannel(const WindowsShellChannel&) = delete;
  WindowsShellChannel& operator=(const WindowsShellChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND hwnd_;
};

#endif  // RUNNER_WINDOWS_SHELL_CHANNEL_H_
