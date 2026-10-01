import React from 'react';
import {
  History,
  Cpu,
  ShieldCheck,
  AlertCircle,
  Plus,
  AlertTriangle,
} from 'lucide-react';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import {
  ModelStatusResponse,
  RegistryEntry,
  getRegistryEntryDisplayName,
  registryEntryMatchesIdentifier,
} from '../../../services/api';
import { AssistantState } from '../../../types';

export type TelemetryProvenance = 'Configured' | 'Estimated' | 'Unavailable';

export interface AssistantStatusBarProps {
  conversationTitle: string;
  drawerConversationsCount: number;
  onOpenHistory: () => void;
  activeCharacterName: string;
  currentModelName?: string;
  isOnline: boolean;
  modelStatus: ModelStatusResponse | null | undefined;
  registry: RegistryEntry[];
  onNewConversation: () => void;
  assistantState: AssistantState;
  isNewConversationDisabled?: boolean;
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
  onNewConversation,
  assistantState,
  isNewConversationDisabled = false,
}) => {
  // Authoritative runtime model identity from backend
  const activeModelId = modelStatus?.active_model || null;
  const activeModelEntry = activeModelId
    ? registry.find((m) => registryEntryMatchesIdentifier(m, activeModelId))
    : null;
  const effectiveModelName = isOnline
    ? (activeModelEntry ? getRegistryEntryDisplayName(activeModelEntry) : (activeModelId || 'No Model Loaded'))
    : 'Runtime Offline';

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
    currentModelName !== (activeModelEntry ? getRegistryEntryDisplayName(activeModelEntry) : undefined)
  );

  // Truthful runtime badge label (backend truth only, no hardcoded llama.cpp)
  const providerLabel = isOnline && modelStatus?.provider?.trim()
    ? modelStatus.provider
    : 'Unavailable';

  // Assistant State Status Label (authoritative runtime truth from client/SSE state)
  const getAssistantStateDisplay = () => {
    if (!isOnline) {
      return { label: 'Offline', color: 'text-[var(--color-text-muted)]', desc: 'Runtime server offline' };
    }
    if (isRouterOffline) {
      return { label: 'Router Stopped', color: 'text-amber-500', desc: 'Runtime online, llama.cpp router not running' };
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
        return {
          label: 'Listening (Preview / Stub)',
          color: 'text-sky-400 animate-pulse',
          desc: 'Voice input not connected — STT planned',
        };
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
        return { label: 'Error', color: 'text-rose-500', desc: 'Runtime error encountered' };
      default:
        return { label: 'Idle', color: 'text-emerald-500', desc: 'Ready' };
    }
  };

  const stateDisplay = getAssistantStateDisplay();

  return (
    <div className="px-4 py-3 rounded-2xl glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-3">
        {/* Left: Conversation Title & Drawer Trigger */}
        <div className="flex items-center gap-3 min-w-0">
          <button
            type="button"
            onClick={onOpenHistory}
            className="w-9 h-9 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-text-primary)] transition-all flex-shrink-0 relative group"
            title="Open Conversation History"
          >
            <History className="w-4 h-4 text-[var(--color-accent)] group-hover:scale-105 transition-transform" />
            <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-[var(--color-accent)] text-white text-[9px] font-bold flex items-center justify-center shadow-sm">
              {drawerConversationsCount}
            </span>
          </button>

          <div className="min-w-0">
            <h1 className="text-sm sm:text-base font-bold text-[var(--color-text-primary)] truncate max-w-[200px] sm:max-w-xs md:max-w-md">
              {conversationTitle}
            </h1>
            <p className="text-[11px] text-[var(--color-text-secondary)] font-mono truncate">
              Active Persona: <strong className="text-[var(--color-text-primary)]">{activeCharacterName}</strong>
            </p>
          </div>
        </div>

        {/* Right: Model / Status Indicators & New Conversation Action */}
        <div className="flex items-center gap-2 flex-shrink-0">
          {/* Model Badge */}
          <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-mono text-[var(--color-text-primary)]">
            <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span className="font-semibold truncate max-w-[130px] sm:max-w-[180px]" title={effectiveModelName}>
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

          {/* Profile change pending restart indicator */}
          {isProfilePendingRestart && (
            <div
              className="hidden lg:flex items-center gap-1.5 px-2 py-1 rounded-xl bg-amber-500/15 border border-amber-500/30 text-amber-400 text-xs font-mono font-bold"
              title={`Requested profile "${modelStatus?.requested_profile}" differs from active applied profile "${modelStatus?.applied_profile}". Restart runtime to apply.`}
            >
              <AlertTriangle className="w-3.5 h-3.5 flex-shrink-0" />
              <span>Profile change pending restart</span>
            </div>
          )}

          {/* Provider Label */}
          <div className="hidden xl:flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono text-[var(--color-text-secondary)]">
            <span>{providerLabel}</span>
          </div>

          {/* State Display Pill */}
          <div className="hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono">
            <span className={stateDisplay.color}>● {stateDisplay.label}</span>
          </div>

          {/* New Conversation Action */}
          <NeumorphicButton
            size="sm"
            variant="primary"
            icon={<Plus className="w-3.5 h-3.5 text-white" />}
            onClick={() => {
              if (isNewConversationDisabled) return;
              onNewConversation();
            }}
            disabled={isNewConversationDisabled}
          >
            New Chat
          </NeumorphicButton>
        </div>
      </div>
    </div>
  );
};
