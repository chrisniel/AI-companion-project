import React from 'react';
import { Cpu, HardDrive, Info, Sliders, Check } from 'lucide-react';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';

interface VramTargetSliderProps {
  vramTargetGb: number;
  totalVramGb?: number;
  currentModelVramGb?: number;
  onChangeVramTarget: (value: number) => void;
}

export const VramTargetSlider: React.FC<VramTargetSliderProps> = ({
  vramTargetGb,
  totalVramGb = 8.0,
  currentModelVramGb = 4.9,
  onChangeVramTarget,
}) => {
  const percentage = Math.min(
    Math.max((vramTargetGb / totalVramGb) * 100, 0),
    100
  );

  const presets = [
    { label: '2.5 GB', value: 2.5, desc: 'Eco Target' },
    { label: '4.0 GB', value: 4.0, desc: 'Balanced' },
    { label: '6.0 GB', value: 6.0, desc: 'High Cache' },
    { label: '8.0 GB', value: 8.0, desc: 'Full GPU' },
  ];

  const systemHeadroom = Math.max(0, totalVramGb - vramTargetGb);

  return (
    <Card id="vram-target-card" className="space-y-4">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-2 border-b border-[var(--color-border-subtle)]">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm sm:text-base font-semibold text-[var(--color-text-primary)]">
              AI VRAM Target
            </h2>
            <Badge variant="accent" size="sm">
              GPU Memory Budget
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
            Controls maximum dedicated VRAM reserved for local model weights and KV tensor cache.
          </p>
        </div>

        {/* Big tactile readout */}
        <div className="flex items-baseline gap-1.5 px-3 py-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] self-start sm:self-auto font-mono">
          <span className="text-xs text-[var(--color-text-muted)]">Target:</span>
          <span className="text-base font-bold text-[var(--color-accent)]">
            {vramTargetGb.toFixed(1)} GB
          </span>
          <span className="text-xs text-[var(--color-text-muted)]">
            / {totalVramGb.toFixed(0)} GB
          </span>
        </div>
      </div>

      {/* Elegant Slider Control */}
      <div className="space-y-3 pt-2">
        <div className="flex items-center justify-between text-xs">
          <span className="font-medium text-[var(--color-text-secondary)] flex items-center gap-1.5">
            <Sliders className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            VRAM Allocation Ceiling
          </span>
          <span className="font-mono text-xs text-[var(--color-text-primary)] font-semibold">
            {vramTargetGb.toFixed(1)} GB / {totalVramGb.toFixed(0)} GB ({Math.round(percentage)}%)
          </span>
        </div>

        {/* Custom tactile slider */}
        <div className="relative flex items-center w-full h-7 select-none touch-none">
          {/* Recessed Track */}
          <div className="w-full h-3 rounded-full surface-recessed border border-[var(--color-border-subtle)] relative overflow-hidden">
            {/* Active Accent Gradient Fill */}
            <div
              className="absolute left-0 top-0 bottom-0 bg-accent-gradient transition-all duration-75 rounded-full"
              style={{ width: `${percentage}%` }}
            />
          </div>

          {/* Native Range Input for accessibility & smooth dragging */}
          <input
            id="vram-target-slider-input"
            type="range"
            min={1.0}
            max={totalVramGb}
            step={0.5}
            value={vramTargetGb}
            onChange={(e) => onChangeVramTarget(parseFloat(e.target.value))}
            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-20"
            aria-label="AI VRAM Target Slider"
          />

          {/* Raised Physical Thumb Indicator */}
          <div
            className="absolute top-1/2 -translate-y-1/2 w-6 h-6 rounded-full surface-raised border-2 border-[var(--color-accent)] shadow-md pointer-events-none transition-all duration-75 flex items-center justify-center -ml-3 z-10"
            style={{ left: `${percentage}%` }}
          >
            <div className="w-2 h-2 rounded-full bg-[var(--color-accent)]" />
          </div>
        </div>

        {/* Scale labels */}
        <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] font-mono px-0.5">
          <span>1.0 GB (Min)</span>
          <span>4.0 GB (Balanced)</span>
          <span>{totalVramGb.toFixed(0)} GB (Dedicated GPU Limit)</span>
        </div>
      </div>

      {/* Visual Memory Budget Bar */}
      <div className="p-3 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2">
        <div className="flex items-center justify-between text-[11px] text-[var(--color-text-muted)]">
          <span>Allocated VRAM Breakdown</span>
          <span className="font-mono">
            {systemHeadroom.toFixed(1)} GB Free for Windows / Display
          </span>
        </div>

        <div className="w-full h-2.5 rounded-full surface-recessed overflow-hidden flex">
          {/* Active Model Weights */}
          <div
            className="h-full bg-sky-500 transition-all duration-200"
            style={{
              width: `${Math.min((currentModelVramGb / totalVramGb) * 100, percentage)}%`,
            }}
            title={`Active Model: ${currentModelVramGb} GB`}
          />
          {/* Reserved KV Cache Buffer */}
          <div
            className="h-full bg-violet-500/60 transition-all duration-200"
            style={{
              width: `${Math.max(
                0,
                percentage - (currentModelVramGb / totalVramGb) * 100
              )}%`,
            }}
            title="KV Cache & Working Memory Buffer"
          />
          {/* Free Headroom */}
          <div className="h-full flex-1 bg-transparent" />
        </div>

        <div className="flex flex-wrap items-center gap-4 text-[10px] font-mono text-[var(--color-text-secondary)] pt-0.5">
          <div className="flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-sky-500" />
            <span>Active Model ({currentModelVramGb.toFixed(1)} GB)</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-violet-500" />
            <span>KV Cache Target</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-[var(--color-text-muted)]/40" />
            <span>System Headroom ({systemHeadroom.toFixed(1)} GB)</span>
          </div>
        </div>
      </div>

      {/* Quick Presets & UI-only note */}
      <div className="flex flex-wrap items-center justify-between gap-2 pt-1 text-xs">
        <div className="flex items-center gap-1.5">
          {presets.map((preset) => (
            <button
              key={preset.value}
              type="button"
              onClick={() => onChangeVramTarget(preset.value)}
              className={`px-2.5 py-1 rounded-lg text-xs font-mono transition-all ${
                Math.abs(vramTargetGb - preset.value) < 0.1
                  ? 'surface-raised font-bold text-[var(--color-accent)] border border-[var(--color-accent)]/40 shadow-sm'
                  : 'surface-recessed text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] border border-transparent'
              }`}
            >
              {preset.label}
            </button>
          ))}
        </div>

        <span className="text-[11px] text-[var(--color-text-muted)] italic">
          UI-only hardware simulation • No driver changes applied
        </span>
      </div>
    </Card>
  );
};
