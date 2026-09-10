import React from 'react';
import { SectionHeader } from '../ui/SectionHeader';
import { Card } from '../ui/Card';
import { GlassPanel } from '../ui/GlassPanel';
import { Badge } from '../ui/Badge';
import { useTheme, ACCENT_PRESETS } from '../../context/ThemeContext';
import { AccentPresetId } from '../../types';

export const TokensShowcase: React.FC = () => {
  const { mode, accent, setAccent } = useTheme();

  const colorTokens = [
    { name: 'App Background', cssVar: '--color-app-bg', usage: 'Whole application window canvas' },
    { name: 'Primary Surface', cssVar: '--color-surface-primary', usage: 'Main content containers' },
    { name: 'Secondary Surface', cssVar: '--color-surface-secondary', usage: 'Sub-containers, chips' },
    { name: 'Glass Surface', cssVar: '--color-surface-glass', usage: 'Translucent frosted panels' },
    { name: 'Elevated Surface', cssVar: '--color-surface-elevated', usage: 'Cards, popovers, modals' },
    { name: 'Recessed Surface', cssVar: '--color-surface-recessed', usage: 'Tracks, grooves, input fields' },
    { name: 'Primary Text', cssVar: '--color-text-primary', usage: 'Headings, high-contrast labels' },
    { name: 'Secondary Text', cssVar: '--color-text-secondary', usage: 'Descriptions, subtext' },
    { name: 'Muted Text', cssVar: '--color-text-muted', usage: 'Captions, timestamps, disabled' },
    { name: 'Border Highlight', cssVar: '--color-border-highlight', usage: 'Glass top light edges' },
    { name: 'Accent (Primary)', cssVar: '--color-accent', usage: 'Key active controls, glow' },
    { name: 'Accent Secondary', cssVar: '--color-accent-secondary', usage: 'Gradient terminal stop' },
    { name: 'Success', cssVar: '--color-success', usage: 'Ready state, low latency' },
    { name: 'Warning', cssVar: '--color-warning', usage: 'High VRAM load, warmup' },
    { name: 'Danger', cssVar: '--color-danger', usage: 'Core errors, model termination' },
  ];

  const effectTokens = [
    {
      name: 'Soft Raised Surface',
      className: 'surface-raised',
      token: '--neu-shadow-raised',
      desc: 'Physical convex elevation with dual highlight & shadow',
    },
    {
      name: 'Soft Recessed Surface',
      className: 'surface-recessed',
      token: '--neu-shadow-recessed',
      desc: 'Concave carved indentation for tracks & text inputs',
    },
    {
      name: 'Glass Panel',
      className: 'glass-panel',
      token: '--glass-shadow + backdrop-blur',
      desc: 'Frosted acrylic surface with 16px blur & glass border',
    },
    {
      name: 'Elevated Glass Panel',
      className: 'glass-panel-elevated',
      token: '--glass-elevated-shadow + 20px blur',
      desc: 'Deep floating frosted layer for dialogs & popouts',
    },
    {
      name: 'Subtle Outer Shadow',
      className: 'shadow-soft-outer bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)]',
      token: '--shadow-subtle-outer',
      desc: 'Subdued minimalist elevation for standard cards',
    },
    {
      name: 'Subtle Inner Shadow',
      className: 'shadow-soft-inner surface-recessed',
      token: '--shadow-subtle-inner',
      desc: 'Micro inset depth for subtle tactile boundaries',
    },
    {
      name: 'Accent Glow',
      className: 'glow-accent bg-[var(--color-surface-elevated)] border border-[var(--color-accent)]',
      token: '--accent-glow',
      desc: 'Restrained luminescent halo for active assistant states',
    },
    {
      name: 'Background Blur',
      className: 'bg-glass-blur glass-panel',
      token: 'backdrop-filter: blur(16px)',
      desc: 'Hardware accelerated backdrop filtering',
    },
  ];

  return (
    <div className="space-y-10 animate-in fade-in duration-200">
      {/* Accent System Configurator */}
      <div className="space-y-4">
        <SectionHeader
          title="Accent System"
          description="Default restrained Cyan → Blue → Violet gradient. Configurable without modifying components."
          badge={<Badge variant="accent">Dynamic Gradient</Badge>}
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {Object.values(ACCENT_PRESETS).map((preset) => {
            const isSelected = preset.id === accent;
            return (
              <div
                key={preset.id}
                onClick={() => setAccent(preset.id as AccentPresetId)}
                className={`p-4 rounded-2xl cursor-pointer transition-all duration-200 select-none ${
                  isSelected
                    ? 'surface-raised ring-2 ring-[var(--color-accent)] glow-accent-sm'
                    : 'surface-recessed hover:border-[var(--color-accent)]/30'
                }`}
              >
                <div
                  className="w-full h-12 rounded-xl mb-3 shadow-inner"
                  style={{ backgroundImage: preset.gradient }}
                />
                <div className="flex items-center justify-between">
                  <span className="text-sm font-bold text-[var(--color-text-primary)]">
                    {preset.name}
                  </span>
                  {isSelected && (
                    <Badge variant="accent" size="sm">
                      Active
                    </Badge>
                  )}
                </div>
                <p className="text-xs text-[var(--color-text-secondary)] mt-1">
                  {preset.description}
                </p>
              </div>
            );
          })}
        </div>
      </div>

      {/* Semantic Color Tokens */}
      <div className="space-y-4">
        <SectionHeader
          title="Semantic Color Palette"
          description={`Centralized CSS variables reacting cleanly to ${mode.toUpperCase()} mode.`}
          badge={<Badge variant="default">{mode.toUpperCase()} MODE</Badge>}
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {colorTokens.map((t) => (
            <div
              key={t.name}
              className="p-3.5 rounded-2xl surface-raised flex items-center gap-3.5 border border-[var(--color-border-subtle)]"
            >
              {/* Swatch */}
              <div
                className="w-10 h-10 rounded-xl border border-black/10 dark:border-white/10 flex-shrink-0 shadow-inner"
                style={{ backgroundColor: `var(${t.cssVar})` }}
              />

              <div className="flex flex-col truncate">
                <span className="text-sm font-semibold text-[var(--color-text-primary)] truncate">
                  {t.name}
                </span>
                <span className="text-xs text-[var(--color-text-secondary)] truncate">
                  {t.usage}
                </span>
                <span className="text-[10px] font-mono text-[var(--color-text-muted)] truncate mt-0.5">
                  var({t.cssVar})
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Reusable Effects Showcase */}
      <div className="space-y-4">
        <SectionHeader
          title="Reusable Surface & Shadow Tokens"
          description="Consistent soft raised, recessed, and frosted glass tokens without inline handcrafted box-shadows."
          badge={<Badge variant="glass">No Inline Shadows</Badge>}
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {effectTokens.map((ef) => (
            <div
              key={ef.name}
              className={`p-5 rounded-2xl flex flex-col justify-between h-36 ${ef.className}`}
            >
              <div>
                <h4 className="text-sm font-bold text-[var(--color-text-primary)]">
                  {ef.name}
                </h4>
                <p className="text-xs text-[var(--color-text-secondary)] mt-1">
                  {ef.desc}
                </p>
              </div>

              <span className="text-[10px] font-mono text-[var(--color-text-muted)] truncate">
                {ef.token}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
