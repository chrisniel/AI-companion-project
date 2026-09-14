import React from 'react';
import {
  History,
  Cpu,
  ShieldCheck,
  AlertCircle,
  Globe,
  Plus,
  AlertTriangle,
} from 'lucide-react';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { ModelStatusResponse, RegistryEntry } from '../../../services/api';
import { AssistantState } from '../../../types';

export type TelemetryProvenance = 'Measured' | 'Configured' | 'Estimated' | 'Unavailable';

export interface AssistantStatusBarProps {
  conversationTitle: string;
  drawerConversationsCount: number;
  onOpenHistory: () => void;
  activeCharacterName: string;
  currentModelName?: string;
  isOnline: boolean;
  modelStatus: ModelStatusResponse | null | undefined;
  registry: RegistryEntry[];
  webSearchMode: 'airgapped' | 'web';
  onToggleWebSearch: () => void;
  onNewConversation: () => void;
  assistantState: AssistantState;
  onSetAssistantState: (state: AssistantState) => void;
}

export const AssistantStatusBar: React.FC<AssistantStatusBarProps> = ({
  conversationTitle,
  drawerConversationsCount,
  onOpenHistory,
  activeCharacterName,
  currentModelName,
  isOnline,
  modelStatus,
  registry,
  webSearchMode,
  onToggleWebSearch,
  onNewConversation,
  assistantState,
  onSetAssistantState,
}) => {
  // Authoritative runtime model identity from backend
  const activeModelId = modelStatus?.active_model || null;
  const activeModelEntry = registry.find(
    (m) => m.id === activeModelId || m.display_name === activeModelId
  );
  const effectiveModelName = isOnline
    ? (activeModelEntry ? activeModelEntry.display_name : (activeModelId || 'No Model Loaded'))
    : (currentModelName || 'Offline Demo');

  const isModelSleeping = isOnline && modelStatus?.runtime_state === 'MODEL_SLEEPING';
  const isModelAwake = isOnline && modelStatus?.runtime_state === 'MODEL_READY';
  const isModelUnloaded = isOnline && (!modelStatus?.model_loaded || modelStatus?.runtime_state === 'MODEL_UNLOADED');
  const isRouterOffline = isOnline && !modelStatus?.router_running;
  const isTransitioning = isOnline && (modelStatus?.runtime_state === 'SERVER_STARTING' || modelStatus?.runtime_state === 'MODEL_LOADING');

  // Profile pending restart check: requested_profile != applied_profile
  const isProfilePendingRestart = Boolean(
    isOnline &&
    modelStatus?.requested_profile &&
    modelStatus?.applied_profile &&
    modelStatus.requested_profile.trim().toLowerCase() !== modelStatus.applied_profile.trim().toLowerCase()
  );

  // Selected model vs active model awareness
  const isSelectedDifferentFromActive = Boolean(
    isOnline &&
    currentModelName &&
    activeModelId &&
    currentModelName !== activeModelId &&
    currentModelName !== activeModelEntry?.display_name
  );

  // Truthful runtime badge label (no fake CUDA)
  const providerLabel = isOnline
    ? (modelStatus?.applied_profile
        ? `llama.cpp (${modelStatus.applied_profile.toUpperCase()})`
        : (modelStatus?.provider || 'llama.cpp'))
    : 'Offline Mode';

  // Assistant State Status Label (authoritative runtime truth)
  const getAssistantStateDisplay = () => {
    if (!isOnline) {
      return { label: 'Offline', color: 'text-[var(--color-text-muted)]', desc: 'Core server offline — demo mode' };
    }
    if (isRouterOffline) {
      return { label: 'Router Stopped', color: 'text-amber-500', desc: 'Core online, llama.cpp router not running' };
    }
    if (isTransitioning) {
      return { label: 'Restarting / Loading', color: 'text-amber-500 animate-pulse', desc: 'Applying runtime changes' };
    }
    if (isModelSleeping) {
      return { label: 'Sleeping', color: 'text-purple-400', desc: 'Model sleeping in RAM (VRAM released)' };
    }
    if (isModelUnloaded) {
      return { label: 'No Model Loaded', color: 'text-amber-500', desc: 'Model weights unloaded from memory' };
    }

    switch (assistantState) {
      case 'idle':
        return { label: 'Idle / Standby', color: 'text-emerald-500', desc: 'Standing by for user query' };
      case 'listening':
        return { label: 'Listening (VAD Active)', color: 'text-sky-400 animate-pulse', desc: 'Streaming audio from microphone' };
      case 'thinking':
        return { label: 'Thinking / Reasoning', color: 'text-amber-500 animate-pulse', desc: 'Evaluating prompt tokens' };
      case 'executing_tool':
        return { label: 'Executing Tool', color: 'text-purple-400 animate-pulse', desc: 'Calling local workspace runtime' };
      case 'speaking':
        return { label: 'Speaking / Streaming', color: 'text-[var(--color-accent)] animate-pulse', desc: 'Synthesizing output tokens' };
      case 'interrupted':
        return { label: 'Interrupted', color: 'text-orange-400', desc: 'Generation halted by user' };
      case 'offline':
        return { label: 'Offline', color: 'text-[var(--color-text-muted)]', desc: 'Local engine disconnected' };
      case 'error':
        return { label: 'Error / OOM Notice', color: 'text-rose-500', desc: 'Context or VRAM overflow notice' };
      default:
        return { label: 'Idle', color: 'text-emerald-500', desc: 'Ready' };
    }
  };

  const stateDisplay = getAssistantStateDisplay();

  return (
    <div className="p-5 sm:p-6 rounded-3xl glass-panel-elevated border border-[var(--color-surface-glass-border)] space-y-4">
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        {/* Conversation Title & Drawer Trigger */}
        <div className="flex items-center gap-3 min-w-0">
          <button
            type="button"
            onClick={onOpenHistory}
            className="w-10 h-10 rounded-2xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-text-primary)] transition-all flex-shrink-0 relative group"
            title="Open Conversation History"
          >
            <History className="w-5 h-5 text-[var(--color-accent)] group-hover:scale-105 transition-transform" />
            <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-[var(--color-accent)] text-white text-[9px] font-bold flex items-center justify-center shadow-sm">
              {drawerConversationsCount}
            </span>
          </button>

          <div className="truncate">
            <div className="flex items-center gap-2">
              <h1 className="text-base sm:text-lg font-bold text-[var(--color-text-primary)] truncate">
                {conversationTitle}
              </h1>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] font-mono truncate">
              Active Persona: <strong className="text-[var(--color-text-primary)]">{activeCharacterName}</strong> • Low-Latency Loopback
            </p>
          </div>
        </div>

        {/* Model / Runtime / Mode Indicators & New Conversation */}
        <div className="flex flex-wrap items-center gap-2 flex-shrink-0">
          {/* Model Badge */}
          <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-mono text-[var(--color-text-primary)]">
            <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span className="font-semibold truncate max-w-[150px]" title={effectiveModelName}>
              {effectiveModelName}
            </span>
            {isOnline && isModelSleeping && (
              <span className="px-1.5 py-0.5 rounded bg-purple-500/20 text-purple-400 text-[10px] font-bold">
                Sleeping
              </span>
            )}
            {isOnline && isModelAwake && (
              <span className="px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 text-[10px] font-bold">
                Awake
              </span>
            )}
            {isOnline && isModelUnloaded && (
              <span className="px-1.5 py-0.5 rounded bg-amber-500/20 text-amber-400 text-[10px] font-bold">
                Unloaded
              </span>
            )}
          </div>

          {/* Selected Model indicator if selected != active model */}
          {isSelectedDifferentFromActive && (
            <div
              className="hidden xl:flex items-center gap-1 px-2 py-0.5 rounded-lg surface-recessed border border-[var(--color-border-subtle)] text-[10px] font-mono text-[var(--color-text-muted)]"
              title={`Selected in workspace: ${currentModelName}. Active in runtime: ${effectiveModelName}.`}
            >
              <span>Selected: {currentModelName}</span>
            </div>
          )}

          {/* Profile change pending restart indicator */}
          {isProfilePendingRestart && (
            <div
              className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl bg-amber-500/15 border border-amber-500/30 text-amber-400 text-xs font-mono font-bold"
              title={`Requested profile "${modelStatus?.requested_profile}" differs from active applied profile "${modelStatus?.applied_profile}". Restart runtime to apply.`}
            >
              <AlertTriangle className="w-3.5 h-3.5 flex-shrink-0" />
              <span>Profile change pending restart</span>
            </div>
          )}

          {/* Runtime / Provider */}
          <div className="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono text-[var(--color-text-secondary)]">
            <span>{providerLabel}</span>
          </div>

          {/* Local / Cloud Indicator */}
          <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono font-semibold">
            {isOnline ? (
              <>
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
                <span className="text-emerald-500 hidden md:inline">100% Local Airgapped</span>
                <span className="text-emerald-500 md:hidden">Local</span>
              </>
            ) : (
              <>
                <AlertCircle className="w-3.5 h-3.5 text-[var(--color-text-muted)]" />
                <span className="text-[var(--color-text-muted)]">Core Offline (Demo)</span>
              </>
            )}
          </div>

          {/* Search / Web Mode Indicator */}
          <button
            type="button"
            onClick={onToggleWebSearch}
            className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl border text-xs font-mono transition-all ${
              webSearchMode === 'airgapped'
                ? 'surface-raised border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                : 'bg-accent-gradient text-white border-[var(--color-accent)] shadow-sm'
            }`}
            title="Click to toggle between airgapped local docs and simulated web search"
          >
            <Globe className="w-3.5 h-3.5" />
            <span className="hidden lg:inline">
              {webSearchMode === 'airgapped' ? 'Search: Airgapped Docs' : 'Search: Web Simulated'}
            </span>
            <span className="lg:hidden">
              {webSearchMode === 'airgapped' ? 'Airgap Docs' : 'Web Mode'}
            </span>
          </button>

          {/* New Conversation Action */}
          <NeumorphicButton
            size="sm"
            variant="primary"
            icon={<Plus className="w-3.5 h-3.5 text-white" />}
            onClick={onNewConversation}
          >
            New Chat
          </NeumorphicButton>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 2. ASSISTANT VISUAL STATES BAR & PROVENANCE TELEMETRY      */}
      {/* ========================================================= */}
      <div className="pt-3 border-t border-[var(--color-border-subtle)] space-y-2">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs font-bold text-[var(--color-text-primary)] uppercase tracking-wider font-mono">
              Status:
            </span>
            <div className="flex items-center gap-2 px-2.5 py-0.5 rounded-lg surface-recessed border border-[var(--color-border-subtle)]">
              <span className={`text-xs font-bold font-mono ${stateDisplay.color}`}>
                ● {stateDisplay.label}
              </span>
              <span className="text-[11px] text-[var(--color-text-muted)] hidden sm:inline">
                — {stateDisplay.desc}
              </span>
            </div>
          </div>

          {/* Interactive Visual State Switcher Chips */}
          <div className="flex items-center gap-1 overflow-x-auto pb-1 md:pb-0">
            <span className="text-[10px] font-mono text-[var(--color-text-muted)] mr-1 flex-shrink-0">
              Mock State:
            </span>
            {(
              [
                { id: 'idle', label: 'Idle' },
                { id: 'listening', label: 'Listening' },
                { id: 'thinking', label: 'Thinking' },
                { id: 'executing_tool', label: 'Tool' },
                { id: 'speaking', label: 'Speaking' },
                { id: 'interrupted', label: 'Interrupted' },
                { id: 'offline', label: 'Offline' },
                { id: 'error', label: 'Error' },
              ] as const
            ).map((st) => (
              <button
                key={st.id}
                type="button"
                onClick={() => onSetAssistantState(st.id)}
                className={`px-2 py-0.5 rounded-lg text-[10px] font-mono font-medium transition-all flex-shrink-0 ${
                  assistantState === st.id
                    ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                    : 'surface-recessed text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                }`}
              >
                {st.label}
              </button>
            ))}
          </div>
        </div>

        {/* Truthful Telemetry Strip with Provenance */}
        {isOnline && modelStatus?.model_loaded && (
          <div className="flex flex-wrap items-center gap-2 pt-1 text-[11px] font-mono text-[var(--color-text-secondary)]">
            <span className="text-[10px] text-[var(--color-text-muted)] uppercase tracking-wider font-bold">
              Telemetry:
            </span>
            {modelStatus.applied_context_size != null ? (
              <span
                className="px-2 py-0.5 rounded-lg surface-recessed border border-[var(--color-border-subtle)]"
                title="Configured session context window"
              >
                Context: <strong className="text-[var(--color-text-primary)]">{modelStatus.applied_context_size} tok</strong>{' '}
                <span className="text-[9px] text-[var(--color-text-muted)] font-sans">(Configured)</span>
              </span>
            ) : null}
            {modelStatus.applied_gpu_layers != null ? (
              <span
                className="px-2 py-0.5 rounded-lg surface-recessed border border-[var(--color-border-subtle)]"
                title="Configured GPU offload layers"
              >
                Layers: <strong className="text-[var(--color-text-primary)]">{modelStatus.applied_gpu_layers}</strong>{' '}
                <span className="text-[9px] text-[var(--color-text-muted)] font-sans">(Configured)</span>
              </span>
            ) : null}
            {activeModelEntry?.size_gb != null ? (
              <span
                className="px-2 py-0.5 rounded-lg surface-recessed border border-[var(--color-border-subtle)]"
                title="Measured primary model file size on disk"
              >
                Disk Size: <strong className="text-[var(--color-text-primary)]">{activeModelEntry.size_gb} GB</strong>{' '}
                <span className="text-[9px] text-[var(--color-text-muted)] font-sans">(Measured)</span>
              </span>
            ) : null}
            {activeModelEntry?.estimated_vram_gb != null ? (
              <span
                className="px-2 py-0.5 rounded-lg surface-recessed border border-[var(--color-border-subtle)]"
                title="Estimated VRAM allocation from model registry hints"
              >
                Est. VRAM: <strong className="text-[var(--color-text-primary)]">~{activeModelEntry.estimated_vram_gb} GB</strong>{' '}
                <span className="text-[9px] text-[var(--color-text-muted)] font-sans">(Estimated)</span>
              </span>
            ) : null}
          </div>
        )}
      </div>
    </div>
  );
};
