import React, { useState } from 'react';
import {
  Sparkles,
  Zap,
  Play,
  RotateCcw,
  Trash2,
  Settings,
  Bell,
  Sliders,
  Volume2,
  Check,
} from 'lucide-react';
import { SectionHeader } from '../ui/SectionHeader';
import { Button } from '../ui/Button';
import { IconButton } from '../ui/IconButton';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { Badge } from '../ui/Badge';
import { Card } from '../ui/Card';
import { ComponentState, ButtonVariant } from '../../types';

export const ButtonsShowcase: React.FC = () => {
  const [activeNeuBtn, setActiveNeuBtn] = useState(false);
  const [testState, setTestState] = useState<ComponentState>('default');
  const [isLoading, setIsLoading] = useState(false);

  const triggerMockLoading = () => {
    setIsLoading(true);
    setTimeout(() => setIsLoading(false), 2000);
  };

  const variants: ButtonVariant[] = ['primary', 'secondary', 'neumorphic', 'ghost', 'danger'];
  const states: ComponentState[] = [
    'default',
    'hover',
    'focused',
    'pressed',
    'selected',
    'disabled',
    'loading',
    'success',
    'warning',
    'error',
  ];

  return (
    <div className="space-y-10 animate-in fade-in duration-200">
      {/* Button Variants Overview */}
      <div className="space-y-4">
        <SectionHeader
          title="Button Variants"
          description="Five distinct purpose-driven button styles adhering to soft glass + neumorphic rules."
          badge={<Badge variant="accent">5 Variants</Badge>}
        />

        <div className="p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-6">
          <div className="flex flex-wrap items-center gap-4">
            <Button variant="primary" leftIcon={<Sparkles className="w-4 h-4" />}>
              Primary Accent
            </Button>
            <Button variant="secondary" leftIcon={<Settings className="w-4 h-4" />}>
              Secondary Elevated
            </Button>
            <Button variant="neumorphic" leftIcon={<Zap className="w-4 h-4" />}>
              Neumorphic Soft
            </Button>
            <Button variant="ghost" leftIcon={<RotateCcw className="w-4 h-4" />}>
              Ghost Minimal
            </Button>
            <Button variant="danger" leftIcon={<Trash2 className="w-4 h-4" />}>
              Danger Action
            </Button>
          </div>

          <div className="pt-4 border-t border-[var(--color-border-subtle)] flex flex-wrap items-center gap-4">
            <span className="text-xs font-semibold text-[var(--color-text-secondary)]">
              Interactive Loading Demo:
            </span>
            <Button
              variant="primary"
              isLoading={isLoading}
              onClick={triggerMockLoading}
              leftIcon={<Play className="w-4 h-4" />}
            >
              {isLoading ? 'Processing Model...' : 'Click to Test Loading'}
            </Button>
          </div>
        </div>
      </div>

      {/* Button Sizes */}
      <div className="space-y-4">
        <SectionHeader
          title="Button Sizing"
          description="Consistent optical scaling (Small: 12px, Medium: 14px, Large: 16px)."
        />

        <div className="p-6 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-wrap items-center gap-4">
          <Button variant="primary" size="sm">
            Small (sm)
          </Button>
          <Button variant="primary" size="md">
            Medium (md)
          </Button>
          <Button variant="primary" size="lg">
            Large (lg)
          </Button>
        </div>
      </div>

      {/* Tactile Neumorphic Buttons */}
      <div className="space-y-4">
        <SectionHeader
          title="Dedicated Neumorphic Button"
          description="Employs convex dual-shadows in default state and transitions to an inset pressed state upon click or selection."
          badge={<Badge variant="glass">Soft UI Tactile</Badge>}
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Card variant="raised" padding="md" className="space-y-3">
            <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
              Interactive Physical Toggle
            </h4>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Click the button below to toggle between raised surface and depressed/pressed
              surface state.
            </p>
            <div className="pt-2">
              <NeumorphicButton
                active={activeNeuBtn}
                onClick={() => setActiveNeuBtn(!activeNeuBtn)}
                icon={<Zap className="w-4 h-4" />}
                size="md"
              >
                {activeNeuBtn ? 'Surface Depressed (Active)' : 'Surface Convex (Inactive)'}
              </NeumorphicButton>
            </div>
          </Card>

          <Card variant="raised" padding="md" className="space-y-3">
            <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
              Quick Action Widget Cluster
            </h4>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Compact tactile triggers ideal for Local AI quick controls.
            </p>
            <div className="flex flex-wrap gap-2 pt-2">
              <NeumorphicButton size="sm" icon={<Play className="w-3.5 h-3.5" />}>
                Resume Model
              </NeumorphicButton>
              <NeumorphicButton size="sm" icon={<Sliders className="w-3.5 h-3.5" />}>
                Quantize
              </NeumorphicButton>
              <NeumorphicButton size="sm" icon={<RotateCcw className="w-3.5 h-3.5" />}>
                Reset Cache
              </NeumorphicButton>
            </div>
          </Card>
        </div>
      </div>

      {/* Icon Buttons */}
      <div className="space-y-4">
        <SectionHeader
          title="Icon Buttons"
          description="Compact accessible controls for toolbars and quick navigation."
        />

        <div className="p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex flex-wrap items-center gap-4">
          <IconButton icon={<Bell className="w-4 h-4" />} aria-label="Notifications" variant="neumorphic" />
          <IconButton icon={<Sparkles className="w-4 h-4" />} aria-label="Assistant" variant="accent" />
          <IconButton icon={<Volume2 className="w-4 h-4" />} aria-label="Audio" variant="glass" />
          <IconButton icon={<Settings className="w-4 h-4" />} aria-label="Settings" variant="ghost" />
          <IconButton icon={<Trash2 className="w-4 h-4 text-rose-500" />} aria-label="Delete" variant="neumorphic" />
        </div>
      </div>

      {/* Comprehensive State Testing Matrix */}
      <div className="space-y-4">
        <SectionHeader
          title="Button State Matrix"
          description="Interactive state inspector for all 10 component states."
          badge={<Badge variant="accent">10 States</Badge>}
        />

        <div className="p-6 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-4">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs font-semibold text-[var(--color-text-secondary)] mr-2">
              Select State to Preview:
            </span>
            {states.map((st) => (
              <button
                key={st}
                type="button"
                onClick={() => setTestState(st)}
                className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-all ${
                  testState === st
                    ? 'bg-accent-gradient text-white shadow-sm'
                    : 'surface-raised text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                }`}
              >
                {st}
              </button>
            ))}
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 pt-3">
            {variants.map((v) => (
              <div key={v} className="flex flex-col items-center gap-2 p-3 surface-raised rounded-xl">
                <span className="text-[11px] font-mono text-[var(--color-text-muted)] uppercase">
                  {v}
                </span>
                <Button variant={v} state={testState} size="sm">
                  {testState}
                </Button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
