import React from 'react';
import { SectionHeader } from '../ui/SectionHeader';
import { Card } from '../ui/Card';
import { Badge } from '../ui/Badge';

export const TypographyShowcase: React.FC = () => {
  const levels = [
    {
      name: 'Page Title',
      className: 'typo-page-title',
      spec: '30px (1.875rem) • Bold 700 • Tracking -0.025em',
      sample: 'Local AI Control Center & Telemetry',
    },
    {
      name: 'Section Title',
      className: 'typo-section-title',
      spec: '20px (1.25rem) • SemiBold 600 • Tracking -0.015em',
      sample: 'Model Ingestion & Compute Engine',
    },
    {
      name: 'Body Text',
      className: 'typo-body',
      spec: '15px (0.9375rem) • Regular 400 • Line Height 1.6',
      sample:
        'Local language models are run directly on the host machine using llama.cpp and quantized GGUF weights, guaranteeing zero data leakage and real-time offline performance.',
    },
    {
      name: 'Secondary Text',
      className: 'typo-secondary',
      spec: '14px (0.875rem) • Regular 400 • Color Secondary',
      sample: 'Configured for high precision fp16 KV cache offloading with 32 GPU layers.',
    },
    {
      name: 'Metric Value',
      className: 'typo-metric-value',
      spec: '30px (1.875rem) • Bold 700 • Tabular Figures font-mono',
      sample: '48.2 tokens/s',
    },
    {
      name: 'Labels',
      className: 'typo-label',
      spec: '11px (0.6875rem) • SemiBold 600 • Uppercase • Tracking 0.05em',
      sample: 'GPU VRAM ALLOCATION',
    },
    {
      name: 'Caption',
      className: 'typo-caption',
      spec: '12px (0.75rem) • Regular 400 • Color Muted',
      sample: 'Last calibrated 2 minutes ago via local background cron daemon.',
    },
  ];

  return (
    <div className="space-y-10 animate-in fade-in duration-200">
      <SectionHeader
        title="Typography Hierarchy & Font Stack"
        description="Clean modern system sans-serif font stack with mathematical line-height scales and high-contrast accessibility."
        badge={<Badge variant="accent">Typographic Scale</Badge>}
      />

      <div className="space-y-4">
        {levels.map((lvl) => (
          <div
            key={lvl.name}
            className="p-5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-2"
          >
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-[var(--color-accent)]">{lvl.name}</span>
              <span className="text-[11px] font-mono text-[var(--color-text-muted)]">
                {lvl.spec}
              </span>
            </div>

            <div className={lvl.className}>{lvl.sample}</div>
          </div>
        ))}
      </div>

      <div className="p-6 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-3">
        <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
          Typographic Rule Adherence
        </h4>
        <ul className="text-xs sm:text-sm text-[var(--color-text-secondary)] space-y-1.5 list-disc list-inside">
          <li>Never use the vibrant accent gradient for ordinary body text to maintain optimal legibility.</li>
          <li>Contrast ratios adhere strictly to WCAG AA guidelines for both Light and Dark themes.</li>
          <li>Tabular figures (monospaced numbers) used for telemetry values to prevent layout jitter.</li>
          <li>Labels on buttons and tabs are single-line with explicit whitespace wrap prevention.</li>
        </ul>
      </div>
    </div>
  );
};
