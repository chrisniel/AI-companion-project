import React from 'react';
import { Route, Cloud, Shield, Cpu, HelpCircle, ArrowRight } from 'lucide-react';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';
import { Toggle } from '../../ui/Toggle';
import { ProviderRoutingPolicy } from '../../../types';

interface ProviderRoutingCardProps {
  routingPolicy: ProviderRoutingPolicy;
  onChangeRoutingPolicy: (policy: ProviderRoutingPolicy) => void;
  allowCloudFallback: boolean;
  onToggleAllowCloudFallback: (allowed: boolean) => void;
  askBeforeCloudUse: boolean;
  onToggleAskBeforeCloudUse: (ask: boolean) => void;
  useCloudForComplexOnly: boolean;
  onToggleUseCloudForComplexOnly: (complexOnly: boolean) => void;
}

interface PolicyOption {
  id: ProviderRoutingPolicy;
  label: string;
  description: string;
  icon: React.ReactNode;
}

export const ProviderRoutingCard: React.FC<ProviderRoutingCardProps> = ({
  routingPolicy,
  onChangeRoutingPolicy,
  allowCloudFallback,
  onToggleAllowCloudFallback,
  askBeforeCloudUse,
  onToggleAskBeforeCloudUse,
  useCloudForComplexOnly,
  onToggleUseCloudForComplexOnly,
}) => {
  const policies: PolicyOption[] = [
    {
      id: 'local_only',
      label: 'Local Only',
      description: 'Zero external cloud transmission. Fails gracefully if local VRAM/context limits are reached.',
      icon: <Cpu className="w-4 h-4 text-sky-500" />,
    },
    {
      id: 'local_first',
      label: 'Local First',
      description: 'Executes on local hardware by default; seamlessly utilizes cloud fallback per rules below.',
      icon: <Route className="w-4 h-4 text-[var(--color-accent)]" />,
    },
    {
      id: 'cloud_first',
      label: 'Cloud First',
      description: 'Prefers high-capacity cloud models (Gemini); falls back to local core during offline operations.',
      icon: <Cloud className="w-4 h-4 text-violet-500" />,
    },
    {
      id: 'cloud_only',
      label: 'Cloud Only',
      description: 'Delegates all inference to remote servers. Local engine handles audio and device tools only.',
      icon: <Cloud className="w-4 h-4 text-indigo-400" />,
    },
  ];

  return (
    <Card id="provider-routing-card" className="space-y-6">
      {/* 1. Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-2 border-b border-[var(--color-border-subtle)]">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm sm:text-base font-semibold text-[var(--color-text-primary)]">
              Provider Routing Policy
            </h2>
            <Badge variant="accent" size="sm">
              Traffic Governance
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
            Configure how prompt requests are dispatched between local hardware and remote providers.
          </p>
        </div>

        <div className="text-xs font-mono text-[var(--color-text-muted)] self-start sm:self-auto">
          Current Policy: <span className="font-semibold text-[var(--color-accent)]">{policies.find(p => p.id === routingPolicy)?.label}</span>
        </div>
      </div>

      {/* 2. Policy Choices Grid (Tactile Segmented Controls) */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        {policies.map((policy) => {
          const isSelected = routingPolicy === policy.id;

          return (
            <button
              key={policy.id}
              type="button"
              id={`routing-policy-${policy.id}`}
              onClick={() => onChangeRoutingPolicy(policy.id)}
              className={`p-3.5 rounded-2xl text-left transition-all duration-150 relative select-none flex flex-col justify-between group outline-none ${
                isSelected
                  ? 'surface-raised border-2 border-[var(--color-accent)] shadow-md ring-2 ring-[var(--color-accent)]/20'
                  : 'surface-base border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 hover:surface-raised'
              }`}
            >
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <div className="w-7 h-7 rounded-lg surface-recessed flex items-center justify-center">
                    {policy.icon}
                  </div>
                  {isSelected && (
                    <span className="w-2 h-2 rounded-full bg-[var(--color-accent)] shadow-sm" />
                  )}
                </div>
                <div className="font-bold text-xs text-[var(--color-text-primary)]">
                  {policy.label}
                  {policy.id === 'local_first' && (
                    <span className="text-[10px] text-[var(--color-text-muted)] ml-1 font-normal font-mono">
                      (Default)
                    </span>
                  )}
                </div>
                <p className="text-[11px] text-[var(--color-text-secondary)] leading-relaxed">
                  {policy.description}
                </p>
              </div>
            </button>
          );
        })}
      </div>

      {/* 3. Cloud Fallback Sub-Controls */}
      <div className="pt-2 border-t border-[var(--color-border-subtle)] space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Cloud className="w-4 h-4 text-violet-400" />
            <h3 className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
              Cloud Fallback Controls
            </h3>
          </div>
          <span className="text-[11px] text-[var(--color-text-muted)] font-mono">
            Provider: Gemini 2.0 API
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-3.5">
          {/* Fallback Control 1: Allow cloud fallback */}
          <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex items-start justify-between gap-3">
            <div className="space-y-1 pr-2">
              <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                Allow cloud fallback
              </span>
              <p className="text-[11px] text-[var(--color-text-muted)] leading-relaxed">
                Permits automatic rerouting when local models exceed context or experience VRAM pressure.
              </p>
            </div>
            <Toggle
              id="toggle-allow-cloud-fallback"
              checked={allowCloudFallback}
              onChange={onToggleAllowCloudFallback}
              size="sm"
            />
          </div>

          {/* Fallback Control 2: Ask before cloud use */}
          <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex items-start justify-between gap-3">
            <div className="space-y-1 pr-2">
              <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                Ask before cloud use
              </span>
              <p className="text-[11px] text-[var(--color-text-muted)] leading-relaxed">
                Displays a quick consent chip in composer before transmitting any prompt payload externally.
              </p>
            </div>
            <Toggle
              id="toggle-ask-before-cloud-use"
              checked={askBeforeCloudUse}
              onChange={onToggleAskBeforeCloudUse}
              size="sm"
              disabled={!allowCloudFallback}
            />
          </div>

          {/* Fallback Control 3: Use cloud for complex requests only */}
          <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex items-start justify-between gap-3">
            <div className="space-y-1 pr-2">
              <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                Use cloud for complex requests only
              </span>
              <p className="text-[11px] text-[var(--color-text-muted)] leading-relaxed">
                Keep quick chat local; route code refactoring, deep research, and long docs to cloud.
              </p>
            </div>
            <Toggle
              id="toggle-use-cloud-complex-only"
              checked={useCloudForComplexOnly}
              onChange={onToggleUseCloudForComplexOnly}
              size="sm"
              disabled={!allowCloudFallback}
            />
          </div>
        </div>
      </div>
    </Card>
  );
};
