import React from 'react';
import {
  Sparkles,
  Layers,
  Sliders,
  ShieldCheck,
  Zap,
  CheckCircle2,
  Cpu,
  Palette,
} from 'lucide-react';
import { Card } from '../ui/Card';
import { GlassPanel } from '../ui/GlassPanel';
import { Button } from '../ui/Button';
import { Badge } from '../ui/Badge';
import { useTheme } from '../../context/ThemeContext';

export const OverviewShowcase: React.FC<{ onNavigate: (section: string) => void }> = ({
  onNavigate,
}) => {
  const { mode, toggleTheme, currentAccentPreset } = useTheme();

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Hero Welcome Card */}
      <GlassPanel elevated padding="lg" className="relative overflow-hidden border-white/20">
        <div className="absolute top-0 right-0 w-96 h-96 bg-accent-gradient opacity-10 blur-3xl -mr-20 -mt-20 pointer-events-none" />

        <div className="max-w-3xl relative z-10 space-y-4">
          <div className="flex flex-wrap items-center gap-2.5">
            <Badge variant="accent" size="md" dot pulse>
              BATCH 1 DELIVERABLE
            </Badge>
            <Badge variant="glass" size="md">
              Neumorphism + Glassmorphism + Minimalism
            </Badge>
          </div>

          <h1 className="typo-page-title">
            Soft Glass Design System for Local AI Control Center
          </h1>

          <p className="typo-body text-[var(--color-text-secondary)] text-base sm:text-lg leading-relaxed">
            A visual foundation and reusable UI component architecture for desktop-oriented
            local AI supervision. Engineered with tactile depth, frosted glass surfaces, and a
            restrained cyan-to-violet accent gradient.
          </p>

          <div className="flex flex-wrap items-center gap-3 pt-2">
            <Button
              variant="primary"
              size="md"
              leftIcon={<Layers className="w-4 h-4" />}
              onClick={() => onNavigate('tokens')}
            >
              Explore Semantic Tokens
            </Button>
            <Button
              variant="secondary"
              size="md"
              leftIcon={<Sliders className="w-4 h-4" />}
              onClick={() => onNavigate('controls')}
            >
              Interactive Controls
            </Button>
            <Button
              variant="neumorphic"
              size="md"
              leftIcon={<Cpu className="w-4 h-4" />}
              onClick={() => onNavigate('preview')}
            >
              View Desktop Shell
            </Button>
          </div>
        </div>
      </GlassPanel>

      {/* Triad Principles Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        <Card variant="raised" padding="md" className="space-y-3">
          <div className="w-10 h-10 rounded-xl surface-raised flex items-center justify-center text-[var(--color-accent)] border border-[var(--color-border-subtle)] shadow-sm">
            <ShieldCheck className="w-5 h-5" />
          </div>
          <h3 className="typo-section-title text-base font-semibold">1. Neumorphism / Soft UI</h3>
          <p className="typo-secondary text-sm">
            Used deliberately for tactile buttons, switches, sliders, compact meters, and active
            controls. Never overused on text reading surfaces.
          </p>
          <div className="p-2 rounded-xl surface-recessed text-xs text-[var(--color-text-muted)] font-mono">
            surface-raised • surface-recessed • surface-pressed
          </div>
        </Card>

        <Card variant="elevated" padding="md" className="glass-panel space-y-3">
          <div className="w-10 h-10 rounded-xl bg-accent-gradient flex items-center justify-center text-white shadow-sm glow-accent-sm">
            <Sparkles className="w-5 h-5" />
          </div>
          <h3 className="typo-section-title text-base font-semibold">2. Glassmorphism</h3>
          <p className="typo-secondary text-sm">
            Reserved for structural frames, navigation sidebar, header, assistant panel, modals,
            and floating menus with multi-step backdrop blur and border highlights.
          </p>
          <div className="p-2 rounded-xl surface-recessed text-xs text-[var(--color-text-muted)] font-mono">
            glass-panel • glass-panel-elevated • backdrop-blur
          </div>
        </Card>

        <Card variant="raised" padding="md" className="space-y-3">
          <div className="w-10 h-10 rounded-xl surface-raised flex items-center justify-center text-[var(--color-accent-secondary)] border border-[var(--color-border-subtle)] shadow-sm">
            <CheckCircle2 className="w-5 h-5" />
          </div>
          <h3 className="typo-section-title text-base font-semibold">3. Minimalism & Accessibility</h3>
          <p className="typo-secondary text-sm">
            High-contrast readable typography, visible focus rings, and states that never rely
            solely on soft drop-shadows to communicate functionality.
          </p>
          <div className="p-2 rounded-xl surface-recessed text-xs text-[var(--color-text-muted)] font-mono">
            WCAG AA • focus-ring • 10 component states
          </div>
        </Card>
      </div>

      {/* Interactive Theme Status Bar */}
      <div className="p-5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl surface-raised flex items-center justify-center text-[var(--color-accent)]">
            <Palette className="w-5 h-5" />
          </div>
          <div>
            <span className="text-sm font-semibold text-[var(--color-text-primary)]">
              Active Environment: {mode === 'light' ? 'Light Soft Pale' : 'Dark Charcoal Velvet'}
            </span>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Accent Preset: {currentAccentPreset.name} ({currentAccentPreset.description})
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Button variant="secondary" size="sm" onClick={toggleTheme}>
            Toggle Theme ({mode === 'light' ? 'Go Dark' : 'Go Light'})
          </Button>
        </div>
      </div>
    </div>
  );
};
