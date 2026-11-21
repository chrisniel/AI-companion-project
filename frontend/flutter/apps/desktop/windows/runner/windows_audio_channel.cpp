#include "windows_audio_channel.h"

#include <audioclient.h>
#include <flutter/standard_method_codec.h>
#include <mmdeviceapi.h>
#include <propidl.h>
#include <propkey.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <utility>

using Microsoft::WRL::ComPtr;

namespace {

constexpr uint32_t kCaptureSampleRate = 16000;
constexpr uint16_t kCaptureChannels = 1;
constexpr uint16_t kCaptureBits = 16;
constexpr size_t kCaptureFrameSamples = 512;
constexpr size_t kCaptureFrameBytes = kCaptureFrameSamples * 2;
constexpr size_t kMaxCaptureQueueDepth = 64;
constexpr double kPi = 3.14159265358979323846;

const GUID kSubformatPcm = {
    0x00000001, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71}};
const GUID kSubformatIeeeFloat = {
    0x00000003, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71}};
// PKEY_Device_FriendlyName ({A45C254E-DF1C-4EFD-8020-67D146A850E0}, 14)
const PROPERTYKEY kPkeyDeviceFriendlyName = {
    {0xa45c254e, 0xdf1c, 0x4efd, {0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0}},
    14};

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return L"";
  const int required = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (required <= 0) return L"";
  std::wstring wide(static_cast<size_t>(required), L'\0');
  ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), wide.data(),
      required);
  return wide;
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return "";
  const int required = ::WideCharToMultiByte(
      CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()), nullptr, 0,
      nullptr, nullptr);
  if (required <= 0) return "";
  std::string utf8(static_cast<size_t>(required), '\0');
  ::WideCharToMultiByte(
      CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()), utf8.data(),
      required, nullptr, nullptr);
  return utf8;
}

// Reuses STA on the Flutter UI thread safely without triggering RPC_E_CHANGED_MODE
// and without calling CoUninitialize when apartment initialization was external.
class ScopedUiComGuard {
 public:
  ScopedUiComGuard() {
    const HRESULT hr = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    should_uninit_ = (hr == S_OK || hr == S_FALSE);
  }
  ~ScopedUiComGuard() {
    if (should_uninit_) {
      ::CoUninitialize();
    }
  }

 private:
  bool should_uninit_ = false;
};

// Dedicated MTA COM guard for WASAPI background worker threads.
class ScopedMtaComGuard {
 public:
  ScopedMtaComGuard() {
    const HRESULT hr = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    should_uninit_ = (hr == S_OK || hr == S_FALSE);
  }
  ~ScopedMtaComGuard() {
    if (should_uninit_) {
      ::CoUninitialize();
    }
  }

 private:
  bool should_uninit_ = false;
};

template <typename T>
T ReadLe(const uint8_t* ptr) {
  T val{};
  std::memcpy(&val, ptr, sizeof(T));
  return val;
}

double ComputePcm16Rms(const int16_t* samples, size_t count) {
  if (!samples || count == 0) return 0.0;
  double sum_sq = 0.0;
  for (size_t i = 0; i < count; ++i) {
    const double v = static_cast<double>(samples[i]);
    sum_sq += v * v;
  }
  const double rms = std::sqrt(sum_sq / static_cast<double>(count)) / 32768.0;
  return (std::min)(1.0, (std::max)(0.0, rms));
}

// Resamples interleaved PCM16 to mono/stereo target sample rate via linear interpolation.
std::vector<int16_t> ConvertAndResamplePcm16(
    const std::vector<int16_t>& src,
    uint32_t src_rate,
    uint16_t src_channels,
    uint32_t dst_rate,
    uint16_t dst_channels) {
  if (src.empty() || src_rate == 0 || src_channels == 0 || dst_rate == 0 ||
      dst_channels == 0) {
    return {};
  }
  const size_t src_frames = src.size() / src_channels;
  if (src_frames == 0) return {};

  auto sample_mono_at = [&](size_t frame_idx) -> double {
    double acc = 0.0;
    for (uint16_t c = 0; c < src_channels; ++c) {
      acc += static_cast<double>(src[frame_idx * src_channels + c]);
    }
    return acc / static_cast<double>(src_channels);
  };

  if (src_rate == dst_rate && src_channels == dst_channels) {
    return src;
  }

  const double ratio = static_cast<double>(dst_rate) / static_cast<double>(src_rate);
  const size_t dst_frames = (std::max)(
      size_t{1}, static_cast<size_t>(std::llround(static_cast<double>(src_frames) * ratio)));
  std::vector<int16_t> out(dst_frames * dst_channels, 0);

  for (size_t df = 0; df < dst_frames; ++df) {
    const double src_pos =
        (static_cast<double>(df) * static_cast<double>(src_rate)) /
        static_cast<double>(dst_rate);
    const size_t i0 = (std::min)(src_frames - 1, static_cast<size_t>(src_pos));
    const size_t i1 = (std::min)(src_frames - 1, i0 + 1);
    const double frac = src_pos - static_cast<double>(i0);
    const double interp = sample_mono_at(i0) * (1.0 - frac) + sample_mono_at(i1) * frac;
    const int clamped = static_cast<int>(
        (std::max)(-32768LL, (std::min)(32767LL, std::llround(interp))));
    for (uint16_t dc = 0; dc < dst_channels; ++dc) {
      out[df * dst_channels + dc] = static_cast<int16_t>(clamped);
    }
  }
  return out;
}

// Dynamic RIFF subchunk parser ("fmt " + "data") handling Kokoro, SAPI, and raw PCM16.
bool DecodeWaveOrPcm16(const std::vector<uint8_t>& raw,
                       uint32_t fallback_sample_rate,
                       std::vector<int16_t>* out_samples,
                       uint32_t* out_rate,
                       uint16_t* out_channels) {
  out_samples->clear();
  if (raw.size() >= 12 &&
      std::memcmp(raw.data(), "RIFF", 4) == 0 &&
      std::memcmp(raw.data() + 8, "WAVE", 4) == 0) {
    bool found_fmt = false;
    bool found_data = false;
    bool is_float = false;
    uint16_t channels = 1;
    uint32_t sample_rate = fallback_sample_rate;
    uint16_t bits_per_sample = 16;
    const uint8_t* data_ptr = nullptr;
    size_t data_len = 0;

    size_t offset = 12;
    while (offset + 8 <= raw.size()) {
      const char* chunk_id = reinterpret_cast<const char*>(raw.data() + offset);
      const uint32_t chunk_size = ReadLe<uint32_t>(raw.data() + offset + 4);
      const size_t payload_offset = offset + 8;
      if (payload_offset + chunk_size > raw.size()) {
        break;
      }

      if (std::memcmp(chunk_id, "fmt ", 4) == 0 && chunk_size >= 16) {
        const uint16_t fmt_tag = ReadLe<uint16_t>(raw.data() + payload_offset);
        channels = ReadLe<uint16_t>(raw.data() + payload_offset + 2);
        sample_rate = ReadLe<uint32_t>(raw.data() + payload_offset + 4);
        bits_per_sample = ReadLe<uint16_t>(raw.data() + payload_offset + 14);
        if (fmt_tag == 3) {
          is_float = true;
          found_fmt = true;
        } else if (fmt_tag == 1) {
          is_float = false;
          found_fmt = true;
        } else if (fmt_tag == 0xFFFE && chunk_size >= 40) {
          GUID subformat{};
          std::memcpy(&subformat, raw.data() + payload_offset + 24, sizeof(GUID));
          if (std::memcmp(&subformat, &kSubformatIeeeFloat, sizeof(GUID)) == 0) {
            is_float = true;
            found_fmt = true;
          } else if (std::memcmp(&subformat, &kSubformatPcm, sizeof(GUID)) == 0) {
            is_float = false;
            found_fmt = true;
          }
        }
      } else if (std::memcmp(chunk_id, "data", 4) == 0) {
        data_ptr = raw.data() + payload_offset;
        data_len = chunk_size;
        found_data = true;
      }

      // RIFF chunks are word-aligned (padded to even byte boundary).
      offset = payload_offset + chunk_size + (chunk_size & 1u);
    }

    if (!found_fmt || !found_data || channels == 0 || sample_rate == 0) {
      return false;
    }
    if (!is_float && bits_per_sample == 16) {
      const size_t count = data_len / 2;
      out_samples->resize(count);
      std::memcpy(out_samples->data(), data_ptr, count * 2);
    } else if (is_float && bits_per_sample == 32) {
      const size_t count = data_len / 4;
      out_samples->resize(count);
      for (size_t i = 0; i < count; ++i) {
        const float f = ReadLe<float>(data_ptr + i * 4);
        const double scaled = (std::max)(-1.0, (std::min)(1.0, static_cast<double>(f))) * 32767.0;
        (*out_samples)[i] = static_cast<int16_t>(std::llround(scaled));
      }
    } else {
      return false;
    }

    *out_rate = sample_rate;
    *out_channels = channels;
    return true;
  }

  // Fallback: treat input directly as mono PCM16.
  if (raw.size() < 2 || (raw.size() % 2) != 0) {
    return false;
  }
  const size_t count = raw.size() / 2;
  out_samples->resize(count);
  std::memcpy(out_samples->data(), raw.data(), count * 2);
  *out_rate = fallback_sample_rate > 0 ? fallback_sample_rate : 16000;
  *out_channels = 1;
  return true;
}

std::vector<int16_t> ExtractCaptureChunkAsMono16k(
    const uint8_t* data,
    UINT32 num_frames,
    const WAVEFORMATEX* fmt) {
  if (!data || num_frames == 0 || !fmt || fmt->nChannels == 0 || fmt->nSamplesPerSec == 0) {
    return {};
  }

  bool is_float = false;
  if (fmt->wFormatTag == WAVE_FORMAT_IEEE_FLOAT) {
    is_float = true;
  } else if (fmt->wFormatTag == WAVE_FORMAT_EXTENSIBLE &&
             fmt->cbSize >= sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX)) {
    const auto* ext = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(fmt);
    is_float = (std::memcmp(&ext->SubFormat, &kSubformatIeeeFloat, sizeof(GUID)) == 0);
  }

  std::vector<int16_t> native_pcm;
  native_pcm.resize(static_cast<size_t>(num_frames) * fmt->nChannels, 0);
  if (is_float && fmt->wBitsPerSample == 32) {
    const size_t total = static_cast<size_t>(num_frames) * fmt->nChannels;
    for (size_t i = 0; i < total; ++i) {
      const float f = ReadLe<float>(data + i * 4);
      const double clamped = (std::max)(-1.0, (std::min)(1.0, static_cast<double>(f)));
      native_pcm[i] = static_cast<int16_t>(std::llround(clamped * 32767.0));
    }
  } else if (!is_float && fmt->wBitsPerSample == 16) {
    std::memcpy(native_pcm.data(), data, native_pcm.size() * 2);
  } else {
    return {};
  }

  return ConvertAndResamplePcm16(
      native_pcm, fmt->nSamplesPerSec, fmt->nChannels, kCaptureSampleRate, kCaptureChannels);
}

}  // namespace

WindowsAudioChannel::WindowsAudioChannel(flutter::BinaryMessenger* messenger, HWND hwnd)
    : hwnd_(hwnd) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });
}

WindowsAudioChannel::~WindowsAudioChannel() {
  if (hotkey_registered_ && hwnd_ != nullptr) {
    ::UnregisterHotKey(hwnd_, kGlobalVoiceHotkeyId);
    hotkey_registered_ = false;
  }
  StopCapture();
  StopRenderThread();
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }
}

void WindowsAudioChannel::HandleAudioEventMessage() {
  std::deque<CapturedFrame> batch;
  {
    std::lock_guard<std::mutex> lock(capture_mutex_);
    batch.swap(capture_queue_);
    capture_event_posted_.store(false);
  }
  if (!channel_) return;

  for (auto& frame : batch) {
    flutter::EncodableMap payload;
    payload[flutter::EncodableValue("pcm16")] = flutter::EncodableValue(std::move(frame.pcm16));
    payload[flutter::EncodableValue("rms")] = flutter::EncodableValue(frame.rms);
    channel_->InvokeMethod("onCaptureFrame", std::make_unique<flutter::EncodableValue>(std::move(payload)));
  }
}

void WindowsAudioChannel::HandleHotkeyMessage(WPARAM wparam) {
  if (static_cast<int>(wparam) == kGlobalVoiceHotkeyId && channel_) {
    channel_->InvokeMethod("onGlobalHotkey", nullptr);
  }
}

void WindowsAudioChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  const std::string& method = call.method_name();

  if (method == "enumerateDevices") {
    bool capture = true;
    if (args) {
      auto it = args->find(flutter::EncodableValue("kind"));
      if (it != args->end()) {
        if (const auto* kind = std::get_if<std::string>(&it->second)) {
          capture = (*kind != "render");
        }
      }
    }
    result->Success(flutter::EncodableValue(EnumerateDevices(capture)));
    return;
  }

  if (method == "startCapture") {
    std::wstring dev_id;
    if (args) {
      auto it = args->find(flutter::EncodableValue("deviceId"));
      if (it != args->end()) {
        if (const auto* id = std::get_if<std::string>(&it->second)) {
          dev_id = Utf8ToWide(*id);
        }
      }
    }
    std::string err;
    if (!StartCapture(dev_id, &err)) {
      result->Error("AUDIO_CAPTURE_ERROR", err.empty() ? "Failed to start WASAPI capture" : err);
      return;
    }
    result->Success();
    return;
  }

  if (method == "stopCapture") {
    StopCapture();
    result->Success();
    return;
  }

  if (method == "playAudio") {
    if (!args) {
      result->Error("INVALID_ARGS", "Missing arguments for playAudio");
      return;
    }
    std::vector<uint8_t> bytes;
    std::wstring dev_id;
    uint32_t sample_rate = 24000;
    uint64_t generation = 0;

    if (auto it = args->find(flutter::EncodableValue("bytes")); it != args->end()) {
      if (const auto* b = std::get_if<std::vector<uint8_t>>(&it->second)) {
        bytes = *b;
      }
    }
    if (auto it = args->find(flutter::EncodableValue("deviceId")); it != args->end()) {
      if (const auto* d = std::get_if<std::string>(&it->second)) {
        dev_id = Utf8ToWide(*d);
      }
    }
    if (auto it = args->find(flutter::EncodableValue("sampleRate")); it != args->end()) {
      if (const auto* sr32 = std::get_if<int32_t>(&it->second)) {
        sample_rate = static_cast<uint32_t>((std::max)(8000, *sr32));
      } else if (const auto* sr64 = std::get_if<int64_t>(&it->second)) {
        sample_rate = static_cast<uint32_t>((std::max)(int64_t{8000}, *sr64));
      }
    }
    if (auto it = args->find(flutter::EncodableValue("generation")); it != args->end()) {
      if (const auto* g32 = std::get_if<int32_t>(&it->second)) {
        generation = static_cast<uint64_t>((std::max)(0, *g32));
      } else if (const auto* g64 = std::get_if<int64_t>(&it->second)) {
        generation = static_cast<uint64_t>((std::max)(int64_t{0}, *g64));
      }
    }

    std::string err;
    if (!EnqueuePlayback(bytes, dev_id, sample_rate, generation, &err)) {
      result->Error("AUDIO_PLAYBACK_ERROR", err.empty() ? "Invalid audio payload" : err);
      return;
    }
    result->Success();
    return;
  }

  if (method == "flushPlayback") {
    uint64_t min_gen = min_playback_generation_.load() + 1;
    if (args) {
      auto it = args->find(flutter::EncodableValue("minGeneration"));
      if (it != args->end()) {
        if (const auto* g32 = std::get_if<int32_t>(&it->second)) {
          min_gen = static_cast<uint64_t>((std::max)(0, *g32));
        } else if (const auto* g64 = std::get_if<int64_t>(&it->second)) {
          min_gen = static_cast<uint64_t>((std::max)(int64_t{0}, *g64));
        }
      }
    }
    FlushPlayback(min_gen);
    result->Success();
    return;
  }

  if (method == "playTestTone") {
    std::wstring dev_id;
    if (args) {
      auto it = args->find(flutter::EncodableValue("deviceId"));
      if (it != args->end()) {
        if (const auto* d = std::get_if<std::string>(&it->second)) {
          dev_id = Utf8ToWide(*d);
        }
      }
    }
    // Generate ~260ms gentle C5 -> E5 sine chime cleanly in memory.
    constexpr uint32_t sr = 24000;
    constexpr size_t total_samples = sr / 4;
    std::vector<uint8_t> pcm_bytes(total_samples * 2, 0);
    for (size_t i = 0; i < total_samples; ++i) {
      const double freq = (i < total_samples / 2) ? 523.25 : 659.25;
      const double env = std::sin(kPi * static_cast<double>(i) / static_cast<double>(total_samples));
      const int16_t s = static_cast<int16_t>(
          std::llround(4800.0 * env * std::sin(2.0 * kPi * freq * static_cast<double>(i) / sr)));
      std::memcpy(pcm_bytes.data() + i * 2, &s, 2);
    }
    std::string err;
    EnqueuePlayback(pcm_bytes, dev_id, sr, min_playback_generation_.load(), &err);
    result->Success();
    return;
  }

  if (method == "registerGlobalHotkey") {
    UINT mods = 0;
    UINT vk = 0;
    if (args) {
      if (auto it = args->find(flutter::EncodableValue("modifiers")); it != args->end()) {
        if (const auto* m = std::get_if<int32_t>(&it->second)) {
          mods = static_cast<UINT>((std::max)(0, *m));
        }
      }
      if (auto it = args->find(flutter::EncodableValue("virtualKey")); it != args->end()) {
        if (const auto* v = std::get_if<int32_t>(&it->second)) {
          vk = static_cast<UINT>((std::max)(0, *v));
        }
      }
    }
    if (hotkey_registered_ && hwnd_ != nullptr) {
      ::UnregisterHotKey(hwnd_, kGlobalVoiceHotkeyId);
      hotkey_registered_ = false;
    }
    flutter::EncodableMap resp;
    if (hwnd_ != nullptr && vk != 0 &&
        ::RegisterHotKey(hwnd_, kGlobalVoiceHotkeyId, mods | MOD_NOREPEAT, vk)) {
      hotkey_registered_ = true;
      resp[flutter::EncodableValue("registered")] = flutter::EncodableValue(true);
    } else {
      const DWORD err_code = ::GetLastError();
      resp[flutter::EncodableValue("registered")] = flutter::EncodableValue(false);
      resp[flutter::EncodableValue("errorCode")] = flutter::EncodableValue(static_cast<int>(err_code));
    }
    result->Success(flutter::EncodableValue(std::move(resp)));
    return;
  }

  if (method == "unregisterGlobalHotkey") {
    if (hotkey_registered_ && hwnd_ != nullptr) {
      ::UnregisterHotKey(hwnd_, kGlobalVoiceHotkeyId);
      hotkey_registered_ = false;
    }
    result->Success();
    return;
  }

  result->NotImplemented();
}

flutter::EncodableList WindowsAudioChannel::EnumerateDevices(bool capture) {
  ScopedUiComGuard com_guard;
  flutter::EncodableList list;

  flutter::EncodableMap def_item;
  def_item[flutter::EncodableValue("id")] = flutter::EncodableValue("");
  def_item[flutter::EncodableValue("name")] = flutter::EncodableValue(
      capture ? "Default Windows Microphone" : "Default Windows Speaker");
  def_item[flutter::EncodableValue("isDefault")] = flutter::EncodableValue(true);
  list.push_back(flutter::EncodableValue(std::move(def_item)));

  ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                IID_PPV_ARGS(&enumerator)))) {
    return list;
  }

  ComPtr<IMMDeviceCollection> collection;
  if (FAILED(enumerator->EnumAudioEndpoints(capture ? eCapture : eRender,
                                            DEVICE_STATE_ACTIVE, &collection))) {
    return list;
  }

  UINT count = 0;
  collection->GetCount(&count);
  for (UINT i = 0; i < count; ++i) {
    ComPtr<IMMDevice> device;
    if (FAILED(collection->Item(i, &device))) continue;

    LPWSTR raw_id = nullptr;
    if (FAILED(device->GetId(&raw_id)) || !raw_id) continue;
    std::wstring dev_id(raw_id);
    ::CoTaskMemFree(raw_id);

    std::string friendly = WideToUtf8(dev_id);
    ComPtr<IPropertyStore> store;
    if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &store))) {
      PROPVARIANT prop;
      ::PropVariantInit(&prop);
      if (SUCCEEDED(store->GetValue(kPkeyDeviceFriendlyName, &prop)) &&
          prop.vt == VT_LPWSTR && prop.pwszVal != nullptr) {
        friendly = WideToUtf8(prop.pwszVal);
      }
      ::PropVariantClear(&prop);
    }

    flutter::EncodableMap entry;
    entry[flutter::EncodableValue("id")] = flutter::EncodableValue(WideToUtf8(dev_id));
    entry[flutter::EncodableValue("name")] = flutter::EncodableValue(std::move(friendly));
    entry[flutter::EncodableValue("isDefault")] = flutter::EncodableValue(false);
    list.push_back(flutter::EncodableValue(std::move(entry)));
  }
  return list;
}

bool WindowsAudioChannel::StartCapture(const std::wstring& device_id, std::string* err_out) {
  StopCapture();
  {
    std::lock_guard<std::mutex> lock(capture_mutex_);
    capture_init_done_ = false;
    capture_init_ok_ = false;
    capture_init_error_.clear();
  }
  capture_stop_requested_.store(false);
  capture_thread_ = std::thread(&WindowsAudioChannel::CaptureWorker, this, device_id);

  std::unique_lock<std::mutex> lock(capture_mutex_);
  capture_init_cv_.wait(lock, [&]() { return capture_init_done_; });
  const bool ok = capture_init_ok_;
  const std::string err = capture_init_error_;
  lock.unlock();

  if (!ok) {
    StopCapture();
    if (err_out) {
      *err_out = err.empty() ? "Failed to open WASAPI capture device." : err;
    }
    return false;
  }
  return true;
}

void WindowsAudioChannel::StopCapture() {
  capture_stop_requested_.store(true);
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
  std::lock_guard<std::mutex> lock(capture_mutex_);
  capture_queue_.clear();
  capture_event_posted_.store(false);
}

void WindowsAudioChannel::CaptureWorker(std::wstring device_id) {
  auto notify_init = [&](bool ok, const char* msg) {
    {
      std::lock_guard<std::mutex> lock(capture_mutex_);
      if (!capture_init_done_) {
        capture_init_ok_ = ok;
        capture_init_error_ = msg ? msg : "";
        capture_init_done_ = true;
      }
    }
    capture_init_cv_.notify_all();
  };

  struct CaptureInitGuard {
    decltype(notify_init)& fn;
    ~CaptureInitGuard() { fn(false, "Capture worker exited before WASAPI initialization completed."); }
  } init_guard{notify_init};

  ScopedMtaComGuard com_guard;
  {
    ComPtr<IMMDeviceEnumerator> enumerator;
    if (FAILED(::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                  IID_PPV_ARGS(&enumerator)))) {
      notify_init(false, "Unable to create MMDeviceEnumerator for microphone capture.");
      return;
    }

    ComPtr<IMMDevice> device;
    if (device_id.empty()) {
      if (FAILED(enumerator->GetDefaultAudioEndpoint(eCapture, eCommunications, &device))) {
        enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
      }
    } else {
      enumerator->GetDevice(device_id.c_str(), &device);
    }
    if (!device) {
      notify_init(false, "No active microphone input device found.");
      return;
    }

    ComPtr<IAudioClient> audio_client;
    if (FAILED(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                reinterpret_cast<void**>(audio_client.GetAddressOf())))) {
      notify_init(false, "Failed to activate WASAPI IAudioClient for microphone.");
      return;
    }

    WAVEFORMATEX target_fmt{};
    target_fmt.wFormatTag = WAVE_FORMAT_PCM;
    target_fmt.nChannels = kCaptureChannels;
    target_fmt.nSamplesPerSec = kCaptureSampleRate;
    target_fmt.wBitsPerSample = kCaptureBits;
    target_fmt.nBlockAlign = (target_fmt.nChannels * target_fmt.wBitsPerSample) / 8;
    target_fmt.nAvgBytesPerSec = target_fmt.nSamplesPerSec * target_fmt.nBlockAlign;

    WAVEFORMATEX* mix_fmt = nullptr;
    const WAVEFORMATEX* active_fmt = &target_fmt;
    constexpr REFERENCE_TIME buffer_duration = 2'000'000;  // 200ms buffer

    HRESULT hr = audio_client->Initialize(
        AUDCLNT_SHAREMODE_SHARED,
        AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
        buffer_duration, 0, &target_fmt, nullptr);
    bool native_16k = SUCCEEDED(hr);
    if (!native_16k) {
      if (FAILED(audio_client->GetMixFormat(&mix_fmt)) || mix_fmt == nullptr) {
        notify_init(false, "Failed to query WASAPI microphone mix format.");
        return;
      }
      hr = audio_client->Initialize(
          AUDCLNT_SHAREMODE_SHARED, 0, buffer_duration, 0, mix_fmt, nullptr);
      if (FAILED(hr)) {
        ::CoTaskMemFree(mix_fmt);
        notify_init(false, "Failed to initialize WASAPI microphone stream.");
        return;
      }
      active_fmt = mix_fmt;
    }

    ComPtr<IAudioCaptureClient> capture_client;
    if (FAILED(audio_client->GetService(IID_PPV_ARGS(&capture_client)))) {
      if (mix_fmt) ::CoTaskMemFree(mix_fmt);
      notify_init(false, "Failed to acquire WASAPI IAudioCaptureClient service.");
      return;
    }

    if (FAILED(audio_client->Start())) {
      if (mix_fmt) ::CoTaskMemFree(mix_fmt);
      notify_init(false, "Failed to start WASAPI microphone capture stream.");
      return;
    }

    notify_init(true, nullptr);

    std::vector<int16_t> staging;
    staging.reserve(kCaptureFrameSamples * 2);

    while (!capture_stop_requested_.load()) {
      UINT32 packet_len = 0;
      if (FAILED(capture_client->GetNextPacketSize(&packet_len))) {
        break;
      }
      if (packet_len == 0) {
        ::Sleep(10);
        continue;
      }

      while (packet_len > 0 && !capture_stop_requested_.load()) {
        BYTE* data = nullptr;
        UINT32 num_frames = 0;
        DWORD flags = 0;
        if (FAILED(capture_client->GetBuffer(&data, &num_frames, &flags, nullptr, nullptr))) {
          packet_len = 0;
          break;
        }

        if (num_frames > 0) {
          if (flags & AUDCLNT_BUFFERFLAGS_SILENT) {
            const size_t approx = native_16k
                ? static_cast<size_t>(num_frames)
                : static_cast<size_t>(std::llround(
                      static_cast<double>(num_frames) * kCaptureSampleRate /
                      (std::max)(DWORD{8000}, active_fmt->nSamplesPerSec)));
            staging.insert(staging.end(), approx, 0);
          } else {
            auto converted = ExtractCaptureChunkAsMono16k(data, num_frames, active_fmt);
            staging.insert(staging.end(), converted.begin(), converted.end());
          }
        }
        capture_client->ReleaseBuffer(num_frames);

        while (staging.size() >= kCaptureFrameSamples && !capture_stop_requested_.load()) {
          const double rms = ComputePcm16Rms(staging.data(), kCaptureFrameSamples);
          std::vector<uint8_t> frame_bytes(kCaptureFrameBytes);
          std::memcpy(frame_bytes.data(), staging.data(), kCaptureFrameBytes);
          staging.erase(staging.begin(), staging.begin() + kCaptureFrameSamples);

          bool should_post = false;
          {
            std::lock_guard<std::mutex> lock(capture_mutex_);
            if (capture_queue_.size() >= kMaxCaptureQueueDepth) {
              capture_queue_.pop_front();
            }
            capture_queue_.push_back(CapturedFrame{std::move(frame_bytes), rms});
            if (!capture_event_posted_.exchange(true)) {
              should_post = true;
            }
          }
          if (should_post && hwnd_ != nullptr) {
            ::PostMessageW(hwnd_, kWmAudioEvent, 0, 0);
          }
        }

        if (FAILED(capture_client->GetNextPacketSize(&packet_len))) {
          packet_len = 0;
        }
      }
    }

    audio_client->Stop();
    if (mix_fmt) ::CoTaskMemFree(mix_fmt);
  }
}

bool WindowsAudioChannel::EnqueuePlayback(
    const std::vector<uint8_t>& raw_bytes,
    const std::wstring& device_id,
    uint32_t fallback_sample_rate,
    uint64_t generation,
    std::string* err_out) {
  if (generation < min_playback_generation_.load()) {
    return true;
  }

  std::vector<int16_t> decoded;
  uint32_t rate = fallback_sample_rate;
  uint16_t channels = 1;
  if (!DecodeWaveOrPcm16(raw_bytes, fallback_sample_rate, &decoded, &rate, &channels)) {
    if (err_out) *err_out = "Unable to decode WAV/PCM16 playback buffer.";
    return false;
  }
  if (decoded.empty()) {
    return true;
  }

  EnsureRenderThreadStarted(device_id);
  {
    std::lock_guard<std::mutex> lock(render_mutex_);
    if (generation < min_playback_generation_.load()) {
      return true;
    }
    render_queue_.push_back(PlaybackItem{generation, std::move(decoded), rate, channels});
  }
  render_cv_.notify_one();
  return true;
}

void WindowsAudioChannel::FlushPlayback(uint64_t min_generation) {
  min_playback_generation_.store(min_generation);
  render_flush_requested_.store(true);
  {
    std::lock_guard<std::mutex> lock(render_mutex_);
    while (!render_queue_.empty()) {
      if (render_queue_.front().generation < min_generation) {
        render_queue_.pop_front();
      } else {
        // Keep only items cleanly >= min_generation
        break;
      }
    }
    std::deque<PlaybackItem> kept;
    for (auto& item : render_queue_) {
      if (item.generation >= min_generation) {
        kept.push_back(std::move(item));
      }
    }
    render_queue_.swap(kept);
  }
  render_cv_.notify_one();
}

void WindowsAudioChannel::EnsureRenderThreadStarted(const std::wstring& device_id) {
  if (render_thread_.joinable() &&
      render_worker_alive_.load() &&
      active_render_device_ == device_id) {
    return;
  }
  StopRenderThread();
  active_render_device_ = device_id;
  render_stop_requested_.store(false);
  render_flush_requested_.store(false);
  render_worker_alive_.store(true);
  render_thread_ = std::thread(&WindowsAudioChannel::RenderWorker, this, device_id);
}

void WindowsAudioChannel::StopRenderThread() {
  render_stop_requested_.store(true);
  render_flush_requested_.store(true);
  render_cv_.notify_all();
  if (render_thread_.joinable()) {
    render_thread_.join();
  }
  render_worker_alive_.store(false);
  std::lock_guard<std::mutex> lock(render_mutex_);
  render_queue_.clear();
}

void WindowsAudioChannel::RenderWorker(std::wstring device_id) {
  struct AliveGuard {
    std::atomic<bool>& flag;
    ~AliveGuard() { flag.store(false); }
  } alive_guard{render_worker_alive_};

  ScopedMtaComGuard com_guard;
  {
    ComPtr<IMMDeviceEnumerator> enumerator;
    if (FAILED(::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                  IID_PPV_ARGS(&enumerator)))) {
      return;
    }

    ComPtr<IMMDevice> device;
    if (device_id.empty()) {
      enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
    } else {
      enumerator->GetDevice(device_id.c_str(), &device);
    }
    if (!device) return;

    ComPtr<IAudioClient> audio_client;
    if (FAILED(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                reinterpret_cast<void**>(audio_client.GetAddressOf())))) {
      return;
    }

    WAVEFORMATEX* mix_fmt = nullptr;
    if (FAILED(audio_client->GetMixFormat(&mix_fmt)) || mix_fmt == nullptr) {
      return;
    }
    const uint32_t out_rate = mix_fmt->nSamplesPerSec;
    const uint16_t out_channels = mix_fmt->nChannels;

    // Open PCM16 stereo/mix output via AUTOCONVERTPCM cleanly.
    WAVEFORMATEX render_fmt{};
    render_fmt.wFormatTag = WAVE_FORMAT_PCM;
    render_fmt.nChannels = out_channels;
    render_fmt.nSamplesPerSec = out_rate;
    render_fmt.wBitsPerSample = 16;
    render_fmt.nBlockAlign = (render_fmt.nChannels * render_fmt.wBitsPerSample) / 8;
    render_fmt.nAvgBytesPerSec = render_fmt.nSamplesPerSec * render_fmt.nBlockAlign;
    ::CoTaskMemFree(mix_fmt);

    if (FAILED(audio_client->Initialize(
            AUDCLNT_SHAREMODE_SHARED,
            AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
            2'000'000, 0, &render_fmt, nullptr))) {
      return;
    }

    UINT32 buffer_frame_count = 0;
    audio_client->GetBufferSize(&buffer_frame_count);

    ComPtr<IAudioRenderClient> render_client;
    if (FAILED(audio_client->GetService(IID_PPV_ARGS(&render_client)))) {
      return;
    }

    audio_client->Start();
    bool is_started = true;

    while (!render_stop_requested_.load()) {
      PlaybackItem item{};
      bool do_flush = false;
      {
        std::unique_lock<std::mutex> lock(render_mutex_);
        render_cv_.wait(lock, [&]() {
          return render_stop_requested_.load() ||
                 render_flush_requested_.load() ||
                 !render_queue_.empty();
        });
        if (render_stop_requested_.load()) break;
        do_flush = render_flush_requested_.exchange(false);
        if (!render_queue_.empty()) {
          item = std::move(render_queue_.front());
          render_queue_.pop_front();
        }
      }

      if (do_flush && is_started) {
        audio_client->Stop();
        audio_client->Reset();
        audio_client->Start();
      }

      if (item.samples.empty()) {
        continue;
      }

      if (item.generation < min_playback_generation_.load()) {
        continue;
      }

      auto resampled = ConvertAndResamplePcm16(
          item.samples, item.sample_rate, item.channels, out_rate, out_channels);
      const size_t total_frames = resampled.size() / out_channels;
      size_t cursor = 0;

      while (cursor < total_frames && !render_stop_requested_.load()) {
        if (item.generation < min_playback_generation_.load() ||
            render_flush_requested_.load()) {
          audio_client->Stop();
          audio_client->Reset();
          audio_client->Start();
          render_flush_requested_.store(false);
          break;
        }

        UINT32 padding = 0;
        if (FAILED(audio_client->GetCurrentPadding(&padding))) {
          break;
        }
        const UINT32 available = buffer_frame_count > padding ? buffer_frame_count - padding : 0;
        if (available == 0) {
          ::Sleep(8);
          continue;
        }

        const UINT32 chunk_frames = static_cast<UINT32>(
            (std::min)(static_cast<size_t>(available), total_frames - cursor));
        BYTE* dst = nullptr;
        if (FAILED(render_client->GetBuffer(chunk_frames, &dst)) || dst == nullptr) {
          break;
        }
        std::memcpy(
            dst,
            resampled.data() + cursor * out_channels,
            static_cast<size_t>(chunk_frames) * out_channels * 2);
        render_client->ReleaseBuffer(chunk_frames, 0);
        cursor += chunk_frames;
      }
    }

    if (is_started) {
      audio_client->Stop();
    }
  }
}
