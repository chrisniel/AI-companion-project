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
}

export const CurrentModelHero: React.FC<CurrentModelHeroProps> = ({
  model,
  isModelLoading = false,
  onLoad,
  onUnload,
  onOpenDetails,
  idleCountdownSeconds,
}) => {
  const isCloud = model.isCloud || model.engine === 'gemini';
  const isLoaded = model.status === 'loaded';

  // Context calculations (active tokens only allocated when model is pinned in VRAM)
  const activeTokens = isLoaded ? Math.min(3840, model.contextWindow) : 0;
  const contextPercentage = isLoaded && model.contextWindow > 0
    ? Math.min(Math.round((activeTokens / model.contextWindow) * 100), 100)
    : 0;

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
              <Badge variant={isLoaded ? 'success' : 'warning'} size="sm">
                <span className={`w-1.5 h-1.5 rounded-full mr-1 ${isLoaded ? 'bg-emerald-500 animate-pulse' : 'bg-amber-500'}`} />
                {isLoaded
                  ? isCloud
                    ? 'Active & Ready'
                    : 'Pinned in VRAM'
                  : 'Standby on Disk (VRAM Free)'}
              </Badge>
              {isLoaded && idleCountdownSeconds !== undefined && idleCountdownSeconds !== null && (
                <Badge variant="default" size="sm">
                  <Clock className="w-3 h-3 mr-1 text-[var(--color-text-muted)]" />
                  Auto-unload in {Math.floor(idleCountdownSeconds / 60)}m {idleCountdownSeconds % 60}s
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
              className="px-3.5 py-1.5 rounded-xl bg-emerald-500/15 border border-emerald-500/40 hover:border-emerald-500/80 text-xs font-semibold text-emerald-500 hover:bg-emerald-500/25 flex items-center gap-1.5 transition-all shadow-sm disabled:opacity-50"
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
            {isCloud ? 'Hosted' : `${model.sizeGb.toFixed(2)} GB`}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            {model.parameters}
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
            {model.tensorType || 'GGUF v3'}
          </div>
        </div>

        {/* 3. Runtime Engine */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Terminal className="w-3.5 h-3.5 text-sky-400" />
            <span>Runtime</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)] truncate">
            {model.engine}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            {isCloud ? 'Cloud GenAI' : 'Vulkan Offload (AMD RX 580)'}
          </div>
        </div>

        {/* 4. Estimated Latency / Speed */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Zap className="w-3.5 h-3.5 text-amber-400" />
            <span>Latency (TTFT)</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)]">
            {isLoaded ? (model.estimatedLatencyMs || 18) : 0} ms
          </div>
          <div className="text-[10px] text-emerald-500 font-mono">
            {isLoaded ? (model.tokensPerSec ? `${model.tokensPerSec} t/s` : '42.8 t/s') : 'Standby'}
          </div>
        </div>

        {/* 5. VRAM Usage */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Cpu className="w-3.5 h-3.5 text-violet-400" />
            <span>VRAM Usage</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)]">
            {isCloud ? '0.0 GB' : isLoaded ? `${(model.vramUsageGb || 4.5).toFixed(1)} GB` : '0.0 GB'}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            {isCloud ? 'Remote Server' : isLoaded ? `${model.layersOffloaded || 28}/${model.layersTotal || 28} layers GPU` : '0/28 layers (VRAM Free)'}
          </div>
        </div>

        {/* 6. RAM Usage */}
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1">
          <div className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] font-medium">
            <Database className="w-3.5 h-3.5 text-teal-400" />
            <span>System RAM</span>
          </div>
          <div className="text-base sm:text-lg font-bold font-mono text-[var(--color-text-primary)]">
            {model.ramUsageGb ? `${model.ramUsageGb} GB` : '1.4 GB'}
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] font-mono">
            Host Overhead
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
              {activeTokens.toLocaleString()} / {model.contextWindow.toLocaleString()} tokens
            </span>
          </div>

          <div className="w-full h-2 rounded-full surface-recessed border border-[var(--color-border-subtle)] overflow-hidden mt-2">
            <div
              className="h-full bg-accent-gradient rounded-full transition-all duration-300"
              style={{ width: `${contextPercentage}%` }}
            />
          </div>

          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] font-mono pt-0.5">
            <span>KV Cache: {isCloud ? 'Cloud Managed' : isLoaded ? '1.2 GB' : '0.0 GB'}</span>
            <span>{contextPercentage}% in use</span>
          </div>
        </div>
      </div>
    </Card>
  );
};
