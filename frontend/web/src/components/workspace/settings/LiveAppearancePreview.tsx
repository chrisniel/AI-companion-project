import React, { useState } from 'react';
import {
  Sparkles,
  Sliders,
  CheckCircle2,
  Maximize2,
  Volume2,
  Bot,
  Zap,
} from 'lucide-react';
import { useTheme } from '../../../context/ThemeContext';
import { computeWallpaperStyle } from '../../../context/backgroundPresets';

export const LiveAppearancePreview: React.FC = () => {
  const { mode, backgroundSettings, glassSettings, currentAccentPreset, customAccentColor } = useTheme();
  const [activeTab, setActiveTab] = useState<'preview' | 'metrics'>('preview');
  const [demoToggled, setDemoToggled] = useState(false);

  const isDark = mode === 'dark';
  const wallpaperStyle = computeWallpaperStyle(backgroundSettings, isDark);

  return (
    <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
            <Sparkles className="w-4 h-4" />
            Live Appearance & Glass Preview
          </h3>
          <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
            Real-time preview of environmental background diffusion, frosted glass opacity, and tactile controls.
          </p>
        </div>

        {/* Live Metrics Pill */}
        <div className="hidden sm:flex items-center gap-2 text-[11px] font-mono text-[var(--color-text-muted)]">
          <span className="px-2.5 py-1 rounded-full bg-[var(--color-surface-secondary)] border border-[var(--color-border-subtle)]">
            Opacity: {glassSettings.transparency}%
          </span>
          <span className="px-2.5 py-1 rounded-full bg-[var(--color-surface-secondary)] border border-[var(--color-border-subtle)]">
            Blur: {glassSettings.blur}px
          </span>
          <span className="px-2.5 py-1 rounded-full bg-[var(--color-surface-secondary)] border border-[var(--color-border-subtle)]">
            Overlay: {backgroundSettings.overlayOpacity}%
          </span>
        </div>
      </div>

      {/* Simulated Environmental Canvas Frame */}
      <div className="relative w-full rounded-2xl overflow-hidden border border-[var(--color-border-subtle)] min-h-[280px] sm:min-h-[300px] flex items-center justify-center p-4 sm:p-8">
        {/* Background layer */}
        <div
          className="absolute inset-0 transition-all duration-300"
          style={{
            ...wallpaperStyle,
            filter: `brightness(${backgroundSettings.brightness}%) saturate(${backgroundSettings.saturation}%) blur(${backgroundSettings.blur}px)`,
            transform: backgroundSettings.blur > 0 ? 'scale(1.04)' : 'none',
          }}
        />

        {/* Scrim / Overlay layer */}
        <div
          className="absolute inset-0 transition-opacity duration-300 pointer-events-none"
          style={{
            backgroundColor: isDark ? '#0b0f17' : '#eaf0f8',
            opacity: backgroundSettings.overlayOpacity / 100,
          }}
        />

        {/* The Live Glass Card Sitting on Top of the Environment */}
        <div className="relative z-10 w-full max-w-lg glass-panel rounded-2xl p-5 shadow-lg border border-[var(--color-surface-glass-border)] space-y-4">
          {/* Card Top Row */}
          <div className="flex items-center justify-between border-b border-[var(--color-border-subtle)] pb-3">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-xl bg-accent-gradient text-white flex items-center justify-center shadow-xs">
                <Bot className="w-4 h-4" />
              </div>
              <div>
                <h4 className="text-sm font-bold text-[var(--color-text-primary)] leading-tight">
                  Neural Core Preview
                </h4>
                <p className="text-[11px] font-mono text-[var(--color-text-muted)]">
                  Environment: {backgroundSettings.type.toUpperCase()} • Mode: {mode.toUpperCase()}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[var(--color-surface-elevated)]/80 border border-[var(--color-border-subtle)] text-[10px] font-mono text-[var(--color-accent)] font-semibold">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              DIFFUSION ACTIVE
            </div>
          </div>

          {/* Middle Row: Content and Sample Controls */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {/* Raised Neumorphic Control Card */}
            <div className="p-3 rounded-xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
              <div className="flex items-center justify-between text-xs font-semibold text-[var(--color-text-primary)]">
                <span>Raised Surface</span>
                <Zap className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              </div>
              <p className="text-[11px] text-[var(--color-text-secondary)] leading-relaxed">
                Opaque high-contrast backing guarantees 100% text readability.
              </p>
              <button
                type="button"
                onClick={() => setDemoToggled(!demoToggled)}
                className={`w-full py-1.5 px-3 rounded-lg text-xs font-medium border transition-all ${
                  demoToggled
                    ? 'surface-pressed text-[var(--color-accent)] border-[var(--color-accent)]/30'
                    : 'surface-raised text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/30'
                }`}
              >
                {demoToggled ? 'Pressed State Active' : 'Click to Press'}
              </button>
            </div>

            {/* Recessed Sensor Readout Card */}
            <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
              <div className="flex items-center justify-between text-xs font-semibold text-[var(--color-text-primary)]">
                <span>Recessed Sensor</span>
                <Sliders className="w-3.5 h-3.5 text-[var(--color-text-muted)]" />
              </div>
              <div className="flex items-baseline justify-between pt-1">
                <span className="text-[10px] uppercase font-mono text-[var(--color-text-muted)]">Inference</span>
                <span className="text-base font-bold font-mono text-[var(--color-text-primary)]">42.8 t/s</span>
              </div>
              {/* Progress bar in accent color */}
              <div className="w-full h-1.5 rounded-full bg-[var(--color-surface-secondary)] overflow-hidden">
                <div className="h-full rounded-full bg-accent-gradient w-3/4" />
              </div>
            </div>
          </div>

          {/* Bottom Action Row: Accent Button & Typography preview */}
          <div className="flex items-center justify-between pt-2 border-t border-[var(--color-border-subtle)]">
            <div className="text-[11px] text-[var(--color-text-secondary)] truncate">
              Accent:{' '}
              <span className="font-semibold text-[var(--color-text-primary)]">
                {customAccentColor ? 'Custom Hex' : currentAccentPreset.name}
              </span>
            </div>

            <div className="flex items-center gap-2">
              <span className="text-[11px] font-mono text-[var(--color-text-muted)] hidden sm:inline">
                Soft Glass Visual Language
              </span>
              <button
                type="button"
                className="px-3.5 py-1.5 rounded-xl bg-accent-gradient text-white text-xs font-semibold shadow-sm hover:opacity-90 active:scale-95 transition-all flex items-center gap-1.5"
              >
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span>Action Button</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
