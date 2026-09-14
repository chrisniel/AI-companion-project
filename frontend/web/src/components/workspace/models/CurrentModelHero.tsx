import React from 'react';
import {
  Cpu,
  Activity,
  HardDrive,
  Zap,
  Layers,
  Clock,
  CheckCircle2,
  Cloud,
  Terminal,
  Database,
  Info,
  Maximize2,
  Power,
  RefreshCw,
} from 'lucide-react';
import { Badge } from '../../ui/Badge';
import { Card } from '../../ui/Card';
import { LocalModel } from '../../../types';

interface CurrentModelHeroProps {
  model: LocalModel;
  isModelLoading?: boolean;
  onLoad?: (modelId: string) => void;
  onUnload?: (modelId: string) => void;
  onOpenDetails?: (model: LocalModel) => void;
  idleCountdownSeconds?: number | null;
  runtimeState?: string;
  modelStatus?: import('../../../services/api').ModelStatusResponse | null;
  activeModelId?: string | null;
}

export const CurrentModelHero: React.FC<CurrentModelHeroProps> = ({
  model,
  isModelLoading = false,
  onLoad,
  onUnload,
  onOpenDetails,
  idleCountdownSeconds,
  runtimeState,
  modelStatus,
  activeModelId,
}) => {
  const isCloud = model.isCloud || model.engine === 'gemini';
  const isThisModelActive = Boolean(activeModelId && model.id === activeModelId);
  const isLoaded = Boolean(isThisModelActive && modelStatus?.model_loaded);
  const isAwake = Boolean(isThisModelActive && modelStatus?.model_awake);
  const isSleeping = Boolean(isThisModelActive && modelStatus?.runtime_state === 'MODEL_SLEEPING');

  const getRuntimeBadge = () => {
    if (isCloud) {
      return {
        label: isLoaded ? 'Active & Ready' : 'Standby Cloud API',
        variant: isLoaded ? ('success' as const) : ('warning' as const),
        dotClass: isLoaded ? 'bg-emerald-500 animate-pulse' : 'bg-amber-500',
      };
    }
    // Only attribute active/loaded/sleeping runtime state if THIS model is actually the active model
    if (isThisModelActive) {
      if (isSleeping) {
        return { label: 'Loaded / Sleeping 💤', variant: 'accent' as const, dotClass: 'bg-purple-500' };
      }
      if (isLoaded) {
        return { label: 'Loaded / Awake', variant: 'success' as const, dotClass: 'bg-emerald-500 animate-pulse' };
      }
      if (runtimeState === 'MODEL_LOADING') {
        return { label: 'Loading…', variant: 'warning' as const, dotClass: 'bg-amber-500 animate-pulse' };
      }
      if (runtimeState === 'MODEL_UNLOADING') {
        return { label: 'Unloading…', variant: 'warning' as const, dotClass: 'bg-amber-500 animate-pulse' };
      }
      if (runtimeState === 'MODEL_ERROR') {
        return { label: 'Model Error ⚠️', variant: 'danger' as const, dotClass: 'bg-rose-500' };
      }
      return { label: 'Standby on Disk', variant: 'default' as const, dotClass: 'bg-zinc-500' };
    }

    // Selected model != active model: MUST never show Loaded / Awake / Sleeping
    if (activeModelId) {
      return {
        label: 'Selected / Not Active',
        variant: 'default' as const,
        dotClass: 'bg-zinc-500',
      };
    }

    // No model is active globally:
    switch (runtimeState) {
      case 'SERVER_STOPPED':
        return { label: 'Router Offline', variant: 'default' as const, dotClass: 'bg-zinc-500' };
      case 'SERVER_STARTING':
        return { label: 'Router Starting…', variant: 'warning' as const, dotClass: 'bg-amber-500 animate-pulse' };
      case 'SERVER_ERROR':
        return { label: 'Router Error ⚠️', variant: 'danger' as const, dotClass: 'bg-rose-500' };
      default:
        return {
          label: 'Selected / Not Active',
          variant: 'default' as const,
          dotClass: 'bg-zinc-500',
        };
    }
  };

  const runtimeBadge = getRuntimeBadge();

  // Context capacity: applied if loaded, else configured limit (usage metric not reported)
  const effectiveMaxContext = isLoaded && modelStatus?.applied_context_size
    ? modelStatus.applied_context_size
    : model.contextWindow;

  return (
    <Card
      id="current-model-hero-card"
      className="p-5 sm:p-6 surface-raised border border-[var(--color-border-subtle)] space-y-6 relative overflow-hidden"
    >
      {/* Subtle background ambient tint */}
      <div className="absolute top-0 right-0 w-80 h-80 bg-accent-gradient opacity-5 blur-3xl pointer-events-none rounded-full" />

      {/* Top Header Row: Model Title & Status Badges */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 relative z-10">
        <div className="flex items-start sm:items-center gap-3.5">
          <div
            className={`w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 shadow-sm ${
              isCloud
                ? 'bg-violet-500/10 dark:bg-violet-500/20 text-violet-500 border border-violet-500/30'
                : 'bg-[var(--color-accent)]/10 text-[var(--color-accent)] border border-[var(--color-accent)]/30'
            }`}
          >
            {isCloud ? (
              <Cloud className="w-6 h-6" />
            ) : (
              <Cpu className="w-6 h-6" />
            )}
          </div>

          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-lg sm:text-xl font-bold text-[var(--color-text-primary)]">
                {model.name}
              </h2>
              <Badge variant={isCloud ? 'accent' : 'default'} size="sm">
                {isCloud ? 'Cloud API' : 'Local (On-Device)'}
              </Badge>
              {/* Variant badge */}
              {model.variant === 'thinking' && (
                <span className="text-xs px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-300 font-medium">
                  Thinking 🧠
                </span>
              )}
              {model.variant === 'instruct' && (
                <span className="text-xs px-2 py-0.5 rounded-full bg-sky-500/20 text-sky-300 font-medium">
                  Instruct
                </span>
              )}
              {model.variant === 'base' && (
                <span className="text-xs px-2 py-0.5 rounded-full bg-zinc-500/20 text-zinc-300 font-medium">
                  Base
                </span>
              )}
              {model.variant && model.variant !== 'thinking' && model.variant !== 'instruct' && model.variant !== 'base' && (
                <span className="text-xs px-2 py-0.5 rounded-full bg-zinc-500/20 text-zinc-300 font-medium">
                  {model.variant.charAt(0).toUpperCase() + model.variant.slice(1)}
                </span>
              )}
              {/* Companion / Vision degradation warning */}
              {(model.capabilities?.includes('vision') || model.hasCompanion) && !model.companionFilesValid && (
                <span
                  className="text-xs px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-400 font-medium font-mono"
                  title="Vision companion missing: Text inference remains available, but vision features are unavailable."
                >
                  ⚠ Vision companion missing (Degraded)
                </span>
              )}
              <Badge variant={runtimeBadge.variant} size="sm">
                <span className={`w-1.5 h-1.5 rounded-full mr-1 ${runtimeBadge.dotClass}`} />
                {runtimeBadge.label}
              </Badge>
              {isLoaded && isSleeping && (
                <Badge variant="accent" size="sm">
                  <Clock className="w-3 h-3 mr-1 text-purple-300" />
                  Native Sleep (VRAM Released)
                </Badge>
              )}
              {isLoaded && !isSleeping && idleCountdownSeconds !== undefined && idleCountdownSeconds !== null && idleCountdownSeconds > 0 && (
                <Badge variant="default" size="sm">
                  <Clock className="w-3 h-3 mr-1 text-[var(--color-text-muted)]" />
                  Native sleep in ~{Math.floor(idleCountdownSeconds / 60)}m {idleCountdownSeconds % 60}s [Estimated]
                </Badge>
              )}
              {!isThisModelActive && activeModelId && (
                <Badge variant="default" size="sm">
                  Viewing Selected Model
                </Badge>
              )}
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-1">
              {model.family} • {model.parameters} parameters • {model.description || 'General instruction model'}
            </p>
          </div>
        </div>

        {/* Quick Action Buttons */}
        <div className="flex items-center gap-2 self-start lg:self-center">
          <button
            type="button"
            onClick={() => onOpenDetails?.(model)}
            className="px-3 py-1.5 rounded-xl surface-base border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/50 text-xs font-medium text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] flex items-center gap-1.5 transition-all shadow-sm"
          >
            <Info className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span>Details</span>
          </button>

          {!isCloud && isLoaded && (
            <button
              type="button"
              disabled={isModelLoading}
              onClick={() => onUnload?.(model.id)}
              className="px-3.5 py-1.5 rounded-xl surface-recessed border border-rose-500/30 hover:border-rose-500/60 text-xs font-semibold text-rose-500 hover:bg-rose-500/10 flex items-center gap-1.5 transition-all shadow-sm disabled:opacity-50"
              title="Release VRAM allocation back to GPU"
            >
              {isModelLoading ? (
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Power className="w-3.5 h-3.5" />
              )}
              <span>{isModelLoading ? 'Unloading...' : 'Unload VRAM'}</span>
            </button>
          )}

          {!isCloud && !isLoaded && (
            <button
              type="button"
              disabled={isModelLoading}
              onClick={() => onLoad?.(model.id)}
              className="px-3.5 py-1.5 rounded-xl bg-accent-gradient text-white hover:opacity-90 text-xs font-semibold flex items-center gap-1.5 transition-all shadow-sm disabled:opacity-50"
              title="Load model weights into VRAM for fast inference"
            >
              {isModelLoading ? (
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Zap className="w-3.5 h-3.5" />
              )}
              <span>{isModelLoading ? 'Loading VRAM...' : 'Load to VRAM'}</span>
            </button>
          )}
        </div>
      </div>

      {/* Grid of 8 Core Telemetry Metrics */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 relative z-10">
        {/* 1. Model Size */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <HardDrive className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span>Model Size</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)]">
            {isCloud ? 'Hosted' : (model.sizeGb != null && model.sizeGb > 0 ? `${model.sizeGb.toFixed(2)} GB` : 'Unavailable')}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            {model.parameters} [Configured]
          </div>
        </div>

        {/* 2. Quantization */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Layers className="w-3.5 h-3.5 text-indigo-400" />
            <span>Quantization</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)]">
            {model.quantization}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono truncate">
            {model.tensorType || 'Unavailable'} [Configured]
          </div>
        </div>

        {/* 3. Runtime Engine */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Terminal className="w-3.5 h-3.5 text-sky-400" />
            <span>Runtime</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)] truncate">
            {modelStatus?.router_running ? 'llama.cpp' : (isCloud ? 'Cloud API' : 'Router Offline')}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            {modelStatus?.router_running ? 'Vulkan Offload (Core) [Applied]' : 'Standby / Offline'}
          </div>
        </div>

        {/* 4. Estimated Latency / Speed */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Zap className="w-3.5 h-3.5 text-amber-400" />
            <span>Latency (TTFT)</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)]">
            Unavailable
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            Live metric not reported
          </div>
        </div>

        {/* 5. VRAM Footprint / Requirement */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Cpu className="w-3.5 h-3.5 text-violet-400" />
            <span>Estimated VRAM</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)]">
            {isCloud
              ? 'Cloud API'
              : isSleeping
              ? 'VRAM released'
              : !isLoaded
              ? 'Not loaded'
              : (model.vramUsageGb != null && model.vramUsageGb > 0
                  ? `~${model.vramUsageGb.toFixed(1)} GB [Estimated]`
                  : 'Unavailable')}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            {isCloud
              ? 'Cloud Managed'
              : isSleeping
              ? 'VRAM Released (Sleeping) [Applied]'
              : isLoaded
              ? (modelStatus?.applied_gpu_layers !== null && modelStatus?.applied_gpu_layers !== undefined
                  ? `${modelStatus.applied_gpu_layers} layers GPU [Applied]`
                  : 'GPU Offload: Unavailable')
              : 'Unloaded from VRAM'}
          </div>
        </div>

        {/* 6. RAM Requirement */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Database className="w-3.5 h-3.5 text-teal-400" />
            <span>Estimated RAM</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)]">
            {model.ramUsageGb != null && model.ramUsageGb > 0
              ? `~${model.ramUsageGb.toFixed(1)} GB [Estimated]`
              : 'Unavailable'}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            Host Overhead [Estimated]
          </div>
        </div>

        {/* 7. Context Window Capacity */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1 col-span-2 sm:col-span-2">
          <div className="flex items-center justify-between text-[11px]">
            <span className="text-[var(--color-text-muted)] font-medium flex items-center gap-1.5">
              <Activity className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              Context Allocation
            </span>
            <span className="font-mono text-xs text-[var(--color-text-secondary)]">
              {isLoaded
                ? `${effectiveMaxContext.toLocaleString()} tokens [Applied]`
                : `${model.contextWindow.toLocaleString()} tokens [Configured]`}
            </span>
          </div>

          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] font-mono pt-1">
            <span>KV Cache: Unavailable (Live metric not reported)</span>
            <span>{isLoaded && isAwake ? 'Ready for input' : 'Standby'}</span>
          </div>
        </div>
      </div>
    </Card>
  );
};
