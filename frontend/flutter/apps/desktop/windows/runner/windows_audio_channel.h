#ifndef RUNNER_WINDOWS_AUDIO_CHANNEL_H_
#define RUNNER_WINDOWS_AUDIO_CHANNEL_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

// Custom Win32 message posted when WASAPI capture worker has queued PCM16 frames
// to be dispatched cleanly on the Flutter UI thread.
constexpr UINT kWmAudioEvent = WM_APP + 0x43;
constexpr int kGlobalVoiceHotkeyId = 0xAC01;

class WindowsAudioChannel {
 public:
  static constexpr char kChannelName[] = "ai_companion/windows_audio";

  WindowsAudioChannel(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~WindowsAudioChannel();

  WindowsAudioChannel(const WindowsAudioChannel&) = delete;
  WindowsAudioChannel& operator=(const WindowsAudioChannel&) = delete;

  // Drains pending captured audio frames on the UI thread via MethodChannel.
  void HandleAudioEventMessage();

  // Dispatches WM_HOTKEY callbacks cleanly to Dart on the UI thread.
  void HandleHotkeyMessage(WPARAM wparam);

 private:
  struct CapturedFrame {
    std::vector<uint8_t> pcm16;
    double rms;
  };

  struct PlaybackItem {
    uint64_t generation;
    std::vector<int16_t> samples;
    uint32_t sample_rate;
    uint16_t channels;
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::EncodableList EnumerateDevices(bool capture);
  bool StartCapture(const std::wstring& device_id, std::string* err_out);
  void StopCapture();
  void CaptureWorker(std::wstring device_id);

  bool EnqueuePlayback(const std::vector<uint8_t>& raw_bytes,
                       const std::wstring& device_id,
                       uint32_t fallback_sample_rate,
                       uint64_t generation,
                       std::string* err_out);
  void FlushPlayback(uint64_t min_generation);
  void EnsureRenderThreadStarted(const std::wstring& device_id);
  void StopRenderThread();
  void RenderWorker(std::wstring device_id);

  HWND hwnd_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool hotkey_registered_ = false;

  // Capture thread & UI-marshaled queue
  std::mutex capture_mutex_;
  std::condition_variable capture_init_cv_;
  bool capture_init_done_{false};
  bool capture_init_ok_{false};
  std::string capture_init_error_;
  std::deque<CapturedFrame> capture_queue_;
  std::atomic<bool> capture_event_posted_{false};
  std::atomic<bool> capture_stop_requested_{false};
  std::thread capture_thread_;

  // Render thread & generation-fenced FIFO
  std::mutex render_mutex_;
  std::condition_variable render_cv_;
  std::deque<PlaybackItem> render_queue_;
  std::wstring active_render_device_;
  std::atomic<uint64_t> min_playback_generation_{0};
  std::atomic<bool> render_flush_requested_{false};
  std::atomic<bool> render_stop_requested_{false};
  std::atomic<bool> render_worker_alive_{false};
  std::thread render_thread_;
};

#endif  // RUNNER_WINDOWS_AUDIO_CHANNEL_H_
