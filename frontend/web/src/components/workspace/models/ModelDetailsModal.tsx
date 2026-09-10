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
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-[var(--color-text-primary)]">
                {model.description || 'Instruction-tuned transformer model'}
              </span>
            </div>
            <div className="flex flex-wrap gap-2 text-[10px] text-[var(--color-text-muted)] font-mono">
              <span>License: {model.license || 'Open Source'}</span>
              <span>•</span>
              <span>Engine: {model.engine}</span>
              <span>•</span>
              <span>Format: {model.tensorType || 'GGUF v3'}</span>
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
              {isCloud ? 'Remote' : `${model.sizeGb.toFixed(2)} GB`}
            </span>
          </div>

          <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-0.5">
            <span className="text-[10px] text-[var(--color-text-muted)] block">VRAM Footprint</span>
            <span className="font-bold text-[var(--color-text-primary)]">
              {isCloud ? '0.0 GB' : `${model.vramUsageGb || 4.9} GB`}
            </span>
          </div>

          <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-0.5">
            <span className="text-[10px] text-[var(--color-text-muted)] block">GPU Offload</span>
            <span className="font-bold text-[var(--color-text-primary)]">
              {isCloud ? 'N/A' : `${model.layersOffloaded || 33} / ${model.layersTotal || 33} layers`}
            </span>
          </div>
        </div>

        {/* Runtime & File Path */}
        <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-1 text-xs">
          <span className="text-[10px] uppercase font-mono tracking-wider text-[var(--color-text-muted)]">
            Local Weight Source / Endpoint
          </span>
          <div className="font-mono text-[11px] text-[var(--color-text-primary)] break-all bg-[var(--color-surface-elevated)] p-2 rounded-lg border border-[var(--color-border-subtle)]">
            {model.filePath || `~/.local/share/models/gguf/${model.name}.gguf`}
          </div>
        </div>

        {/* Recommended Inference Hyperparameters */}
        <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] space-y-2 text-xs">
          <div className="flex items-center justify-between">
            <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
              <Sliders className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              Recommended Sampling Presets
            </span>
            <span className="text-[10px] text-[var(--color-text-muted)] font-mono">Modelfile Defaults</span>
          </div>

          <div className="grid grid-cols-3 gap-2 text-center text-xs font-mono">
            <div className="p-2 rounded-lg surface-recessed">
              <span className="text-[10px] text-[var(--color-text-muted)] block">Temperature</span>
              <span className="font-bold text-[var(--color-text-primary)]">0.7</span>
            </div>
            <div className="p-2 rounded-lg surface-recessed">
              <span className="text-[10px] text-[var(--color-text-muted)] block">Top-P</span>
              <span className="font-bold text-[var(--color-text-primary)]">0.9</span>
            </div>
            <div className="p-2 rounded-lg surface-recessed">
              <span className="text-[10px] text-[var(--color-text-muted)] block">Repeat Penalty</span>
              <span className="font-bold text-[var(--color-text-primary)]">1.1</span>
            </div>
          </div>
        </div>
      </div>
    </Modal>
  );
};
