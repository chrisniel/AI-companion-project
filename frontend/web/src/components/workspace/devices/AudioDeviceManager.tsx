import React, { useState, useEffect } from 'react';
import {
  Sliders,
  Mic,
  Speaker,
  Volume2,
  VolumeX,
  Play,
  Square,
  Check,
  AlertCircle,
  Sparkles,
  Radio,
  RadioTower,
  Cpu,
  ChevronDown,
} from 'lucide-react';
import { AudioDeviceOption, AudioRoutingConfig } from '../../../types';
import {
  mockAudioInputOptions,
  mockAudioOutputOptions,
  initialAudioRoutingConfig,
} from '../../../mock/deviceAndMemoryData';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { useTheme } from '../../../context/ThemeContext';

export interface AudioDeviceManagerProps {
  onConfigChange?: (config: AudioRoutingConfig) => void;
}

export const AudioDeviceManager: React.FC<AudioDeviceManagerProps> = ({
  onConfigChange,
}) => {
  const { mode } = useTheme();
  const [config, setConfig] = useState<AudioRoutingConfig>(initialAudioRoutingConfig);

  // Mock testing states (no real audio access)
  const [isTestingMic, setIsTestingMic] = useState(false);
  const [micLevelDb, setMicLevelDb] = useState(-52);
  const [isTestingOutput, setIsTestingOutput] = useState(false);
  const [outputTestProgress, setOutputTestProgress] = useState(0);
  const [outputTestSuccess, setOutputTestSuccess] = useState(false);

  // Simulated Mic level oscillation during microphone test
  useEffect(() => {
    let interval: NodeJS.Timeout | null = null;
    let timeout: NodeJS.Timeout | null = null;

    if (isTestingMic) {
      interval = setInterval(() => {
        // Random natural fluctuating speech level between -34 dB and -16 dB
        const simulatedDb = Math.floor(Math.random() * 20) - 36;
        setMicLevelDb(simulatedDb);
      }, 100);

      // Automatically finish test after 4.5 seconds
      timeout = setTimeout(() => {
        setIsTestingMic(false);
        setMicLevelDb(-52);
      }, 4500);
    } else {
      setMicLevelDb(-52);
    }

    return () => {
      if (interval) clearInterval(interval);
      if (timeout) clearTimeout(timeout);
    };
  }, [isTestingMic]);

  // Simulated Output chime test progress
  useEffect(() => {
    let interval: NodeJS.Timeout | null = null;
    let timeout: NodeJS.Timeout | null = null;

    if (isTestingOutput) {
      setOutputTestProgress(0);
      setOutputTestSuccess(false);

      interval = setInterval(() => {
        setOutputTestProgress((prev) => {
          if (prev >= 100) {
            clearInterval(interval!);
            return 100;
          }
          return prev + 10;
        });
      }, 150);

      timeout = setTimeout(() => {
        setIsTestingOutput(false);
        setOutputTestSuccess(true);
        setTimeout(() => setOutputTestSuccess(false), 3000);
      }, 1800);
    }

    return () => {
      if (interval) clearInterval(interval);
      if (timeout) clearTimeout(timeout);
    };
  }, [isTestingOutput]);

  const handleUpdate = (field: keyof AudioRoutingConfig, value: string) => {
    const updated = { ...config, [field]: value };
    setConfig(updated);
    onConfigChange?.(updated);
  };

  const getInterfaceBadge = (type: AudioDeviceOption['interfaceType']) => {
    switch (type) {
      case 'usb':
        return <span className="text-[10px] font-mono px-1.5 py-0.5 rounded surface-recessed text-cyan-500 border border-cyan-500/20">USB</span>;
      case 'bluetooth':
        return <span className="text-[10px] font-mono px-1.5 py-0.5 rounded surface-recessed text-indigo-400 border border-indigo-400/20">BT</span>;
      case 'system':
        return <span className="text-[10px] font-mono px-1.5 py-0.5 rounded surface-recessed text-emerald-500 border border-emerald-500/20">SYS</span>;
      case 'pci':
        return <span className="text-[10px] font-mono px-1.5 py-0.5 rounded surface-recessed text-amber-500 border border-amber-500/20">PCIe</span>;
      case 'virtual':
        return <span className="text-[10px] font-mono px-1.5 py-0.5 rounded surface-recessed text-purple-400 border border-purple-400/20">VIRT</span>;
      default:
        return null;
    }
  };

  const currentInput = mockAudioInputOptions.find((o) => o.id === config.inputDeviceId) || mockAudioInputOptions[0];
  const currentOutput = mockAudioOutputOptions.find((o) => o.id === config.outputDeviceId) || mockAudioOutputOptions[0];
  const preferredOutput = mockAudioOutputOptions.find((o) => o.id === config.preferredOutputId) || mockAudioOutputOptions[0];
  const fallbackOutput = mockAudioOutputOptions.find((o) => o.id === config.fallbackOutputId) || mockAudioOutputOptions[0];

  return (
    <Card
      id="audio-device-manager-card"
      variant="elevated"
      padding="lg"
      className="space-y-6"
    >
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center text-[var(--color-accent)] flex-shrink-0 shadow-xs">
            <Sliders className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-base font-bold text-[var(--color-text-primary)]">
                Audio Device Manager
              </h3>
              <Badge variant="accent" size="sm">
                Bit-Perfect Routing
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-muted)]">
              Dynamic hardware selectors, priority routing, and zero-latency failover endpoints.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-[11px] font-mono text-[var(--color-text-muted)]">
            Active Subsystem: <strong className="text-[var(--color-text-primary)]">PipeWire (WASAPI/ALSA Bridge)</strong>
          </span>
        </div>
      </div>

      {/* Selectors Grid: Input, Output, Preferred Output, Fallback Output */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {/* 1. Input Device Selector */}
        <div className="space-y-2">
          <label className="flex items-center justify-between text-xs font-semibold text-[var(--color-text-secondary)]">
            <span className="flex items-center gap-1.5">
              <Mic className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              <span>Input Device (Capture)</span>
            </span>
            {getInterfaceBadge(currentInput.interfaceType)}
          </label>
          <div className="relative">
            <select
              value={config.inputDeviceId}
              onChange={(e) => handleUpdate('inputDeviceId', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 pr-9 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all appearance-none cursor-pointer shadow-xs"
            >
              {mockAudioInputOptions.map((opt) => (
                <option
                  key={opt.id}
                  value={opt.id}
                  className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1.5' : 'bg-white text-slate-900 py-1.5'}
                >
                  {opt.name} — [{opt.sampleRate}]
                </option>
              ))}
            </select>
            <ChevronDown className="w-4 h-4 text-[var(--color-text-muted)] absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
          <p className="text-[11px] text-[var(--color-text-muted)] font-mono">
            {currentInput.channels} • Format: PCM 32-bit Float
          </p>
        </div>

        {/* 2. Output Device Selector */}
        <div className="space-y-2">
          <label className="flex items-center justify-between text-xs font-semibold text-[var(--color-text-secondary)]">
            <span className="flex items-center gap-1.5">
              <Speaker className="w-3.5 h-3.5 text-emerald-500" />
              <span>Output Device (Playback)</span>
            </span>
            {getInterfaceBadge(currentOutput.interfaceType)}
          </label>
          <div className="relative">
            <select
              value={config.outputDeviceId}
              onChange={(e) => handleUpdate('outputDeviceId', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 pr-9 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all appearance-none cursor-pointer shadow-xs"
            >
              {mockAudioOutputOptions.map((opt) => (
                <option
                  key={opt.id}
                  value={opt.id}
                  className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1.5' : 'bg-white text-slate-900 py-1.5'}
                >
                  {opt.name} — [{opt.sampleRate}]
                </option>
              ))}
            </select>
            <ChevronDown className="w-4 h-4 text-[var(--color-text-muted)] absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
          <p className="text-[11px] text-[var(--color-text-muted)] font-mono">
            {currentOutput.channels} • Latency: &lt;5.8ms
          </p>
        </div>

        {/* 3. Preferred Output Selector */}
        <div className="space-y-2">
          <label className="flex items-center justify-between text-xs font-semibold text-[var(--color-text-secondary)]">
            <span className="flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-amber-500" />
              <span>Preferred Output (Primary Target)</span>
            </span>
            {getInterfaceBadge(preferredOutput.interfaceType)}
          </label>
          <div className="relative">
            <select
              value={config.preferredOutputId}
              onChange={(e) => handleUpdate('preferredOutputId', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 pr-9 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all appearance-none cursor-pointer shadow-xs"
            >
              {mockAudioOutputOptions.map((opt) => (
                <option
                  key={opt.id}
                  value={opt.id}
                  className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1.5' : 'bg-white text-slate-900 py-1.5'}
                >
                  {opt.name} ({opt.interfaceType.toUpperCase()})
                </option>
              ))}
            </select>
            <ChevronDown className="w-4 h-4 text-[var(--color-text-muted)] absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
          <p className="text-[11px] text-[var(--color-text-muted)]">
            Automatically targeted when hardware link connects or handoff occurs.
          </p>
        </div>

        {/* 4. Fallback Output Selector */}
        <div className="space-y-2">
          <label className="flex items-center justify-between text-xs font-semibold text-[var(--color-text-secondary)]">
            <span className="flex items-center gap-1.5">
              <RadioTower className="w-3.5 h-3.5 text-purple-400" />
              <span>Fallback Output (Failover Sink)</span>
            </span>
            {getInterfaceBadge(fallbackOutput.interfaceType)}
          </label>
          <div className="relative">
            <select
              value={config.fallbackOutputId}
              onChange={(e) => handleUpdate('fallbackOutputId', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 pr-9 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all appearance-none cursor-pointer shadow-xs"
            >
              {mockAudioOutputOptions.map((opt) => (
                <option
                  key={opt.id}
                  value={opt.id}
                  className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1.5' : 'bg-white text-slate-900 py-1.5'}
                >
                  {opt.name} ({opt.interfaceType.toUpperCase()})
                </option>
              ))}
            </select>
            <ChevronDown className="w-4 h-4 text-[var(--color-text-muted)] absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
          <p className="text-[11px] text-[var(--color-text-muted)]">
            Gracefully activated if preferred device disconnects or suffers buffer underrun.
          </p>
        </div>
      </div>

      {/* Mock Hardware Testing Section (No Real Audio Access) */}
      <div className="pt-4 border-t border-[var(--color-border-subtle)]">
        <div className="flex items-center justify-between mb-3">
          <span className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
            Diagnostic Verification (Mock Audio Access)
          </span>
          <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
            Pure client-side simulated telemetry
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Test Microphone Card */}
          <div className="p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Mic className="w-4 h-4 text-[var(--color-accent)]" />
                <span className="text-xs font-bold text-[var(--color-text-primary)]">
                  Microphone Signal Loopback
                </span>
              </div>
              <NeumorphicButton
                size="sm"
                variant={isTestingMic ? 'danger' : 'primary'}
                onClick={() => setIsTestingMic(!isTestingMic)}
                icon={isTestingMic ? <Square className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5" />}
              >
                {isTestingMic ? 'Stop Test' : 'Test Microphone'}
              </NeumorphicButton>
            </div>

            {/* Visual Level Meter */}
            <div className="space-y-1.5">
              <div className="flex justify-between text-[10px] font-mono text-[var(--color-text-muted)]">
                <span>Signal Level:</span>
                <span className={isTestingMic ? 'text-emerald-400 font-bold' : ''}>
                  {isTestingMic ? `${micLevelDb} dB RMS (Active)` : 'Inactive (-∞ dB)'}
                </span>
              </div>

              {/* Progress bar level meter */}
              <div className="w-full h-3 rounded-full surface-recessed overflow-hidden p-0.5 border border-[var(--color-border-subtle)] flex items-center">
                <div
                  className={`h-full rounded-full transition-all duration-100 ${
                    isTestingMic
                      ? micLevelDb > -22
                        ? 'bg-amber-400 shadow-sm'
                        : 'bg-emerald-500 shadow-sm'
                      : 'bg-transparent'
                  }`}
                  style={{
                    width: isTestingMic
                      ? `${Math.min(100, Math.max(8, ((micLevelDb + 60) / 45) * 100))}%`
                      : '0%',
                  }}
                />
              </div>

              {/* Speech Activity Status */}
              <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] pt-0.5">
                <span className="flex items-center gap-1">
                  <span
                    className={`w-1.5 h-1.5 rounded-full ${
                      isTestingMic ? 'bg-emerald-400 animate-ping' : 'bg-[var(--color-text-muted)]'
                    }`}
                  />
                  <span>Voice Activity Detection (VAD)</span>
                </span>
                <span className="font-mono text-[var(--color-text-secondary)]">
                  Target: {currentInput.name.split(' ')[0]}
                </span>
              </div>
            </div>
          </div>

          {/* Test Output Card */}
          <div className="p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Speaker className="w-4 h-4 text-emerald-500" />
                <span className="text-xs font-bold text-[var(--color-text-primary)]">
                  Output Channel Tone Verification
                </span>
              </div>
              <NeumorphicButton
                size="sm"
                variant={isTestingOutput ? 'secondary' : 'primary'}
                disabled={isTestingOutput}
                onClick={() => setIsTestingOutput(true)}
                icon={
                  outputTestSuccess ? (
                    <Check className="w-3.5 h-3.5 text-emerald-500" />
                  ) : isTestingOutput ? (
                    <Volume2 className="w-3.5 h-3.5 animate-pulse text-[var(--color-accent)]" />
                  ) : (
                    <Play className="w-3.5 h-3.5" />
                  )
                }
              >
                {outputTestSuccess ? 'Passed' : isTestingOutput ? 'Emitting Tone...' : 'Test Output'}
              </NeumorphicButton>
            </div>

            {/* Test progress visual */}
            <div className="space-y-1.5">
              <div className="flex justify-between text-[10px] font-mono text-[var(--color-text-muted)]">
                <span>Routing:</span>
                <span className="text-[var(--color-text-primary)] font-semibold truncate max-w-[200px]">
                  {preferredOutput.name}
                </span>
              </div>

              <div className="w-full h-3 rounded-full surface-recessed overflow-hidden p-0.5 border border-[var(--color-border-subtle)] flex items-center">
                <div
                  className="h-full rounded-full bg-accent-gradient transition-all duration-150"
                  style={{
                    width: isTestingOutput ? `${outputTestProgress}%` : outputTestSuccess ? '100%' : '0%',
                  }}
                />
              </div>

              <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] pt-0.5">
                <span className="italic">
                  {outputTestSuccess
                    ? '✓ Sine wave 440 Hz test confirmed (No underrun)'
                    : isTestingOutput
                    ? 'Transmitting 440Hz test chirp...'
                    : 'Sends simulated test chime'}
                </span>
                <span className="font-mono text-[var(--color-text-secondary)]">
                  48kHz PCM
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Card>
  );
};
