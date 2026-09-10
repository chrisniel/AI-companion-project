import React, { useState, useEffect } from 'react';
import {
  X,
  Sparkles,
  Volume2,
  Mic,
  MicOff,
  Activity,
  Terminal,
  Zap,
  RotateCcw,
  Sliders,
  ChevronRight,
  ChevronLeft,
  Bot,
  Layers,
  Radio,
  PanelRightClose,
  PanelRightOpen,
  Globe,
  Languages,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { IconButton } from '../ui/IconButton';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { Badge } from '../ui/Badge';
import { StatusIndicator } from '../ui/StatusIndicator';
import { ProgressBar } from '../ui/ProgressBar';
import { Slider } from '../ui/Slider';
import {
  mockAssistantPersonas,
  mockActivityLogs,
} from '../../mock/localAiData';
import { AssistantPanelMode, AssistantState } from '../../types';

export interface AssistantPanelProps {
  mode: AssistantPanelMode;
  onSetMode: (mode: AssistantPanelMode) => void;
  selectedPersonaId?: string;
  onSelectPersona?: (id: string) => void;
  assistantState?: AssistantState;
  onSetAssistantState?: (state: AssistantState) => void;
}

export const AssistantPanel: React.FC<AssistantPanelProps> = ({
  mode,
  onSetMode,
  selectedPersonaId = 'p-1',
  onSelectPersona,
  assistantState: controlledState,
  onSetAssistantState,
}) => {
  const [activePersonaId, setActivePersonaId] = useState(selectedPersonaId);
  const [internalAssistantState, setInternalAssistantState] = useState<AssistantState>('idle');
  const [micVolume, setMicVolume] = useState(78);
  const [isMuted, setIsMuted] = useState(false);
  const [simulatingInference, setSimulatingInference] = useState(false);
  const [panelLangMode, setPanelLangMode] = useState<'auto' | 'en' | 'fil' | 'ja'>('auto');

  const assistantState = controlledState !== undefined ? controlledState : internalAssistantState;
  const updateAssistantState = (st: AssistantState) => {
    if (onSetAssistantState) {
      onSetAssistantState(st);
    } else {
      setInternalAssistantState(st);
    }
  };

  // Sync prop changes
  useEffect(() => {
    if (selectedPersonaId) setActivePersonaId(selectedPersonaId);
  }, [selectedPersonaId]);

  if (mode === 'hidden') return null;

  const currentPersona =
    mockAssistantPersonas.find((p) => p.id === activePersonaId) ||
    mockAssistantPersonas[0];

  const handleTriggerInference = () => {
    setSimulatingInference(true);
    updateAssistantState('thinking');
    setTimeout(() => {
      updateAssistantState('speaking');
    }, 1200);
    setTimeout(() => {
      setSimulatingInference(false);
      updateAssistantState('idle');
    }, 3200);
  };

  const isCollapsed = mode === 'collapsed';

  return (
    <aside
      className={`h-full glass-bar border-l border-[var(--color-surface-glass-border)] flex flex-col justify-between overflow-y-auto z-30 select-none transition-[width] duration-300 ease-in-out ${
        isCollapsed ? 'w-[72px]' : 'w-80 sm:w-96'
      }`}
    >
      {/* 1. Header Bar of Panel */}
      <div className="h-14 px-3 border-b border-[var(--color-surface-glass-border)] flex items-center justify-between flex-shrink-0">
        {!isCollapsed ? (
          <div className="flex items-center gap-2.5 min-w-0 w-full">
            <button
              type="button"
              onClick={() => onSetMode('collapsed')}
              className="w-8 h-8 rounded-xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0 cursor-pointer hover:opacity-90 active:scale-95 transition-all shadow-sm"
              title="Click panel icon to collapse"
            >
              <Sparkles className="w-4 h-4" />
            </button>
            <div
              className="truncate cursor-pointer select-none flex-1 min-w-0"
              onClick={() => onSetMode('collapsed')}
              title="Click to collapse"
            >
              <h3 className="text-xs font-bold text-[var(--color-text-primary)] truncate leading-tight">
                Assistant Panel
              </h3>
              <p className="text-[10px] text-[var(--color-text-muted)] truncate font-mono">
                {currentPersona.name} • {assistantState}
              </p>
            </div>
          </div>
        ) : (
          <div className="w-full flex justify-center">
            <button
              type="button"
              onClick={() => onSetMode('expanded')}
              className="w-8 h-8 rounded-xl bg-accent-gradient text-white flex items-center justify-center shadow-md glow-accent-sm cursor-pointer hover:opacity-90 active:scale-95 transition-all"
              title="Click panel icon to uncollapse"
            >
              <Sparkles className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>

      {/* 2. Main Content */}
      {!isCollapsed ? (
        <div className="p-4 space-y-5 flex-1 overflow-y-auto">
          {/* Active Character Card */}
          <div className="p-3.5 rounded-2xl surface-raised border border-[var(--color-border-subtle)]">
            <div className="flex items-start justify-between gap-3 mb-2">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-bold text-[var(--color-text-primary)]">
                    {currentPersona.name}
                  </span>
                  <Badge variant="accent" size="sm">
                    Active
                  </Badge>
                </div>
                <span className="text-xs text-[var(--color-text-secondary)]">
                  {currentPersona.title}
                </span>
              </div>

              <StatusIndicator
                status={simulatingInference ? 'busy' : 'assistant'}
                size="md"
                showLabel={false}
              />
            </div>

            <p className="text-xs text-[var(--color-text-muted)] italic mb-3">
              &ldquo;{currentPersona.personality}&rdquo;
            </p>

            {/* Persona Switcher Chips */}
            <div className="flex gap-1.5 pt-2 border-t border-[var(--color-border-subtle)]">
              {mockAssistantPersonas.map((persona) => (
                <button
                  key={persona.id}
                  type="button"
                  onClick={() => {
                    setActivePersonaId(persona.id);
                    onSelectPersona?.(persona.id);
                  }}
                  className={`px-2.5 py-1 text-xs rounded-lg font-medium transition-all ${
                    persona.id === activePersonaId
                      ? 'bg-accent-gradient text-white shadow-sm'
                      : 'surface-recessed text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  {persona.name}
                </button>
              ))}
            </div>
          </div>

          {/* Compact Multilingual Status (Batch 12.1) */}
          <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
                <Globe className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                Language Engine
              </span>
              <span className="text-[10px] font-mono px-1.5 py-0.5 rounded-full bg-[var(--color-accent)]/10 text-[var(--color-accent)] font-semibold">
                Mixed-Enabled
              </span>
            </div>

            {/* Quick Language Target Selector */}
            <div className="grid grid-cols-4 gap-1 p-1 rounded-xl surface-base border border-[var(--color-border-subtle)] text-[10px] font-medium text-center">
              {[
                { id: 'auto' as const, label: 'Auto' },
                { id: 'en' as const, label: '🇺🇸 EN' },
                { id: 'fil' as const, label: '🇵🇭 FIL' },
                { id: 'ja' as const, label: '🇯🇵 JA' },
              ].map((l) => (
                <button
                  key={l.id}
                  type="button"
                  onClick={() => setPanelLangMode(l.id)}
                  className={`py-1 rounded-lg transition-all ${
                    panelLangMode === l.id
                      ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                      : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  {l.label}
                </button>
              ))}
            </div>

            <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] pt-0.5">
              <span>Code-Switch: Natural</span>
              <span>STT: Auto-Acoustic</span>
            </div>
          </div>

          {/* Assistant State Selector */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <span className="typo-label">Assistant State</span>
              <span className="text-[10px] font-mono capitalize text-[var(--color-accent)] font-semibold">
                {assistantState.replace('_', ' ')}
              </span>
            </div>
            <div className="grid grid-cols-4 gap-1 p-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[10px] font-medium text-center">
              {(
                [
                  { id: 'idle', label: 'Idle' },
                  { id: 'listening', label: 'Listen' },
                  { id: 'thinking', label: 'Think' },
                  { id: 'executing_tool', label: 'Tool' },
                  { id: 'speaking', label: 'Speak' },
                  { id: 'interrupted', label: 'Pause' },
                  { id: 'offline', label: 'Offline' },
                  { id: 'error', label: 'Error' },
                ] as const
              ).map((st) => (
                <button
                  key={st.id}
                  type="button"
                  onClick={() => updateAssistantState(st.id)}
                  className={`py-1 rounded-lg transition-all ${
                    assistantState === st.id
                      ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                      : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  {st.label}
                </button>
              ))}
            </div>
          </div>

          {/* Model Activity & Inference Monitor */}
          <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
                <Activity className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                Model Activity
              </span>
              <span className="font-mono text-[var(--color-accent)] font-semibold">
                {simulatingInference ? '38.4 t/s (Generating)' : 'Idle (0.0 t/s)'}
              </span>
            </div>

            <ProgressBar
              value={simulatingInference ? 84 : 12}
              size="sm"
              showValue={false}
              variant={simulatingInference ? 'accent' : 'success'}
            />

            <div className="flex justify-between items-center text-[11px] text-[var(--color-text-muted)] font-mono">
              <span>KV Cache: 3,840 / 16k</span>
              <span>Latency: 22ms</span>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="space-y-2">
            <span className="typo-label">Quick Actions</span>
            <div className="grid grid-cols-2 gap-2">
              <NeumorphicButton
                size="sm"
                icon={<Zap className="w-3.5 h-3.5 text-[var(--color-accent)]" />}
                onClick={handleTriggerInference}
                active={simulatingInference}
              >
                Run Inference
              </NeumorphicButton>

              <NeumorphicButton
                size="sm"
                icon={<RotateCcw className="w-3.5 h-3.5 text-[var(--color-text-secondary)]" />}
              >
                Clear Cache
              </NeumorphicButton>
            </div>
          </div>

          {/* Speech & Audio Controls */}
          <div className="p-3.5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
                {isMuted ? (
                  <MicOff className="w-3.5 h-3.5 text-[var(--color-danger)]" />
                ) : (
                  <Mic className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                )}
                Speech & Audio
              </span>
              <button
                type="button"
                onClick={() => setIsMuted(!isMuted)}
                className={`text-[10px] px-2 py-0.5 rounded-md font-mono transition-colors ${
                  isMuted
                    ? 'bg-rose-500/15 text-rose-500 font-bold'
                    : 'surface-recessed text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]'
                }`}
              >
                {isMuted ? 'Muted' : 'VAD On'}
              </button>
            </div>

            {/* Animated Waveform Equalizer */}
            <div className="h-8 flex items-center justify-center gap-1 px-2 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] overflow-hidden">
              {[40, 75, 50, 90, 60, 85, 30, 95, 45, 70, 55, 35].map((height, i) => (
                <span
                  key={i}
                  className={`w-1 rounded-full transition-all duration-300 ${
                    isMuted
                      ? 'h-1 bg-[var(--color-text-muted)]/30'
                      : 'bg-accent-gradient'
                  }`}
                  style={{
                    height: isMuted ? 4 : `${height}%`,
                    opacity: isMuted ? 0.3 : 0.85,
                  }}
                />
              ))}
            </div>

            <Slider
              value={micVolume}
              onChange={setMicVolume}
              min={0}
              max={100}
              label="Input Sensitivity"
              unit="%"
            />
          </div>

          {/* Telemetry / Recent Events */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="typo-label">Telemetry & Events</span>
              <Terminal className="w-3 h-3 text-[var(--color-text-muted)]" />
            </div>

            <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-2 font-mono text-[10px] max-h-36 overflow-y-auto">
              {mockActivityLogs.map((log) => (
                <div key={log.id} className="flex items-start gap-1.5 leading-tight">
                  <span className="text-[var(--color-text-muted)] flex-shrink-0">
                    [{log.time}]
                  </span>
                  <span className="text-[var(--color-accent)] flex-shrink-0">
                    {log.source}:
                  </span>
                  <span className="text-[var(--color-text-secondary)] truncate">
                    {log.message}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : (
        /* Collapsed Icon-Only Rail */
        <div className="flex-1 py-4 flex flex-col items-center justify-between space-y-4">
          <div className="space-y-3 flex flex-col items-center">
            {/* Active Character Quick Avatar */}
            <button
              type="button"
              onClick={() => onSetMode('expanded')}
              className="w-10 h-10 rounded-xl bg-accent-gradient text-white flex items-center justify-center font-bold text-xs shadow-md glow-accent-sm hover:scale-105 transition-transform"
              title={`Active Character: ${currentPersona.name} (${currentPersona.title})`}
            >
              {currentPersona.name.slice(0, 2)}
            </button>

            {/* Assistant State Pulse Indicator */}
            <div
              className="w-8 h-8 rounded-lg surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center cursor-pointer"
              onClick={() => onSetMode('expanded')}
              title={`State: ${assistantState}`}
            >
              <StatusIndicator
                status={simulatingInference ? 'busy' : 'assistant'}
                size="sm"
                showLabel={false}
              />
            </div>

            {/* Run Inference Trigger */}
            <button
              type="button"
              onClick={handleTriggerInference}
              className="w-8 h-8 rounded-lg surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-accent)] active:scale-95 transition-all"
              title="Run inference test"
            >
              <Zap className="w-4 h-4" />
            </button>

            {/* Mic / VAD Status */}
            <button
              type="button"
              onClick={() => setIsMuted(!isMuted)}
              className={`w-8 h-8 rounded-lg border flex items-center justify-center transition-all ${
                isMuted
                  ? 'border-rose-500/40 text-rose-500 bg-rose-500/10'
                  : 'surface-raised border-[var(--color-border-subtle)] text-[var(--color-accent)]'
              }`}
              title={isMuted ? 'Microphone muted' : 'Voice detection active'}
            >
              {isMuted ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
            </button>
          </div>

          <div className="flex flex-col items-center">
            <button
              type="button"
              onClick={() => onSetMode('expanded')}
              className="w-8 h-8 rounded-lg surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-center text-[var(--color-text-muted)] hover:text-[var(--color-accent)]"
              title="View telemetry logs"
            >
              <Terminal className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* 3. Footer */}
      {!isCollapsed && (
        <div className="p-3 border-t border-[var(--color-border-subtle)] text-center">
          <span className="text-[10px] text-[var(--color-text-muted)]">
            Local Core Loopback • 0ms Remote Latency
          </span>
        </div>
      )}
    </aside>
  );
};
