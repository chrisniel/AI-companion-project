import React from 'react';
import {
  X,
  Cpu,
  HardDrive,
  Layers,
  Database,
  Terminal,
  ShieldCheck,
  FileCode,
  Sliders,
  Check,
  Play,
  Cloud,
} from 'lucide-react';
import { Modal } from '../../ui/Modal';
import { Badge } from '../../ui/Badge';
import { LocalModel } from '../../../types';

interface ModelDetailsModalProps {
  model: LocalModel | null;
  isOpen: boolean;
  onClose: () => void;
  isActive: boolean;
  onActivate: (modelId: string) => void;
}

export const ModelDetailsModal: React.FC<ModelDetailsModalProps> = ({
  model,
  isOpen,
  onClose,
  isActive,
  onActivate,
}) => {
  if (!model) return null;

  const isCloud = model.isCloud || model.engine === 'gemini';

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={model.name}
      description={`${model.family} • ${model.parameters} parameters • ${model.quantization}`}
      maxWidth="lg"
      footer={
        <div className="flex items-center justify-between w-full">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 rounded-xl surface-recessed hover:surface-raised text-xs font-medium text-[var(--color-text-secondary)] transition-all"
          >
            Close
          </button>

          {!isActive ? (
            <button
              type="button"
              onClick={() => {
                onActivate(model.id);
                onClose();
              }}
              className="px-4 py-2 rounded-xl bg-accent-gradient text-white text-xs font-semibold flex items-center gap-1.5 shadow-md hover:opacity-90 transition-all"
            >
              <Play className="w-3.5 h-3.5 fill-current" />
              <span>Activate Model</span>
            </button>
          ) : (
            <Badge variant="accent" size="md">
              <Check className="w-3.5 h-3.5 mr-1" />
              Currently Active Model
            </Badge>
          )}
        </div>
      }
    >
      <div className="space-y-4 pt-2">
        {/* Top Summary Banner */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-start gap-3">
          <div
            className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${
              isCloud
                ? 'bg-violet-500/10 text-violet-500'
                : 'bg-[var(--color-accent)]/10 text-[var(--color-accent)]'
            }`}
          >
            {isCloud ? <Cloud className="w-5 h-5" /> : <Cpu className="w-5 h-5" />}
          </div>
          <div className="space-y-1">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-xs font-bold text-[var(--color-text-primary)]">
                {model.description || 'Description unavailable'}
              </span>
              {/* Variant badge */}
              {model.variant === 'thinking' && (
                <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-purple-500/20 text-purple-300 font-medium">
                  Thinking 🧠
                </span>
              )}
              {model.variant === 'instruct' && (
                <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-sky-500/20 text-sky-300 font-medium">
                  Instruct
                </span>
              )}
              {model.variant === 'base' && (
                <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-zinc-500/20 text-zinc-300 font-medium">
                  Base
                </span>
              )}
              {model.variant && model.variant !== 'thinking' && model.variant !== 'instruct' && model.variant !== 'base' && (
                <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-zinc-500/20 text-zinc-300 font-medium">
                  {model.variant.charAt(0).toUpperCase() + model.variant.slice(1)}
                </span>
              )}
              {/* Vision companion warning */}
              {(model.capabilities?.includes('vision') || model.hasCompanion) && !model.companionFilesValid && (
                <span
                  className="text-[10px] px-1.5 py-0.5 rounded-full bg-amber-500/20 text-amber-400 font-medium font-mono"
                  title="Vision companion missing: Text inference remains available, but vision features are unavailable."
                >
                  ⚠ Vision companion missing (Degraded)
                </span>
              )}
            </div>
            <div className="flex flex-wrap gap-2 text-[10px] text-[var(--color-text-muted)] font-mono">
              <span>License: {model.license || 'Unavailable'}</span>
              <span>•</span>
              <span>Format: {model.tensorType || 'Unavailable'}</span>
              <span>•</span>
              <span>Engine: {model.engine || 'Unavailable'}</span>
              <span>•</span>
              <span>Acceleration: {isCloud ? 'Cloud Managed' : 'Vulkan [Configured]'}</span>
            </div>
          </div>
        </div>

        {/* Technical Specs Breakdown */}
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5 text-xs font-mono">
          <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-0.5">
            <span className="text-[10px] text-[var(--color-text-muted)] block">Parameters</span>
            <span className="font-bold text-[var(--color-text-primary)]">{model.parameters}</span>
          </div>

          <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-0.5">
            <span className="text-[10px] text-[var(--color-text-muted)] block">Quantization</span>
            <span className="font-bold text-[var(--color-text-primary)]">{model.quantization}</span>
          </div>

          <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-0.5">
            <span className="text-[10px] text-[var(--color-text-muted)] block">Context Window</span>
            <span className="font-bold text-[var(--color-text-primary)]">
              {model.contextWindow.toLocaleString()} tokens
            </span>
          </div>

          <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-0.5">
            <span className="text-[10px] text-[var(--color-text-muted)] block">File Size</span>
            <span className="font-bold text-[var(--color-text-primary)]">
              {isCloud ? 'Remote' : (model.sizeGb != null && model.sizeGb > 0 ? `${model.sizeGb.toFixed(2)} GB [Configured]` : 'Unavailable')}
            </span>
          </div>

          <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-0.5">
            <span className="text-[10px] text-[var(--color-text-muted)] block">VRAM Footprint</span>
            <span className="font-bold text-[var(--color-text-primary)]">
              {isCloud ? 'N/A' : (model.vramUsageGb != null && model.vramUsageGb > 0 ? `~${model.vramUsageGb} GB [Estimated]` : 'Unavailable')}
            </span>
          </div>

          <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-0.5">
            <span className="text-[10px] text-[var(--color-text-muted)] block">GPU Offload</span>
            <span className="font-bold text-[var(--color-text-primary)]">
              {isCloud ? 'N/A' : (model.layersOffloaded != null ? `${model.layersOffloaded} layers [Applied]` : (model.layersTotal != null ? `${model.layersTotal} layers [Configured]` : 'Unavailable'))}
            </span>
          </div>
        </div>

        {/* Runtime & File Path */}
        <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-1 text-xs">
          <span className="text-[10px] uppercase font-mono tracking-wider text-[var(--color-text-muted)]">
            Local Weight Source / Endpoint
          </span>
          <div className="font-mono text-[11px] text-[var(--color-text-primary)] break-all bg-[var(--color-surface-elevated)] p-2 rounded-lg border border-[var(--color-border-subtle)]">
            {model.filePath || 'Unavailable'}
          </div>
        </div>

        {/* Recommended Inference Hyperparameters */}
        <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-2 text-xs">
          <div className="flex items-center justify-between">
            <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
              <Sliders className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              Recommended Sampling Presets
            </span>
            <span className="text-[10px] text-[var(--color-text-muted)] font-mono">Registry Specifications</span>
          </div>

          <div className="p-2.5 rounded-lg surface-recessed text-xs font-mono text-[var(--color-text-muted)] text-center">
            Sampling parameters: Not reported by registry
          </div>
        </div>
      </div>
    </Modal>
  );
};
