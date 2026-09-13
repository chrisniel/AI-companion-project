import React from 'react';
import { Leaf, Gauge, Zap, CheckCircle2, ShieldAlert } from 'lucide-react';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';
import { PerformanceProfile } from '../../../types';

interface PerformanceProfileSelectorProps {
  currentProfile?: PerformanceProfile | string;
  requestedProfile?: PerformanceProfile | string;
  appliedProfile?: string | null;
  appliedContextSize?: number | null;
  appliedGpuLayers?: number | null;
  requestedMmprojOffload?: boolean;
  appliedMmprojOffload?: boolean | null;
  onSelectProfile: (profile: PerformanceProfile) => void;
}

interface ProfileItem {
  id: PerformanceProfile;
  name: string;
  tagline: string;
  description: string;
  details: string[];
  icon: React.ReactNode;
  accentColor: string;
}

export const PerformanceProfileSelector: React.FC<PerformanceProfileSelectorProps> = ({
  currentProfile,
  requestedProfile: explicitRequestedProfile,
  appliedProfile,
  appliedContextSize,
  appliedGpuLayers,
  requestedMmprojOffload,
  appliedMmprojOffload,
  onSelectProfile,
}) => {
  const reqProfile = (explicitRequestedProfile || currentProfile || 'balanced').toLowerCase();
  // Normalize 'turbo' to 'maximum' if passed
  const activeId = reqProfile === 'turbo' ? 'maximum' : reqProfile;

  const isTransitionPending = appliedProfile === null || (appliedProfile !== undefined && appliedProfile !== null && appliedProfile.toLowerCase() !== reqProfile);

  const profiles: ProfileItem[] = [
    {
      id: 'eco',
      name: 'Eco',
      tagline: 'Cool & Quiet',
      description: 'Prioritize resources for gaming/development.',
      details: ['4 CPU threads', '0 GPU layers (CPU only)', 'Context capped to 2048', '--no-mmproj-offload'],
      icon: <Leaf className="w-5 h-5 text-emerald-500" />,
      accentColor: 'border-emerald-500/40 text-emerald-500',
    },
    {
      id: 'balanced',
      name: 'Balanced',
      tagline: 'Standard Daily Operations',
      description: 'Normal assistant performance.',
      details: ['6 CPU threads', '28 GPU layers (AMD RX 580)', '4096 context tokens', 'GPU mmproj offload'],
      icon: <Gauge className="w-5 h-5 text-[var(--color-accent)]" />,
      accentColor: 'border-[var(--color-accent)]/40 text-[var(--color-accent)]',
    },
    {
      id: 'maximum',
      name: 'Maximum',
      tagline: 'Full Neural Throughput',
      description: 'Prioritize AI performance.',
      details: ['33 GPU layers (Max offload)', '8 CPU threads', '8192 context tokens', 'GPU mmproj offload'],
      icon: <Zap className="w-5 h-5 text-amber-500" />,
      accentColor: 'border-amber-500/40 text-amber-500',
    },
  ];

  return (
    <Card id="performance-profiles-card" className="space-y-4">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-2 border-b border-[var(--color-border-subtle)]">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm sm:text-base font-semibold text-[var(--color-text-primary)]">
              Performance Profiles
            </h2>
            <Badge variant="default" size="sm">
              Tactile Control
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
            Dynamically adjust runtime hardware scheduling, thread affinity, and clock headroom.
          </p>
        </div>

        <div className="flex items-center gap-2 text-xs font-mono">
          <span className="text-[var(--color-text-muted)]">Requested:</span>
          <span className="font-semibold text-[var(--color-accent)] capitalize">{activeId}</span>
          <span className="text-[var(--color-text-muted)] ml-2">Applied:</span>
          {appliedProfile ? (
            <span className="font-semibold text-emerald-500 capitalize">{appliedProfile}</span>
          ) : (
            <Badge variant="warning" size="sm">Pending</Badge>
          )}
        </div>
      </div>

      {/* Applied Truthful Telemetry Bar */}
      <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] grid grid-cols-2 sm:grid-cols-4 gap-2 text-[11px] font-mono">
        <div>
          <span className="text-[var(--color-text-muted)] block text-[10px]">Context Window</span>
          <span className="font-semibold text-[var(--color-text-primary)]">
            {appliedContextSize !== null && appliedContextSize !== undefined
              ? `${appliedContextSize} [Applied]`
              : 'Pending / Not running'}
          </span>
        </div>
        <div>
          <span className="text-[var(--color-text-muted)] block text-[10px]">GPU Offload</span>
          <span className="font-semibold text-[var(--color-text-primary)]">
            {appliedGpuLayers !== null && appliedGpuLayers !== undefined
              ? `${appliedGpuLayers} layers [Applied]`
              : 'Pending / Not running'}
          </span>
        </div>
        <div>
          <span className="text-[var(--color-text-muted)] block text-[10px]">Vision Projector (Req)</span>
          <span className="font-semibold text-[var(--color-text-secondary)]">
            {requestedMmprojOffload !== undefined
              ? (requestedMmprojOffload ? 'GPU [Configured]' : 'CPU [Configured]')
              : (activeId === 'eco' ? 'CPU [Configured]' : 'GPU [Configured]')}
          </span>
        </div>
        <div>
          <span className="text-[var(--color-text-muted)] block text-[10px]">Vision Projector (Applied)</span>
          <span className="font-semibold text-[var(--color-text-primary)]">
            {appliedMmprojOffload !== null && appliedMmprojOffload !== undefined
              ? (appliedMmprojOffload ? 'GPU [Applied]' : 'CPU [Applied]')
              : 'Pending / Not running'}
          </span>
        </div>
      </div>

      {/* 3 Tactile Profile Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3.5">
        {profiles.map((p) => {
          const isSelected = activeId === p.id;

          return (
            <button
              key={p.id}
              type="button"
              id={`profile-btn-${p.id}`}
              onClick={() => onSelectProfile(p.id)}
              className={`p-4 rounded-2xl text-left transition-all duration-150 relative select-none flex flex-col justify-between group outline-none ${
                isSelected
                  ? 'surface-raised border-2 border-[var(--color-accent)] shadow-md ring-2 ring-[var(--color-accent)]/20'
                  : 'surface-base border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 hover:surface-raised'
              }`}
            >
              <div>
                {/* Top Row: Icon, Title, Check */}
                <div className="flex items-center justify-between gap-2 mb-2">
                  <div className="flex items-center gap-2.5">
                    <div className="w-9 h-9 rounded-xl surface-recessed flex items-center justify-center flex-shrink-0 shadow-inner">
                      {p.icon}
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
                        {p.name}
                      </h3>
                      <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
                        {p.tagline}
                      </span>
                    </div>
                  </div>

                  {isSelected && (
                    <div className="w-5 h-5 rounded-full bg-[var(--color-accent)] text-white flex items-center justify-center shadow-sm">
                      <CheckCircle2 className="w-3.5 h-3.5" />
                    </div>
                  )}
                </div>

                {/* Exact Prompt Description */}
                <p className="text-xs font-medium text-[var(--color-text-primary)] leading-relaxed mt-2">
                  {p.description}
                </p>
              </div>

              {/* Technical Details Pills */}
              <div className="mt-3 pt-2.5 border-t border-[var(--color-border-subtle)] space-y-1">
                {p.details.map((detail, idx) => (
                  <div
                    key={idx}
                    className="flex items-center gap-1.5 text-[10px] text-[var(--color-text-secondary)] font-mono"
                  >
                    <span className="w-1 h-1 rounded-full bg-[var(--color-text-muted)]" />
                    <span>{detail}</span>
                  </div>
                ))}
              </div>
            </button>
          );
        })}
      </div>
    </Card>
  );
};
