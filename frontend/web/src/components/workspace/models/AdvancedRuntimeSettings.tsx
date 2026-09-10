import React, { useState } from 'react';
import {
  ChevronDown,
  ChevronRight,
  Sliders,
  Cpu,
  Zap,
  Layers,
  Clock,
  Settings,
  HardDrive,
  Info,
} from 'lucide-react';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';
import { Toggle } from '../../ui/Toggle';

export const AdvancedRuntimeSettings: React.FC = () => {
  const [isOpen, setIsOpen] = useState(false);

  // Technical runtime state (mock UI-only)
  const [gpuLayers, setGpuLayers] = useState(33);
  const [cpuThreads, setCpuThreads] = useState(8);
  const [flashAttention, setFlashAttention] = useState(true);
  const [kvCacheQuant, setKvCacheQuant] = useState<'fp16' | 'q8_0' | 'q4_0'>('q8_0');
  const [contextShift, setContextShift] = useState(true);
  const [batchSize, setBatchSize] = useState<'512' | '1024' | '2048'>('512');
  const [keepAlive, setKeepAlive] = useState<'5m' | '30m' | 'forever'>('30m');

  return (
    <Card id="advanced-runtime-settings-card" className="p-0 overflow-hidden">
      {/* Collapsible Header Accordion */}
      <button
        type="button"
        id="advanced-settings-toggle-btn"
        onClick={() => setIsOpen(!isOpen)}
        className="w-full p-4 sm:p-5 flex items-center justify-between text-left select-none hover:bg-[var(--color-surface-recessed)]/50 transition-colors"
      >
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl surface-recessed flex items-center justify-center text-[var(--color-text-secondary)]">
            <Settings className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-sm font-semibold text-[var(--color-text-primary)]">
                Advanced Technical Runtime Settings
              </h2>
              <Badge variant="default" size="sm">
                Optional
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-muted)] mt-0.5">
              Fine-tune GPU layer offloading, FlashAttention, KV quantization, and thread affinity.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 text-xs font-mono text-[var(--color-text-muted)]">
          <span>{isOpen ? 'Collapse' : 'Expand'}</span>
          {isOpen ? (
            <ChevronDown className="w-4 h-4 text-[var(--color-text-secondary)]" />
          ) : (
            <ChevronRight className="w-4 h-4 text-[var(--color-text-secondary)]" />
          )}
        </div>
      </button>

      {/* Expandable Body */}
      {isOpen && (
        <div className="p-4 sm:p-6 border-t border-[var(--color-border-subtle)] space-y-5 bg-[var(--color-surface-recessed)]/30">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* 1. GPU Layers Offload */}
            <div className="p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2.5">
              <div className="flex items-center justify-between text-xs">
                <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
                  <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                  GPU Layer Offloading
                </span>
                <span className="font-mono text-[var(--color-accent)] font-bold">
                  {gpuLayers} / 33 layers
                </span>
              </div>
              <p className="text-[11px] text-[var(--color-text-muted)]">
                Number of transformer weight layers loaded onto CUDA cores rather than CPU RAM.
              </p>
              <input
                type="range"
                min={0}
                max={33}
                value={gpuLayers}
                onChange={(e) => setGpuLayers(Number(e.target.value))}
                className="w-full accent-[var(--color-accent)] cursor-pointer"
              />
              <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] font-mono">
                <span>0 (CPU Only)</span>
                <span>16 (Hybrid)</span>
                <span>33 (Full VRAM)</span>
              </div>
            </div>

            {/* 2. CPU Thread Allocation */}
            <div className="p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2.5">
              <div className="flex items-center justify-between text-xs">
                <span className="font-semibold text-[var(--color-text-primary)] flex items-center gap-1.5">
                  <Zap className="w-3.5 h-3.5 text-amber-500" />
                  CPU Ingestion Threads
                </span>
                <span className="font-mono text-[var(--color-accent)] font-bold">
                  {cpuThreads} Threads
                </span>
              </div>
              <p className="text-[11px] text-[var(--color-text-muted)]">
                Dedicated worker threads for initial prompt evaluation and tokenizer token ingestion.
              </p>
              <input
                type="range"
                min={2}
                max={16}
                step={2}
                value={cpuThreads}
                onChange={(e) => setCpuThreads(Number(e.target.value))}
                className="w-full accent-[var(--color-accent)] cursor-pointer"
              />
              <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] font-mono">
                <span>2 Threads (Eco)</span>
                <span>8 Threads (Optimal)</span>
                <span>16 Threads (Max)</span>
              </div>
            </div>

            {/* 3. KV Cache Quantization */}
            <div className="p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2.5">
              <span className="font-semibold text-xs text-[var(--color-text-primary)] flex items-center gap-1.5">
                <Layers className="w-3.5 h-3.5 text-indigo-400" />
                KV Cache Precision
              </span>
              <p className="text-[11px] text-[var(--color-text-muted)]">
                Compresses conversational context memory buffer to dramatically reduce VRAM spikes.
              </p>
              <div className="grid grid-cols-3 gap-2 pt-1 font-mono text-xs">
                {(['fp16', 'q8_0', 'q4_0'] as const).map((q) => (
                  <button
                    key={q}
                    type="button"
                    onClick={() => setKvCacheQuant(q)}
                    className={`py-1.5 px-2 rounded-xl text-center transition-all ${
                      kvCacheQuant === q
                        ? 'surface-raised font-bold text-[var(--color-accent)] border border-[var(--color-accent)]/50 shadow-sm'
                        : 'surface-recessed text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                    }`}
                  >
                    {q.toUpperCase()}
                  </button>
                ))}
              </div>
            </div>

            {/* 4. Batch Size */}
            <div className="p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2.5">
              <span className="font-semibold text-xs text-[var(--color-text-primary)] flex items-center gap-1.5">
                <HardDrive className="w-3.5 h-3.5 text-teal-400" />
                Prompt Evaluation Batch Size
              </span>
              <p className="text-[11px] text-[var(--color-text-muted)]">
                Parallel token chunking size for processing long document inputs and system prompt preambles.
              </p>
              <div className="grid grid-cols-3 gap-2 pt-1 font-mono text-xs">
                {(['512', '1024', '2048'] as const).map((b) => (
                  <button
                    key={b}
                    type="button"
                    onClick={() => setBatchSize(b)}
                    className={`py-1.5 px-2 rounded-xl text-center transition-all ${
                      batchSize === b
                        ? 'surface-raised font-bold text-[var(--color-accent)] border border-[var(--color-accent)]/50 shadow-sm'
                        : 'surface-recessed text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                    }`}
                  >
                    {b} Tokens
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Additional Toggles */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5 pt-2 border-t border-[var(--color-border-subtle)]">
            <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] flex items-center justify-between">
              <div>
                <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                  Flash Attention 2 Kernel
                </span>
                <span className="text-[11px] text-[var(--color-text-muted)]">
                  Accelerate attention calculation via fused GPU operations.
                </span>
              </div>
              <Toggle
                id="toggle-flash-attention"
                checked={flashAttention}
                onChange={setFlashAttention}
                size="sm"
              />
            </div>

            <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] flex items-center justify-between">
              <div>
                <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                  Context Shift & Sliding Window
                </span>
                <span className="text-[11px] text-[var(--color-text-muted)]">
                  Discard oldest message tokens smoothly when hitting window cap.
                </span>
              </div>
              <Toggle
                id="toggle-context-shift"
                checked={contextShift}
                onChange={setContextShift}
                size="sm"
              />
            </div>
          </div>

          <div className="flex items-center gap-2 text-[11px] text-[var(--color-text-muted)] pt-1 italic">
            <Info className="w-3.5 h-3.5 text-[var(--color-accent)] flex-shrink-0" />
            <span>
              Changes will be staged into ~/.config/local-ai-core/engine.json and applied upon the next model reload cycle.
            </span>
          </div>
        </div>
      )}
    </Card>
  );
};
