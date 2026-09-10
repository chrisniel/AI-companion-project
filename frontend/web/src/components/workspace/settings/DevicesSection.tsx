import React from 'react';
import { Mic, Headphones, Bluetooth, Usb, Cpu, Settings2, Check } from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { useTheme } from '../../../context/ThemeContext';

export interface DeviceSettingsState {
  selectedMicId: string;
  selectedSpeakerId: string;
  audioBufferSize: number;
  autoReconnectBluetooth: boolean;
  usbHotplugAutoSwitch: boolean;
  exclusiveDeviceAccess: boolean;
  wearableAutoSync: boolean;
}

interface DevicesSectionProps {
  settings: DeviceSettingsState;
  onUpdate: <K extends keyof DeviceSettingsState>(key: K, value: DeviceSettingsState[K]) => void;
}

export const DevicesSection: React.FC<DevicesSectionProps> = ({ settings, onUpdate }) => {
  const { mode } = useTheme();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <Headphones className="w-5 h-5 text-[var(--color-accent)]" />
          Hardware Devices & Audio I/O Preferences
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Select primary audio stream endpoints, manage low-latency ringbuffers, and configure peripheral hotplugging.
        </p>
      </div>

      {/* 1. Audio I/O Routing */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Mic className="w-4 h-4" />
          Primary Audio Routing Endpoints
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)] flex items-center justify-between">
              <span>Primary Input Microphone</span>
              <span className="text-[10px] font-mono text-emerald-500 font-semibold">Ready</span>
            </label>
            <select
              value={settings.selectedMicId}
              onChange={(e) => onUpdate('selectedMicId', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="builtin_mic" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>MacBook Pro Microphone (Built-in Array)</option>
              <option value="focusrite_in" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Focusrite Scarlett 2i2 USB (Channel 1/2)</option>
              <option value="airpods_in" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>AirPods Pro (Bluetooth HFP Wideband)</option>
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)] flex items-center justify-between">
              <span>Primary Output Playback</span>
              <span className="text-[10px] font-mono text-emerald-500 font-semibold">Active</span>
            </label>
            <select
              value={settings.selectedSpeakerId}
              onChange={(e) => onUpdate('selectedSpeakerId', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="usb_dac" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>USB Audio DAC (Low Latency 48kHz)</option>
              <option value="focusrite_out" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Focusrite Scarlett 2i2 Monitors</option>
              <option value="builtin_speakers" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>MacBook Pro Speakers (Spatial Audio)</option>
            </select>
          </div>
        </div>

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-3 border-t border-[var(--color-border-subtle)]">
          <div>
            <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
              CoreAudio Buffer Frame Size
            </span>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Smaller frames reduce latency but increase CPU scheduling load.
            </p>
          </div>
          <select
            value={settings.audioBufferSize}
            onChange={(e) => onUpdate('audioBufferSize', Number(e.target.value))}
            style={{ colorScheme: mode }}
            className="px-3.5 py-2 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] cursor-pointer shadow-xs"
          >
            <option value={128} className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>128 samples (~2.7ms Ultra-low latency)</option>
            <option value={256} className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>256 samples (~5.3ms Balanced Default)</option>
            <option value={512} className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>512 samples (~10.7ms Maximum stability)</option>
          </select>
        </div>
      </div>

      {/* 2. Peripheral Hotplugging & Bluetooth */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Bluetooth className="w-4 h-4" />
          Peripheral Connection Automation
        </h3>

        <div className="space-y-3.5">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Auto-Reconnect Paired Bluetooth Peripherals
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Automatically reconnect to FitCloudPro smart watch and wireless headphones when in range.
              </p>
            </div>
            <Toggle
              checked={settings.autoReconnectBluetooth}
              onChange={(val) => onUpdate('autoReconnectBluetooth', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                USB Audio Hotplug Auto-Switch
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Automatically transition audio input/output when an external USB interface is plugged in.
              </p>
            </div>
            <Toggle
              checked={settings.usbHotplugAutoSwitch}
              onChange={(val) => onUpdate('usbHotplugAutoSwitch', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Exclusive Audio Device Access (Direct Mode)
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Bypass system mixer DSP for bit-perfect input to Whisper transcription.
              </p>
            </div>
            <Toggle
              checked={settings.exclusiveDeviceAccess}
              onChange={(val) => onUpdate('exclusiveDeviceAccess', val)}
              size="sm"
            />
          </div>
        </div>
      </div>
    </div>
  );
};
