import React from 'react';
import {
  Sparkles,
  Bot,
  Cpu,
  MicOff,
  ChevronRight,
} from 'lucide-react';
import { useBackend } from '../../context/BackendContext';
import { Badge } from '../ui/Badge';
import { StatusIndicator } from '../ui/StatusIndicator';
import { AssistantPanelMode, AssistantState } from '../../types';

export interface AssistantPanelProps {
  mode: AssistantPanelMode;
  onSetMode: (mode: AssistantPanelMode) => void;
  onOpenAssistant?: () => void;
  selectedPersonaId?: string;
  onSelectPersona?: (id: string) => void;
  assistantState?: AssistantState;
  onSetAssistantState?: (state: AssistantState) => void;
}

export const AssistantPanel: React.FC<AssistantPanelProps> = ({
  mode,
  onSetMode,
  onOpenAssistant,
  assistantState = 'idle',
}) => {
  const { isOnline, modelStatus, registry } = useBackend();

  if (mode === 'hidden') return null;

  const isCollapsed = mode === 'collapsed';

  // Authoritative runtime model identity
  const activeModelId = isOnline && modelStatus?.model_loaded ? (modelStatus?.active_model ?? null) : null;
  const activeRegistryEntry = activeModelId ? registry.find((m) => m.id === activeModelId) : null;
  const activeModelDisplay = activeRegistryEntry?.display_name || activeModelId || (isOnline ? 'No Model Loaded' : 'Unavailable');

  const runtimeState = isOnline ? (modelStatus?.runtime_state || 'Unknown') : 'Offline';
  const appliedLayers = isOnline && modelStatus?.applied_gpu_layers !== undefined
    ? `${modelStatus.applied_gpu_layers} [Applied]`
    : 'Unavailable';

  const appliedProfile = isOnline && modelStatus?.applied_profile
    ? `${modelStatus.applied_profile} [Applied]`
    : isOnline && modelStatus?.requested_profile
    ? `${modelStatus.requested_profile} [Requested]`
    : 'Unavailable';

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
              title="Click to collapse panel"
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
                {isOnline ? 'Core Online' : 'Core Offline'} • UI: {assistantState}
              </p>
            </div>
          </div>
        ) : (
          <div className="w-full flex justify-center">
            <button
              type="button"
              onClick={() => onSetMode('expanded')}
              className="w-8 h-8 rounded-xl bg-accent-gradient text-white flex items-center justify-center shadow-md glow-accent-sm cursor-pointer hover:opacity-90 active:scale-95 transition-all"
              title="Click to expand panel"
            >
              <Sparkles className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>

      {/* 2. Main Content */}
      {!isCollapsed ? (
        <div className="p-4 space-y-5 flex-1 overflow-y-auto">
          {/* Neutral Assistant Companion Card */}
          <div className="p-3.5 rounded-2xl surface-raised border border-[var(--color-border-subtle)]">
            <div className="flex items-start justify-between gap-3 mb-2">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-bold text-[var(--color-text-primary)]">
                    Assistant
                  </span>
                  <Badge variant={isOnline ? 'accent' : 'glass'} size="sm">
                    {isOnline ? 'Connected' : 'Offline'}
                  </Badge>
                </div>
                <span className="text-xs text-[var(--color-text-secondary)]">
                  Local AI Companion Workspace
                </span>
              </div>

              <StatusIndicator
                status={isOnline ? 'assistant' : 'offline'}
                size="md"
                showLabel={false}
              />
            </div>

            <p className="text-xs text-[var(--color-text-muted)] italic mb-3">
              Conversational reasoning and tool orchestration via Local AI Core.
            </p>

            {onOpenAssistant && (
              <button
                type="button"
                onClick={onOpenAssistant}
                className="w-full flex items-center justify-center gap-1.5 py-1.5 px-3 rounded-xl bg-accent-gradient text-white text-xs font-semibold shadow-sm hover:opacity-90 active:scale-95 transition-all cursor-pointer"
              >
                <span>Open Assistant Workspace</span>
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            )}
          </div>

          {/* Authoritative Runtime Status Card */}
          <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2.5">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
                <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                Runtime Telemetry
              </span>
              <span className="text-[10px] font-mono px-1.5 py-0.5 rounded-full bg-[var(--color-surface-secondary)] text-[var(--color-text-secondary)] font-semibold">
                {isOnline ? 'Live Backend' : 'Offline'}
              </span>
            </div>

            <div className="space-y-1.5 text-xs font-mono">
              <div className="flex justify-between items-center text-[11px]">
                <span className="text-[var(--color-text-muted)]">Core Status:</span>
                <span className={isOnline ? 'text-emerald-500 font-semibold' : 'text-rose-400 font-semibold'}>
                  {isOnline ? 'Online (Port 8000)' : 'Offline'}
                </span>
              </div>
              <div className="flex justify-between items-center text-[11px]">
                <span className="text-[var(--color-text-muted)]">Active Model:</span>
                <span className="text-[var(--color-text-primary)] font-semibold truncate max-w-[170px]">
                  {activeModelDisplay}
                </span>
              </div>
              <div className="flex justify-between items-center text-[11px]">
                <span className="text-[var(--color-text-muted)]">Runtime State:</span>
                <span className="text-[var(--color-accent)]">{runtimeState}</span>
              </div>
              <div className="flex justify-between items-center text-[11px]">
                <span className="text-[var(--color-text-muted)]">GPU Offload:</span>
                <span className="text-[var(--color-text-secondary)]">{appliedLayers}</span>
              </div>
              <div className="flex justify-between items-center text-[11px]">
                <span className="text-[var(--color-text-muted)]">Profile:</span>
                <span className="text-[var(--color-text-secondary)]">{appliedProfile}</span>
              </div>
            </div>
          </div>

          {/* Client Session UI State (Truthfully Labeled) */}
          <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-[var(--color-text-primary)]">
                Client Session State
              </span>
              <span className="text-[10px] font-mono capitalize text-[var(--color-accent)] font-semibold">
                {assistantState.replace('_', ' ')}
              </span>
            </div>
            <p className="text-[11px] text-[var(--color-text-muted)] leading-relaxed">
              Derived from active chat stream session. No simulated overrides.
            </p>
          </div>

          {/* Speech & Audio (Truthfully Planned) */}
          <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
                <MicOff className="w-3.5 h-3.5 text-[var(--color-text-muted)]" />
                Speech & Audio
              </span>
              <Badge variant="glass" size="sm">
                Planned
              </Badge>
            </div>
            <p className="text-[11px] text-[var(--color-text-muted)] leading-relaxed">
              Voice input not connected. On-device microphone capture and speech synthesis will be integrated in a subsequent phase.
            </p>
          </div>
        </div>
      ) : (
        /* Collapsed Icon-Only Rail */
        <div className="flex-1 py-4 flex flex-col items-center justify-between space-y-4">
          <div className="space-y-3 flex flex-col items-center">
            {/* Quick Avatar */}
            <button
              type="button"
              onClick={() => onSetMode('expanded')}
              className="w-10 h-10 rounded-xl bg-accent-gradient text-white flex items-center justify-center font-bold text-xs shadow-md glow-accent-sm hover:scale-105 transition-transform cursor-pointer"
              title="Assistant Panel — Click to expand"
            >
              <Bot className="w-5 h-5" />
            </button>

            {/* Core Status Indicator */}
            <div
              className="w-8 h-8 rounded-lg surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center cursor-pointer"
              onClick={() => onSetMode('expanded')}
              title={`Runtime: ${isOnline ? 'Online' : 'Offline'}`}
            >
              <StatusIndicator
                status={isOnline ? 'online' : 'offline'}
                size="sm"
                showLabel={false}
              />
            </div>

            {/* Navigation Button */}
            {onOpenAssistant && (
              <button
                type="button"
                onClick={onOpenAssistant}
                className="w-8 h-8 rounded-lg surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-accent)] active:scale-95 transition-all cursor-pointer"
                title="Open Assistant Workspace"
              >
                <Sparkles className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      )}

      {/* 3. Footer */}
      {!isCollapsed && (
        <div className="p-3 border-t border-[var(--color-border-subtle)] text-center">
          <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
            Local AI Companion Panel • Truthful Runtime Status
          </span>
        </div>
      )}
    </aside>
  );
};
